# Luna Worker Agent Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the valid global `luna_worker` definition, add global subagent-dispatch guidance, and prove the resulting Codex 0.146.1 configuration is valid without modifying unrelated settings.

**Architecture:** Treat `C:\Users\dongx\.codex` as protected global state. Stage the new `AGENTS.md` inside the writable project, capture hashes of all existing global configuration files, copy only the staged file to the previously absent target, then validate TOML, strict Codex configuration loading, instruction content, and unchanged-file hashes.

**Tech Stack:** Codex CLI 0.146.1, TOML, Markdown, PowerShell, Python 3.12 `tomllib`, SHA-256.

---

### Task 1: Stage the exact global guidance and capture the baseline

**Files:**
- Create: `.superpowers/config-staging/luna-worker/AGENTS.md`
- Generate: `.superpowers/config-staging/luna-worker/baseline.json`
- Read: `C:\Users\dongx\.codex\agents\luna-worker.toml`
- Read: `C:\Users\dongx\.codex\config.toml`
- Read: `C:\Users\dongx\.codex\agents\*.toml`

- [ ] **Step 1: Confirm the target state before writing**

Run with host-user access:

```powershell
$codexDir='C:\Users\dongx\.codex'
Test-Path -LiteralPath "$codexDir\AGENTS.md"
Get-Item -LiteralPath "$codexDir\agents\luna-worker.toml" | Select-Object FullName,Length
```

Expected: `AGENTS.md` is `False`; `luna-worker.toml` exists and is non-empty. Stop without writing if the target unexpectedly exists, then inspect and merge instead of overwriting.

- [ ] **Step 2: Capture hashes of all global files that must remain unchanged**

Run:

```powershell
$codexDir='C:\Users\dongx\.codex'
$baselineConfig=(Get-FileHash -Algorithm SHA256 -LiteralPath "$codexDir\config.toml").Hash
$baselineAgents=@{}
Get-ChildItem -LiteralPath "$codexDir\agents" -Filter '*.toml' -File | ForEach-Object {
    $baselineAgents[$_.FullName]=(Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
}
$manifest=[ordered]@{ configToml=$baselineConfig; agents=$baselineAgents }
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -LiteralPath '.superpowers\config-staging\luna-worker\baseline.json'
Get-Content -Raw -Encoding UTF8 -LiteralPath '.superpowers\config-staging\luna-worker\baseline.json'
```

Expected: `baseline.json` contains one `config.toml` hash and one hash per existing custom Agent.

- [ ] **Step 3: Stage the approved global instructions with `apply_patch`**

Create `.superpowers/config-staging/luna-worker/AGENTS.md` with exactly:

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

- [ ] **Step 4: Validate the staged text before copying**

Run:

```powershell
$staged='.superpowers\config-staging\luna-worker\AGENTS.md'
$text=Get-Content -Raw -Encoding UTF8 -LiteralPath $staged
$required=@('luna_worker','main thread','acceptance criteria','Git worktrees','serially','max_concurrent_threads_per_session','all other custom subagents','final verification')
$missing=$required | Where-Object { -not $text.Contains($_) }
if($missing){ throw "Missing guidance: $($missing -join ', ')" }
Write-Output 'STAGED_AGENTS_OK'
```

Expected: `STAGED_AGENTS_OK` with no missing terms.

---

### Task 2: Install only the global AGENTS.md

**Files:**
- Create: `C:\Users\dongx\.codex\AGENTS.md`
- Preserve: `C:\Users\dongx\.codex\agents\luna-worker.toml`
- Preserve: `C:\Users\dongx\.codex\config.toml`
- Preserve: every other file under `C:\Users\dongx\.codex\agents`

- [ ] **Step 1: Copy the staged file to the absent global target**

Run with host-user access:

```powershell
$source='C:\Users\dongx\Desktop\平和展会游戏\.superpowers\config-staging\luna-worker\AGENTS.md'
$target='C:\Users\dongx\.codex\AGENTS.md'
if(Test-Path -LiteralPath $target){ throw 'Refusing to overwrite an existing global AGENTS.md' }
Copy-Item -LiteralPath $source -Destination $target
Get-Item -LiteralPath $target | Select-Object FullName,Length
```

Expected: the new global file exists and is non-empty. Do not write `config.toml` or any Agent TOML file.

- [ ] **Step 2: Produce the requested unified diff**

Run:

