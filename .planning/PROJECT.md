# Botato AI Refactor

## What This Is

Pasha-AutoBattler 是 Brotato（土豆兄弟）的 AI 自动战斗 Mod，为玩家提供 AI 自动操作功能，包含可视化决策展示和合作模式支持。当前版本存在核心 AI 逻辑缺陷和扩展性不足的问题，需要从架构层面进行全面重构升级。

## Core Value

AI 必须在复杂战斗场景中做出正确的生存决策 — 正确闪避弹幕、智能适应难度变化、提供足够的行为调节维度。

## Requirements

### Validated

- ✓ AI 可以自动控制玩家角色移动 — existing
- ✓ 基于权重的转向力系统（consumables、items、projectiles、enemies、bosses、walls） — existing
- ✓ AI 决策可视化（蓝色吸引、红色排斥、紫色墙壁） — existing
- ✓ 13 个可配置参数通过 ModOptions UI 调节 — existing
- ✓ 合作模式下 bot/人类玩家切换 — existing
- ✓ 配置持久化到本地文件 — existing
- ✓ 角色特殊逻辑（Soldier、Bull） — existing

### Active

- [ ] 硬逻辑修复：弹幕闪避应垂直于弹幕轨迹方向，而非直线后退
- [ ] 硬逻辑修复：全面审查并修复类似的算法缺陷
- [x] 软逻辑：局内自适应权重系统，根据表现指标实时调节各因素权重 — Validated in Phase 3
- [x] 软逻辑：自适应触发条件（存活时长、失败次数、场上威胁密度等） — Validated in Phase 3 (EMA health_ratio + damage_rate)
- [x] 可控性：扩展更多可调因素（水果吸引、箱子吸引、Boss 闪避强度等） — Validated in Phase 4 (CONSUMABLE_WEIGHT + CRATE_WEIGHT sliders, BOSS_WEIGHT verified independent)
- [x] 可控性：新因素的可视化支持 — Validated in Phase 4 (crate arrows in ai_canvas)
- [ ] 架构重构：代码结构更健壮、简洁、可扩展
- [ ] 架构重构：为未来新增因素/行为提供清晰的扩展点

### Out of Scope

- 跨局学习/持久化记忆 — 用户明确选择仅当局内自适应，不需要跨局数据持久化
- 多 bot 支持 — 历史上尝试过并已回滚，当前保持单 AI 支持
- 自定义 AI 策略预设 — v1 重构聚焦核心逻辑，预设功能后续考虑

## Context

- **技术栈**：GDScript / Godot 3.5 / Godot Mod Loader 6.0.0
- **Mod 依赖**：ContentLoader、dami-ModOptions
- **分发平台**：Steam Workshop
- **代码规模**：~933 行 GDScript，7 个功能模块
- **核心模块**：`player_movement_behavior.gd`（AI 决策算法）和 `ai_canvas.gd`（可视化）是最大的两个模块
- **已知问题**：弹幕闪避方向错误（直线后退而非横向闪避）；多 bot 功能曾尝试后回滚
- **Modding 框架**：使用 Script Extensions 模式通过继承链覆盖游戏方法，不能重定义成员变量，不能替换虚函数
- **Brotato Mod 开发**：基于 Godot 3.5（非 4.0），使用 GDRETools 反编译，ModLoaderMod API 注册扩展

## Constraints

- **引擎版本**: Godot 3.5 — Brotato 使用 Godot 3.5 构建，所有代码必须兼容此版本
- **Mod 框架限制**: Script Extensions 不能重定义成员变量、不能替换虚函数、不能修改预加载脚本
- **性能**: 所有 AI 计算在 `_physics_process` 中逐帧执行，必须保持高性能（当前使用距离平方避免 sqrt）
- **兼容性**: 必须兼容 Brotato 1.1.10.4+，不破坏现有 ModOptions 配置
- **无外部依赖**: 不能引入 Brotato/Godot 生态之外的库

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 仅局内自适应，不跨局 | 简化架构，避免文件持久化复杂度；局内适应已满足需求 | — Pending |
| 保持单 AI，不恢复多 bot | 多 bot 曾尝试并回滚，复杂度高且不稳定 | — Pending |
| 横向闪避替代直线后退 | 垂直于弹幕轨迹的闪避更符合实际战斗直觉 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -- still the right priority?
3. Audit Out of Scope -- reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-13 after Phase 4 completion (all v1 phases complete)*
