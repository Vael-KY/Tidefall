-- Tidefall: 04_cron.sql
-- 启用 pg_cron 定时任务
--
-- 前置条件：
-- 1. 在 Supabase Dashboard → Database → Extensions 中启用 pg_cron
-- 2. 确保 02_functions.sql 已执行
--
-- ❗ 把下方所有 'your-assistant-id' 改成你的 assistant_id

-- 每 15 分钟推进身体状态
select cron.schedule(
  'eventide-tick-15min',
  '*/15 * * * *',
  $$select eventide_tick('your-assistant-id')$$
);

-- 每 15 分钟存储快照
select cron.schedule(
  'eventide-snapshot-15min',
  '*/15 * * * *',
  $$select eventide_snapshot('your-assistant-id')$$
);

-- 每 15 分钟检查是否抽取新事件
select cron.schedule(
  'eventide-event-roll-15min',
  '*/15 * * * *',
  $$select eventide_event_roll('your-assistant-id')$$
);

-- （可选）每天凌晨 4 点清理 7 天前的快照
select cron.schedule(
  'eventide-cleanup-daily',
  '0 4 * * *',
  $$select eventide_cleanup_snapshots(7)$$
);
