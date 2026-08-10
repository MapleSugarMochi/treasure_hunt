# `luna_worker` 自定义 Agent 配置设计

日期：2026-08-10  
状态：已批准，待实施  
适用范围：当前用户的全局 Codex 配置

## 目标

确保全局自定义 Agent `luna_worker` 使用 `gpt-5.6-luna` 与最高 `max` 推理等级，只执行范围明确、边界清晰、可独立验收的委派任务；同时建立适用于所有自定义 subagents 的全局调度规则。

## 当前状态

- 本机 Codex CLI 版本为 `0.146.1`。
- `C:\Users\dongx\.codex\agents\luna-worker.toml` 已存在。
- 现有 Agent 文件已经包含当前版本要求的 `name`、`description`、`developer_instructions`，并设置 `model = "gpt-5.6-luna"`、`model_reasoning_effort = "max"`。
- 现有说明已经禁止改变主任务目标、自行扩大范围、修改未授权文件和继续委派。
- `C:\Users\dongx\.codex\AGENTS.md` 与 `AGENTS.override.md` 均不存在。
- `C:\Users\dongx\.codex\config.toml` 没有 `[agents]` 并发限制，也没有 `agents.max_concurrent_threads_per_session` 或旧字段 `agents.max_threads`。

## 兼容格式

当前 Codex 自定义 Agent 文件必须使用：

```toml
name = "luna_worker"
description = "Bounded execution worker for well-scoped, independent delegated tasks with explicit deliverables and acceptance criteria."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"
developer_instructions = """
Work only on the delegated task. Preserve the parent objective, remain within the assigned file and responsibility boundaries, validate every acceptance criterion, and return a concise handoff to the parent agent.
"""
```

用户所说的 `instructions` 以当前版本支持的 `developer_instructions` 实现。文件名保留为 `luna-worker.toml`，Agent 名称以 `name = "luna_worker"` 为准。用户末句中的 `lIuna_worker` 视为拼写误差，统一使用 `luna_worker`。

## 增量修改

### Agent 文件

保留现有 `luna-worker.toml`。只有严格验证发现当前文件无效时，才进行最小修正；不得删除或重写其他 Agent 文件。

### 全局 `AGENTS.md`

新建 `C:\Users\dongx\.codex\AGENTS.md`，内容如下：

```markdown
# Global Codex Instructions

## Subagent delegation

- Prefer dispatching multiple `luna_worker` agents in parallel for substantial, mutually independent subtasks.
- Keep lightweight tasks that can be completed within a few minutes in the main thread.
- Every worker assignment must be self-contained and explicitly state the relevant context, owned files or read-only scope, task boundaries, expected output, and acceptance criteria.
- Read-only tasks may run in parallel. File-writing tasks must use separate Git worktrees; if safe isolation is unavailable, run those tasks serially.
- The main agent owns task decomposition and acceptance. After a worker finishes, verify its result against every acceptance criterion; if it does not pass, dispatch a corrected assignment instead of accepting it.
- If multiple workers cannot run concurrently, inspect `agents.max_concurrent_threads_per_session` in `~/.codex/config.toml`; a value of `1` prevents parallel worker execution.
- Apply these delegation rules to `luna_worker` and all other custom subagents unless a more specific applicable instruction overrides them.
- When a suitable custom worker is needed, prefer `luna_worker`. Workers execute bounded subtasks; the main agent retains responsibility for the parent objective, coordination, integration, and final verification.
```

这些规则使用全局 `AGENTS.md`，因此适用于所有项目；项目或子目录中更具体的 `AGENTS.md` 仍可按 Codex 的指令优先级覆盖它们。

### `config.toml`

不修改 `config.toml`。当前未设置并发上限，没有证据表明其值为 `1`。避免为了本次需求新增不必要的全局配置。

## 验证

实施后执行以下检查：

1. 使用 UTF-8 读取并解析 `luna-worker.toml`，确认五个关键字段及三引号字符串有效。
2. 运行 `codex.cmd --strict-config features list`，确认当前 `config.toml` 没有未知字段。
3. 运行 `codex.cmd doctor --json`，检查 Agent 和全局配置诊断。
4. 对本次两个目标文件生成修改前后 diff；若 Agent 文件未变化，明确显示其验证结果而不是制造无意义改动。
5. 确认 `config.toml` 和其他 Agent 文件的哈希未改变。
6. 提醒用户新的全局 `AGENTS.md` 在新 Codex 会话中加载；当前已启动会话不会重新读取全局指令链。

## 安全与恢复

- 写入前保存两个目标文件的内存快照，并仅对目标路径使用原子替换。
- 不打印 `config.toml` 的无关内容，避免泄露潜在私密配置。
- 若验证失败，恢复本次变更前的目标文件内容；不操作其他配置。
- 本次不删除文件、不修改 Agent 并发上限、不启动 subagent、不更改项目代码。
