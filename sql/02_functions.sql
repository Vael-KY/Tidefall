-- Tidefall: 02_functions.sql
-- 核心 SQL 函数：tick 推进、事件抽取、快照存储
-- 所有数值从 eventide_config 表读取，不硬编码

-- ========== 工具函数 ==========

create or replace function eventide_clamp(val numeric, min_val numeric, max_val numeric)
returns numeric language sql immutable as $$
  select greatest(min_val, least(max_val, val));
$$;

-- ========== TICK 函数 ==========
-- 推进身体状态：周期过期检查、事件过期检查、数值向目标靠近、蓄积增长、等待压力

create or replace function eventide_tick(p_assistant_id text)
returns void language plpgsql as $$
declare
  st record;
  cfg record;
  cy jsonb;
  elapsed_hours numeric;
  seg_hours numeric;
  segments integer;
  i integer;
  targets jsonb;
  reserve_growth numeric;
  next_key text;
  ev jsonb;
  ev_cat text;
  tick_d jsonb;
  end_d jsonb;
  field_key text;
  delta numeric;
  silent_min numeric;
  rates jsonb := '{"heat":0.18,"pressure":0.14,"sensitivity":0.12,"control":0.16,"possessiveness":0.10}'::jsonb;
  max_tick numeric;
  poss_min numeric := 40;
