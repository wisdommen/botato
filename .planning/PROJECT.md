# Botato AI Refactor

## What This Is

Pasha-AutoBattlerEnhanced 是 Brotato（土豆兄弟）的 AI 自动战斗 Mod，为玩家提供 AI 自动操作功能。v1.0 完成了完整的架构重构：composable force calculators、arrow-based 可视化、EMA 自适应权重控制器、以及可扩展的新力类型系统。

## Core Value

AI 必须在复杂战斗场景中做出正确的生存决策 — 正确闪避弹幕、智能适应难度变化、提供足够的行为调节维度。

## Requirements

### Validated

- ✓ AI 可以自动控制玩家角色移动 — existing
- ✓ 基于权重的转向力系统（consumables、items、projectiles、enemies、bosses、walls） — existing
- ✓ AI 决策可视化（蓝色吸引、红色排斥、紫色墙壁） — existing → upgraded to arrow-based in v1.0
- ✓ 13+ 可配置参数通过 ModOptions UI 调节 — existing → extended to 15 in v1.0
- ✓ 合作模式下 bot/人类玩家切换 — existing
- ✓ 配置持久化到本地文件 — existing
- ✓ 角色特殊逻辑（Soldier、Bull） — existing
- ✓ 架构重构：composable force calculators with ForceResult contract — v1.0 Phase 1
- ✓ 硬逻辑修复：弹幕闪避使用垂直于弹幕轨迹的横向闪避 — v1.0 Phase 1 (ALGO-01)
- ✓ 硬逻辑修复：对称弹幕不再相互抵消，其他力类型自然打破平衡 — v1.0 Phase 1 (ALGO-02)
- ✓ 硬逻辑修复：边界力使用解析式4墙公式替代O(n)循环 — v1.0 Phase 1 (ALGO-03)
- ✓ 可视化解耦：ai_canvas 读取 ForceResult 数据，不再重复计算 — v1.0 Phase 2 (ARCH-03)
- ✓ 软逻辑：EMA 自适应权重系统，根据 damage_rate 和 health_ratio 实时调节 — v1.0 Phase 3
- ✓ 软逻辑：自适应波次重置，无跨波次残留 — v1.0 Phase 3 (ADAPT-03)
- ✓ 可控性：CONSUMABLE_WEIGHT 和 CRATE_WEIGHT 新增滑块 — v1.0 Phase 4
- ✓ 可控性：箱子力类型可视化（棕色箭头） — v1.0 Phase 4
- ✓ 向后兼容：旧存档加载不崩溃，缺失键使用默认值回退 — v1.0 Phase 4 (EXT-06/07)

### Active

(None — v1.0 complete. Next milestone requirements TBD via `/gsd-new-milestone`)

### Out of Scope

- 跨局学习/持久化记忆 — 用户明确选择仅当局内自适应，不需要跨局数据持久化
- 多 bot 支持 — 历史上尝试过并已回滚，当前保持单 AI 支持
- 自定义 AI 策略预设 — v1 重构聚焦核心逻辑，预设功能后续考虑
- Context steering maps — 对于开放竞技场地形来说过于复杂，不必要
- ML/RL 神经网络 — 需要外部 Python 训练环境，在 Godot mod 中不可行

## Context

- **技术栈**：GDScript / Godot 3.5 / Godot Mod Loader 6.0.0
- **Mod 名称**：Pasha-AutoBattlerEnhanced（从 Pasha-AutoBattler 重命名）
- **分发平台**：Steam Workshop
- **代码规模**：~1520 行 GDScript，8 个力计算器 + 自适应控制器 + 可视化 + 配置
- **架构**：Composable force calculators (forces/ 目录) → ForceResult contract → 30行 get_movement() 编排循环
- **可视化**：Arrow-based debug overlay，8 种力类型颜色，复合总力箭头
- **自适应系统**：EMA 跟踪 damage_rate + health_ratio，双组自适应（防御组/进攻组），±30% 权重调节
- **配置系统**：15 个 ModOptions 滑块，ConfigFile 持久化，向后兼容的 get_value(key, default) 模式

## Constraints

- **引擎版本**: Godot 3.5 — Brotato 使用 Godot 3.5 构建，所有代码必须兼容此版本
- **Mod 框架限制**: Script Extensions 不能重定义成员变量、不能替换虚函数、不能修改预加载脚本
- **性能**: 所有 AI 计算在 `_physics_process` 中逐帧执行，必须保持高性能（使用距离平方避免 sqrt）
- **兼容性**: 必须兼容 Brotato 1.1.10.4+，不破坏现有 ModOptions 配置
- **无外部依赖**: 不能引入 Brotato/Godot 生态之外的库

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 仅局内自适应，不跨局 | 简化架构，避免文件持久化复杂度；局内适应已满足需求 | ✓ Validated v1.0 |
| 保持单 AI，不恢复多 bot | 多 bot 曾尝试并回滚，复杂度高且不稳定 | ✓ Validated v1.0 |
| 横向闪避替代直线后退 | 垂直于弹幕轨迹的闪避更符合实际战斗直觉 | ✓ Validated v1.0 Phase 1 |
| 线性权重映射替代平方映射 | 滑块值直接用作乘数，更直观 | ✓ Validated v1.0 Phase 1 |
| EMA 平滑 + 双组自适应 | 防御组(弹幕/Boss/墙壁)和进攻组(拾取/树木)反向调节 | ✓ Validated v1.0 Phase 3 |
| 箱子通过 consumable_data.my_id 过滤 | 箱子和水果共享 _consumables 数组，按 my_id 区分 | ✓ Validated v1.0 Phase 4 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check -- still the right priority?
3. Audit Out of Scope -- reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-13 after v1.0 milestone completion*
