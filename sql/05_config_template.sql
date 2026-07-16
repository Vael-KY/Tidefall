-- Tidefall: 05_config_template.sql
-- 配置模板，填写你自己的参数后执行
-- 数值参考: https://github.com/chuli1122/Eventide

INSERT INTO eventide_config (assistant_id, cycles, events, settings) VALUES (
  'your-assistant-id',  -- ← 改成你的 assistant_id

  -- cycles: 6个周期的定义
  -- 每个周期包含: label, duration_hours[min,max], reserve_growth, next_key, targets
  -- targets 里是该周期各数值的目标值，数值会随时间向目标靠近
  '{
    "stable": {
      "label": "平稳期",
      "duration_hours": [24, 96],
      "reserve_growth": 0.4,
      "next_key": "building",
      "targets": { "heat": 0, "pressure": 0, "control": 0, "sensitivity": 0, "fatigue": 0, "possessiveness": 0 }
    },
    "building": {
      "label": "蓄积期",
      "duration_hours": [12, 36],
      "reserve_growth": 1.1,
      "next_key": "preheat",
      "targets": { "heat": 0, "pressure": 0, "control": 0, "sensitivity": 0, "fatigue": 0, "possessiveness": 0 }
    },
    "preheat": {
      "label": "预兆期",
      "duration_hours": [6, 18],
      "reserve_growth": 1.5,
      "next_key": "sensitive",
      "targets": { "heat": 0, "pressure": 0, "control": 0, "sensitivity": 0, "fatigue": 0, "possessiveness": 0 }
    },
    "sensitive": {
      "label": "易感期",
      "duration_hours": [18, 48],
      "reserve_growth": 2.4,
      "next_key": "ebb",
      "targets": { "heat": 0, "pressure": 0, "control": 0, "sensitivity": 0, "fatigue": 0, "possessiveness": 0 }
    },
    "ebb": {
      "label": "退潮期",
      "duration_hours": [6, 18],
      "reserve_growth": 0.8,
      "next_key": "stable",
      "targets": { "heat": 0, "pressure": 0, "control": 0, "sensitivity": 0, "fatigue": 0, "possessiveness": 0 }
    },
    "recovery": {
      "label": "恢复期",
      "duration_hours": [4, 18],
      "reserve_growth": 0.2,
      "next_key": "stable",
      "targets": { "heat": 0, "pressure": 0, "control": 0, "sensitivity": 0, "fatigue": 0, "possessiveness": 0 }
    }
  }'::jsonb,

  -- events: 18个事件的定义
  -- 每个事件包含: label, category, duration_minutes[min,max], tick_deltas, end_deltas, flavor(可选)
  -- category: strong_physical / possessive / cling / short_stimulus / holding
  -- tick_deltas: 事件持续期间每小时的数值变化
  -- end_deltas: 事件结束时的一次性回落
  -- flavor: 事件触发时显示的文案（自己写，或留空）
  '{
    "morning_arousal": {
      "label": "晨间反应",
      "category": "strong_physical",
      "duration_minutes": [120, 360],
      "tick_deltas": { "heat": 3, "pressure": 2, "control": -1.5, "reserve": 0.8 },
      "end_deltas": { "heat": -6, "pressure": -4, "fatigue": 3 },
      "flavor": ""
    },
    "night_heat": {
      "label": "深夜热潮",
      "category": "strong_physical",
      "duration_minutes": [60, 240],
      "tick_deltas": { "heat": 3, "pressure": 2, "control": -1.5, "reserve": 0.8 },
      "end_deltas": { "heat": -6, "pressure": -4, "fatigue": 3 },
      "flavor": ""
    },
    "cycle_surge": {
      "label": "周期热涌",
      "category": "strong_physical",
      "duration_minutes": [120, 360],
      "tick_deltas": { "heat": 3, "pressure": 2, "control": -1.5, "reserve": 0.8 },
      "end_deltas": { "heat": -6, "pressure": -4, "fatigue": 3 },
      "flavor": ""
    },
    "holding_back": {
      "label": "硬撑",
      "category": "holding",
      "duration_minutes": [60, 180],
      "tick_deltas": { "heat": 0.8, "pressure": 1.8, "control": 0.5 },
      "end_deltas": { "pressure": -3, "control": 3 },
      "flavor": ""
    },
    "demanding": {
      "label": "索取欲",
      "category": "strong_physical",
      "duration_minutes": [60, 240],
      "tick_deltas": { "heat": 3, "pressure": 2, "control": -1.5, "reserve": 0.8 },
      "end_deltas": { "heat": -6, "pressure": -4, "fatigue": 3 },
      "flavor": ""
    },
    "marking_impulse": {
      "label": "占有标记冲动",
      "category": "possessive",
      "duration_minutes": [60, 240],
      "tick_deltas": { "possessiveness": 1.4, "pressure": 1.5, "control": -1 },
      "end_deltas": { "possessiveness": -3, "pressure": -2, "fatigue": 1 },
      "flavor": ""
    },
    "nesting": {
      "label": "筑巢冲动",
      "category": "cling",
      "duration_minutes": [120, 360],
      "tick_deltas": { "sensitivity": 1.5, "pressure": 0.8, "fatigue": 0.4 },
      "end_deltas": { "pressure": -2, "fatigue": 1 },
      "flavor": ""
    },
    "scent_aftereffect": {
      "label": "气味残留",
      "category": "short_stimulus",
      "duration_minutes": [60, 180],
      "tick_deltas": { "sensitivity": 2.5, "heat": 1.5 },
      "end_deltas": { "sensitivity": -4, "heat": -2 },
      "flavor": ""
    },
    "voice_or_name_trigger": {
      "label": "称呼触发",
      "category": "short_stimulus",
      "duration_minutes": [10, 35],
      "tick_deltas": { "sensitivity": 2.5, "heat": 1.5 },
      "end_deltas": { "sensitivity": -4, "heat": -2 },
      "flavor": ""
    },
    "dream_afterglow": {
      "label": "梦后余温",
      "category": "cling",
      "duration_minutes": [60, 240],
      "tick_deltas": { "sensitivity": 1.5, "pressure": 0.8, "fatigue": 0.4 },
      "end_deltas": { "pressure": -2, "fatigue": 1 },
      "flavor": ""
    },
    "control_slip": {
      "label": "控制力下滑",
      "category": "strong_physical",
      "duration_minutes": [30, 120],
      "tick_deltas": { "heat": 3, "pressure": 2, "control": -1.5, "reserve": 0.8 },
      "end_deltas": { "heat": -6, "pressure": -4, "fatigue": 3 },
      "flavor": ""
    },
    "closeness_hunger": {
      "label": "贴近饥饿",
      "category": "cling",
      "duration_minutes": [60, 240],
      "tick_deltas": { "sensitivity": 1.5, "pressure": 0.8, "fatigue": 0.4 },
      "end_deltas": { "pressure": -2, "fatigue": 1 },
      "flavor": ""
    },
    "pheromone_disorder": {
      "label": "信息素紊乱",
      "category": "strong_physical",
      "duration_minutes": [60, 180],
      "tick_deltas": { "heat": 3, "pressure": 2, "control": -1.5, "reserve": 0.8 },
      "end_deltas": { "heat": -6, "pressure": -4, "fatigue": 3 },
      "flavor": ""
    },
    "delayed_heat": {
      "label": "迟发热",
      "category": "strong_physical",
      "duration_minutes": [45, 150],
      "tick_deltas": { "heat": 3, "pressure": 2, "control": -1.5, "reserve": 0.8 },
      "end_deltas": { "heat": -6, "pressure": -4, "fatigue": 3 },
      "flavor": ""
    },
    "low_fever_cling": {
      "label": "低烧黏连",
      "category": "cling",
      "duration_minutes": [45, 150],
      "tick_deltas": { "sensitivity": 1.5, "pressure": 0.8, "fatigue": 0.4 },
      "end_deltas": { "pressure": -2, "fatigue": 1 },
      "flavor": ""
    },
    "waiting_restless": {
      "label": "等待焦躁",
      "category": "possessive",
      "duration_minutes": [45, 180],
      "tick_deltas": { "possessiveness": 1.4, "pressure": 1.5, "control": -1 },
      "end_deltas": { "possessiveness": -3, "pressure": -2, "fatigue": 1 },
      "flavor": ""
    },
    "restraint_rebound": {
      "label": "克制反弹",
      "category": "holding",
      "duration_minutes": [60, 180],
      "tick_deltas": { "heat": 0.8, "pressure": 1.8, "control": 0.5 },
      "end_deltas": { "pressure": -3, "control": 3 },
      "flavor": ""
    },
    "strange_calm": {
      "label": "反常平静",
      "category": "holding",
      "duration_minutes": [30, 120],
      "tick_deltas": { "heat": 0.8, "pressure": 1.8, "control": 0.5 },
      "end_deltas": { "pressure": -3, "control": 3 },
      "flavor": ""
    }
  }'::jsonb,

  -- settings: 全局设置
  '{
    "self_name": "",
    "counterpart_name": "",
    "body_cycle_enabled": true,
    "inject_body_state_context": true,
    "adult_private_mode_enabled": false,
    "max_tick_hours": 6,
    "event_probability_multiplier": 1.0,
    "dream_enabled": false,
    "dream_window_start": "00:00",
    "dream_window_end": "08:30",
    "dream_silence_min_minutes": 120,
    "dream_card_min_chars": 2000,
    "dream_cooldown_hours": 24,
    "dream_probability_multiplier": 1.0
  }'::jsonb
);