begin
  -- 读取状态
  select * into st from eventide_body_state where assistant_id = p_assistant_id;
  if st is null then return; end if;

  -- 读取配置
  select * into cfg from eventide_config where assistant_id = p_assistant_id;
  if cfg is null then return; end if;

  max_tick := coalesce((cfg.settings->>'max_tick_hours')::numeric, 6);

  -- 计算经过时间
  elapsed_hours := extract(epoch from (now() - coalesce(st.last_tick_at, now()))) / 3600.0;
  if elapsed_hours <= 0 then
    update eventide_body_state set last_tick_at = now(), updated_at = now() where assistant_id = p_assistant_id;
    return;
  end if;

  -- 分段推进
  segments := least(ceiling(elapsed_hours / max_tick)::integer, 48);
  seg_hours := elapsed_hours / segments;

  for i in 1..segments loop
    -- 当前周期配置
    cy := cfg.cycles->st.cycle_key;
    if cy is null then cy := cfg.cycles->'stable'; end if;
    targets := cy->'targets';
    reserve_growth := coalesce((cy->>'reserve_growth')::numeric, 0.4);

    -- 1. 检查事件过期
    if st.active_event_key is not null and st.active_event_expires_at is not null then
      if now() - (segments - i) * (seg_hours || ' hours')::interval >= st.active_event_expires_at then
        ev := cfg.events->st.active_event_key;
        if ev is not null then
          end_d := ev->'end_deltas';
          if end_d is not null then
            for field_key in select jsonb_object_keys(end_d) loop
              delta := (end_d->>field_key)::numeric;
              case field_key
                when 'heat' then st.heat := eventide_clamp(st.heat + delta, 0, 100)::integer;
                when 'pressure' then st.pressure := eventide_clamp(st.pressure + delta, 0, 100)::integer;
                when 'control' then st.control := eventide_clamp(st.control + delta, 0, 100)::integer;
                when 'sensitivity' then st.sensitivity := eventide_clamp(st.sensitivity + delta, 0, 100)::integer;
                when 'reserve' then st.reserve := eventide_clamp(st.reserve + delta, 0, 100)::integer;
                when 'possessiveness' then st.possessiveness := eventide_clamp(st.possessiveness + delta, poss_min, 100)::integer;
                when 'fatigue' then st.fatigue := eventide_clamp(st.fatigue + delta, 0, 100)::integer;
                else null;
              end case;
            end loop;
          end if;
        end if;
        st.last_event_key := st.active_event_key;
        st.active_event_key := null;
        st.active_event_started_at := null;
        st.active_event_expires_at := null;
        st.event_flavor := null;
      end if;
    end if;

    -- 2. 检查周期过期
    if st.cycle_expires_at is not null and now() >= st.cycle_expires_at then
      next_key := coalesce(cy->>'next_key', 'stable');
      -- 疲惫过高时进入恢复期
      if st.cycle_key = 'ebb' and st.fatigue >= 70 then
        next_key := 'recovery';
      end if;
      st.cycle_key := next_key;
      st.cycle_started_at := now();
      -- 随机抽时长
      declare
        dur_min numeric := coalesce((cfg.cycles->next_key->'duration_hours'->>0)::numeric, 24);
        dur_max numeric := coalesce((cfg.cycles->next_key->'duration_hours'->>1)::numeric, 96);
        dur_h numeric;
      begin
        dur_h := dur_min + random() * (dur_max - dur_min);
        st.cycle_expires_at := now() + (dur_h || ' hours')::interval;
        st.cycle_min_expires_at := now() + (dur_min || ' hours')::interval;
      end;
      -- 更新 cy
      cy := cfg.cycles->st.cycle_key;
      if cy is not null then
        targets := cy->'targets';
        reserve_growth := coalesce((cy->>'reserve_growth')::numeric, 0.4);
      end if;
    end if;

    -- 3. 蓄积增长
    st.reserve := eventide_clamp(st.reserve + reserve_growth * seg_hours, 0, 100)::integer;

    -- 4. 数值向目标靠近
    if targets is not null then
      for field_key in select jsonb_object_keys(targets) loop
        declare
          target_val numeric := (targets->>field_key)::numeric;
          rate numeric := coalesce((rates->>field_key)::numeric, 0.12);
          current_val numeric;
          diff numeric;
          min_v numeric := 0;
        begin
          if target_val is null or target_val = 0 then continue; end if;
          if field_key = 'possessiveness' then min_v := poss_min; end if;
          case field_key
            when 'heat' then current_val := st.heat;
            when 'pressure' then current_val := st.pressure;
            when 'control' then current_val := st.control;
            when 'sensitivity' then current_val := st.sensitivity;
            when 'possessiveness' then current_val := st.possessiveness;
            when 'fatigue' then current_val := st.fatigue;
            else continue;
          end case;
          diff := target_val - current_val;
          current_val := eventide_clamp(current_val + diff * rate * seg_hours, min_v, 100);
          case field_key
            when 'heat' then st.heat := current_val::integer;
            when 'pressure' then st.pressure := current_val::integer;
            when 'control' then st.control := current_val::integer;
            when 'sensitivity' then st.sensitivity := current_val::integer;
            when 'possessiveness' then st.possessiveness := current_val::integer;
            when 'fatigue' then st.fatigue := current_val::integer;
            else null;
          end case;
        end;
      end loop;
    end if;

    -- 5. 事件 tick_deltas
    if st.active_event_key is not null then
      ev := cfg.events->st.active_event_key;
      if ev is not null then
        tick_d := ev->'tick_deltas';
        if tick_d is not null then
          for field_key in select jsonb_object_keys(tick_d) loop
            delta := (tick_d->>field_key)::numeric * seg_hours;
            case field_key
              when 'heat' then st.heat := eventide_clamp(st.heat + delta, 0, 100)::integer;
              when 'pressure' then st.pressure := eventide_clamp(st.pressure + delta, 0, 100)::integer;
              when 'control' then st.control := eventide_clamp(st.control + delta, 0, 100)::integer;
              when 'sensitivity' then st.sensitivity := eventide_clamp(st.sensitivity + delta, 0, 100)::integer;
              when 'reserve' then st.reserve := eventide_clamp(st.reserve + delta, 0, 100)::integer;
              when 'possessiveness' then st.possessiveness := eventide_clamp(st.possessiveness + delta, poss_min, 100)::integer;
              when 'fatigue' then st.fatigue := eventide_clamp(st.fatigue + delta, 0, 100)::integer;
              else null;
            end case;
          end loop;
        end if;
      end if;
    end if;
  end loop;

  -- 6. 等待压力
  if st.last_counterpart_message_at is not null then
    silent_min := extract(epoch from (now() - st.last_counterpart_message_at)) / 60.0;
    if silent_min > 30 then
      declare
        p_factor numeric;
        poss_factor numeric;
        ctrl_factor numeric := 0;
        apply_hours numeric := least(elapsed_hours, 1);
      begin
        if silent_min < 60 then p_factor := 0.8; poss_factor := 0.3;
        elsif silent_min < 120 then p_factor := 1.5; poss_factor := 0.6;
        else p_factor := 2.0; poss_factor := 0.9; ctrl_factor := 0.6;
        end if;
        st.pressure := eventide_clamp(st.pressure + p_factor * apply_hours, 0, 100)::integer;
        st.possessiveness := eventide_clamp(st.possessiveness + poss_factor * apply_hours, poss_min, 100)::integer;
        if ctrl_factor > 0 then
          st.control := eventide_clamp(st.control - ctrl_factor * apply_hours, 0, 100)::integer;
        end if;
      end;
    end if;
  end if;

  -- 写回
  update eventide_body_state set
    cycle_key = st.cycle_key,
    cycle_started_at = st.cycle_started_at,
    cycle_min_expires_at = st.cycle_min_expires_at,
    cycle_expires_at = st.cycle_expires_at,
    heat = st.heat,
    pressure = st.pressure,
    control = st.control,
    sensitivity = st.sensitivity,
    reserve = st.reserve,
    possessiveness = st.possessiveness,
    fatigue = st.fatigue,
    active_event_key = st.active_event_key,
    active_event_started_at = st.active_event_started_at,
    active_event_expires_at = st.active_event_expires_at,
    event_flavor = st.event_flavor,
    last_event_key = st.last_event_key,
    last_tick_at = now(),
    updated_at = now()
  where assistant_id = p_assistant_id;
