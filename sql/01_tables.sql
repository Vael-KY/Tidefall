-- Tidefall: 01_tables.sql
-- 建立 5 张核心表
-- 在 Supabase SQL Editor 中执行

-- 1. 身体状态主表
create table if not exists eventide_body_state (
  id uuid default gen_random_uuid() primary key,
  assistant_id text not null unique,
  cycle_key text default 'stable',
  cycle_started_at timestamptz default now(),
  cycle_min_expires_at timestamptz,
  cycle_expires_at timestamptz,
  heat integer default 30,
  pressure integer default 25,
  control integer default 75,
  sensitivity integer default 35,
  reserve integer default 20,
  possessiveness integer default 40,
  fatigue integer default 15,
  active_event_key text,
  active_event_started_at timestamptz,
  active_event_expires_at timestamptz,
  event_flavor text,
  last_event_key text,
  last_tick_at timestamptz default now(),
  last_dream_at timestamptz,
  last_counterpart_message_at timestamptz,
  map_weather text default 'sunny',
  meta jsonb default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table eventide_body_state enable row level security;
create policy "anon_all" on eventide_body_state for all using (true) with check (true);

-- 2. 快照表（曲线图用）
create table if not exists eventide_snapshots (
  id uuid default gen_random_uuid() primary key,
  assistant_id text not null,
  ts timestamptz default now(),
  heat integer,
  pressure integer,
  control integer,
  sensitivity integer,
  reserve integer,
  possessiveness integer,
  fatigue integer,
  cycle_key text,
  active_event_key text
);

create index if not exists idx_snapshots_aid_ts on eventide_snapshots(assistant_id, ts desc);

alter table eventide_snapshots enable row level security;
create policy "anon_all" on eventide_snapshots for all using (true) with check (true);

-- 3. 事件日志表
create table if not exists eventide_event_log (
  id uuid default gen_random_uuid() primary key,
  assistant_id text not null,
  event_key text not null,
  started_at timestamptz,
  ended_at timestamptz,
  trigger_reason text,
  state_snapshot jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_eventlog_aid on eventide_event_log(assistant_id, ended_at desc);

alter table eventide_event_log enable row level security;
create policy "anon_all" on eventide_event_log for all using (true) with check (true);

-- 4. 触发词表
create table if not exists eventide_trigger_words (
  id serial primary key,
  assistant_id text not null,
  key text not null,           -- 去重用，如 'nickname:宝贝'
  word text not null,          -- 匹配文本
  type text default 'nickname', -- nickname / phrase
  enabled boolean default true,
  created_at timestamptz default now()
);

create index if not exists idx_trigger_aid on eventide_trigger_words(assistant_id);

alter table eventide_trigger_words enable row level security;
create policy "anon_all" on eventide_trigger_words for all using (true) with check (true);

-- 5. 配置表（周期/事件/设置全部存这里）
create table if not exists eventide_config (
  id serial primary key,
  assistant_id text not null unique,
  cycles jsonb default '{}',    -- 6个周期的完整定义
  events jsonb default '{}',    -- 18个事件的完整定义
  settings jsonb default '{}',  -- 全局设置
  updated_at timestamptz default now()
);

alter table eventide_config enable row level security;
create policy "anon_all" on eventide_config for all using (true) with check (true);
