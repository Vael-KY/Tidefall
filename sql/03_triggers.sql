-- Tidefall: 03_triggers.sql
-- DB Trigger：消息写入时检测触发词，命中则修改身体数值
--
-- ❗ 重要：你需要把这个 trigger 绑到你自己的消息表上
--    替换下方的 YOUR_MESSAGE_TABLE 和 NEW.content
--    如果你的平台没有消息入库机制，可以跳过这个文件

create or replace function eventide_on_message()
returns trigger language plpgsql as $$
declare
  msg_content text;
  tw record;
  matched boolean := false;
  aid text;
  sens_delta integer;
  poss_delta integer;
  pres_delta integer;
begin
  -- ← 把 NEW.content 改成你的消息内容字段名
  msg_content := lower(coalesce(NEW.content, ''));
  
  -- ← 把这里改成你确定 assistant_id 的方式
  -- 如果你的消息表有 assistant_id 字段可以直接用
  -- 否则硬编码你的 assistant_id
  aid := 'your-assistant-id';  -- ← 改成你的 assistant_id

  -- 扫描触发词表
  for tw in
    select * from eventide_trigger_words
    where assistant_id = aid and enabled = true
  loop
    if msg_content like '%' || lower(tw.word) || '%' then
      matched := true;
      exit;
    end if;
  end loop;

  if not matched then
    -- 没命中触发词，但更新最后消息时间
    update eventide_body_state
    set last_counterpart_message_at = now(), updated_at = now()
    where assistant_id = aid;
    return NEW;
  end if;

  -- 命中触发词：随机增加数值
  sens_delta := 3 + floor(random() * 6)::integer;  -- +3 到 +8
  poss_delta := 1 + floor(random() * 3)::integer;  -- +1 到 +3
  pres_delta := floor(random() * 5)::integer;      -- +0 到 +4

  update eventide_body_state set
    sensitivity = eventide_clamp(sensitivity + sens_delta, 0, 100)::integer,
    possessiveness = eventide_clamp(possessiveness + poss_delta, 40, 100)::integer,
    pressure = eventide_clamp(pressure + pres_delta, 0, 100)::integer,
    last_counterpart_message_at = now(),
    updated_at = now()
  where assistant_id = aid;

  return NEW;
end;
$$;

-- ❗ 把 YOUR_MESSAGE_TABLE 改成你的消息表名
-- 例如：chat_messages / messages / conversations 等

-- CREATE TRIGGER eventide_trigger_check
--   AFTER INSERT ON YOUR_MESSAGE_TABLE
--   FOR EACH ROW
--   EXECUTE FUNCTION eventide_on_message();

-- 取消注释并替换表名后执行