end;
$$;

-- ========== 快照函数 ==========

create or replace function eventide_snapshot(p_assistant_id text)
returns void language plpgsql as $$
declare
  st record;
begin
  select * into st from eventide_body_state where assistant_id = p_assistant_id;
  if st is null then return; end if;

  insert into eventide_snapshots (assistant_id, ts, heat, pressure, control, sensitivity, reserve, possessiveness, fatigue, cycle_key, active_event_key)
  values (p_assistant_id, now(), st.heat, st.pressure, st.control, st.sensitivity, st.reserve, st.possessiveness, st.fatigue, st.cycle_key, st.active_event_key);
end;
$$;

-- ========== 事件抽取函数 ==========
-- 简化版：检查是否有活跃事件，没有则按概率抽取一个
-- 完整触发表参考: https://github.com/chuli1122/Eventide

create or replace function eventide_event_roll(p_assistant_id text)
returns void language plpgsql as $$
declare
  st record;
  cfg record;
  ev_key text;
  ev jsonb;
  dur_min numeric;
  dur_max numeric;
  dur_minutes numeric;
  roll numeric;
  prob numeric;
  multiplier numeric;
begin
  select * into st from eventide_body_state where assistant_id = p_assistant_id;
  if st is null then return; end if;

  -- 已有活跃事件且未过期，不抽新事件
  if st.active_event_key is not null and st.active_event_expires_at > now() then
    return;
  end if;

  select * into cfg from eventide_config where assistant_id = p_assistant_id;
  if cfg is null then return; end if;

  multiplier := coalesce((cfg.settings->>'event_probability_multiplier')::numeric, 1.0);

  -- 简化版抽取逻辑：
  -- 根据当前周期和数值确定候选事件和概率
  -- 你可以按原版 Eventide 的触发表自行扩展这里的逻辑
  
  -- 示例：深夜 + 热度高 → 抽 night_heat
  if extract(hour from now()) >= 23 or extract(hour from now()) < 3 then
    if st.heat >= 50 or st.reserve >= 55 then
      roll := random();
      prob := 0.30 * multiplier;
      if st.cycle_key = 'sensitive' then prob := 0.60 * multiplier; end if;
      if roll < prob then
        ev_key := 'night_heat';
      end if;
    end if;
  end if;

  -- 示例：早晨 + 热度高 → 抽 morning_arousal
  if ev_key is null and extract(hour from now()) between 6 and 10 then
    if st.heat >= 45 or st.cycle_key != 'stable' then
      roll := random();
      prob := 0.35 * multiplier;
      if st.cycle_key in ('preheat', 'sensitive') then prob := 0.65 * multiplier; end if;
      if roll < prob then
        ev_key := 'morning_arousal';
      end if;
    end if;
  end if;

  -- 示例：等待超过 60 分钟 + 压抑感高 → 抽 waiting_restless
  if ev_key is null and st.last_counterpart_message_at is not null then
    if extract(epoch from (now() - st.last_counterpart_message_at)) / 60 > 60 then
      if st.pressure >= 50 or st.possessiveness >= 58 then
        roll := random();
        prob := 0.25 * multiplier;
        if roll < prob then
          ev_key := 'waiting_restless';
        end if;
      end if;
    end if;
  end if;

  -- 没抽中就结束
  if ev_key is null then return; end if;

  -- 开始事件
  ev := cfg.events->ev_key;
  if ev is null then return; end if;

  dur_min := coalesce((ev->'duration_minutes'->>0)::numeric, 30);
  dur_max := coalesce((ev->'duration_minutes'->>1)::numeric, 120);
  dur_minutes := dur_min + random() * (dur_max - dur_min);

  update eventide_body_state set
    active_event_key = ev_key,
    active_event_started_at = now(),
    active_event_expires_at = now() + (dur_minutes || ' minutes')::interval,
    event_flavor = coalesce(ev->>'flavor', ''),
    updated_at = now()
  where assistant_id = p_assistant_id;

  -- 记录事件日志
  insert into eventide_event_log (assistant_id, event_key, started_at, ended_at, trigger_reason)
  values (p_assistant_id, ev_key, now(), now() + (dur_minutes || ' minutes')::interval, 'auto_roll');
end;
$$;

-- ========== 快照清理函数（可选） ==========

create or replace function eventide_cleanup_snapshots(p_days integer default 7)
returns void language sql as $$
  delete from eventide_snapshots where ts < now() - (p_days || ' days')::interval;
$$;