```powershell
$empty='.superpowers\config-staging\luna-worker\before-AGENTS.md'
New-Item -ItemType File -Force -Path $empty | Out-Null
git diff --no-index -- $empty 'C:\Users\dongx\.codex\AGENTS.md'
```

Expected: exit code `1`, which is normal for `git diff --no-index` when differences exist, and a diff showing only the newly added global `AGENTS.md`. Record this output for the final report.

- [ ] **Step 3: Prove protected files are unchanged**

Read the saved baseline and run:

```powershell
$codexDir='C:\Users\dongx\.codex'
$baseline=Get-Content -Raw -Encoding UTF8 -LiteralPath '.superpowers\config-staging\luna-worker\baseline.json' | ConvertFrom-Json
if((Get-FileHash -Algorithm SHA256 -LiteralPath "$codexDir\config.toml").Hash -ne $baseline.configToml){ throw 'config.toml changed' }
foreach($property in $baseline.agents.psobject.Properties){
    if((Get-FileHash -Algorithm SHA256 -LiteralPath $property.Name).Hash -ne $property.Value){ throw "Agent changed: $($property.Name)" }
}
Write-Output 'PROTECTED_CONFIG_UNCHANGED'
```

Expected: `PROTECTED_CONFIG_UNCHANGED`.

---

### Task 3: Validate the custom Agent and effective Codex configuration

**Files:**
- Test: `C:\Users\dongx\.codex\agents\luna-worker.toml`
- Test: `C:\Users\dongx\.codex\AGENTS.md`
- Test: `C:\Users\dongx\.codex\config.toml`

- [ ] **Step 1: Parse and validate the Agent TOML with Python 3.12**

Run with host-user access:

```powershell
$pythonExe='C:\Users\dongx\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$agentPath='C:\Users\dongx\.codex\agents\luna-worker.toml'
& $pythonExe -c "import pathlib,tomllib; p=pathlib.Path(r'$agentPath'); d=tomllib.loads(p.read_text(encoding='utf-8')); required={'name','description','developer_instructions'}; missing=required-d.keys(); assert not missing, f'missing {missing}'; assert d['name']=='luna_worker'; assert d['model']=='gpt-5.6-luna'; assert d['model_reasoning_effort']=='max'; assert len(d['description'].strip())>=80; assert len(d['developer_instructions'].strip())>=500; print('LUNA_WORKER_TOML_OK')"
```

Expected: `LUNA_WORKER_TOML_OK` and exit code 0.

- [ ] **Step 2: Strict-load the current Codex config as the host user**

Run:

```powershell
codex.cmd --strict-config features list
```

Expected: exit code 0 with the known feature table and no unknown-field or TOML parse error.

- [ ] **Step 3: Run redacted Codex diagnostics and interpret only relevant checks**

Run:

```powershell
codex.cmd doctor --json
```

Expected: `checks.config.load.status` is `ok` and `codexVersion` is `0.146.1`. Overall Doctor may still report unrelated authentication, network, or terminal findings; those do not invalidate this configuration and must be reported separately rather than hidden.

- [ ] **Step 4: Verify global guidance content and absence of an override**

Run:

```powershell
$codexDir='C:\Users\dongx\.codex'
$text=Get-Content -Raw -Encoding UTF8 -LiteralPath "$codexDir\AGENTS.md"
if(Test-Path -LiteralPath "$codexDir\AGENTS.override.md"){ throw 'AGENTS.override.md would shadow the new global guidance' }
foreach($term in @('luna_worker','main thread','Git worktrees','acceptance criteria','max_concurrent_threads_per_session','all other custom subagents')){
    if(-not $text.Contains($term)){ throw "Missing global instruction: $term" }
}
Write-Output 'GLOBAL_AGENTS_OK'
```

Expected: `GLOBAL_AGENTS_OK`.

- [ ] **Step 5: Report the effective result and reload requirement**

Report:

- The unified diff for the new global `AGENTS.md`.
- `luna-worker.toml` was already compatible and remained byte-for-byte unchanged.
- `config.toml` and all other Agent files remained unchanged.
- TOML parsing, strict configuration loading, and relevant Doctor configuration checks passed.
- Any unrelated Doctor warnings or failures by category.
- A new Codex task/session is required for global `AGENTS.md` discovery; the already running session does not rebuild its instruction chain.

If any validation in Steps 1–4 fails, remove only the newly created `C:\Users\dongx\.codex\AGENTS.md`, report the exact failure, and leave all pre-existing files untouched.
