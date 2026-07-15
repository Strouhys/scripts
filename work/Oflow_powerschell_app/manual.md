# oflow User Manual

> Version: 2.0 | Last updated: 2026-04-27

## Table of Contents

1. [What Is oflow](#1-what-is-oflow)
2. [Job Designer](#2-job-designer)
3. [Job Execution and Transitions](#3-job-execution-and-transitions)
4. [State Handling](#4-state-handling)
5. [Logging](#5-logging)
6. [Configuration](#6-configuration)
7. [REST API](#7-rest-api)
8. [Web Frontend (oflow-web)](#8-web-frontend-oflow-web)
9. [API Quick Reference](#9-api-quick-reference)
10. [PowerShell API Reference](#10-powershell-api-reference)
11. [Windows firewall settings](#11-windows-firewall-settings)

---

## 1. What Is oflow

oflow is a lightweight task scheduler and executor. It runs jobs — external processes defined as JSON files — on a schedule, retries them on failure, and exposes a REST API for monitoring and control.

**Designed for:**

- Operations teams that need to run recurring scripts (ETL pipelines, data exports, cleanup tasks) without a heavy workflow engine.
- Environments where simplicity matters more than distributed orchestration — one machine, one scheduler, predictable behavior.

**Key characteristics:**

- **In-memory** — no database. Job definitions are JSON files on disk. Runtime state lives in memory with optional persistence to a state file for restartability across planned restarts.
- **Cross-platform** — runs on Windows (production) and Linux (development). Same binary, same behavior.
- **Self-contained** — single binary, no external dependencies at runtime.
- **Observable** — structured JSON logs, REST API for status and control, optional web dashboard.

**Architecture at a glance:**

```
                  +-----------+
                  | REST API  |  (bearer token auth)
                  +-----+-----+
                        |
           +------------+------------+
           |                         |
     +-----v------+          +------v------+
     | RunningPool |<-------->|  JobQueue   |
     | (scheduler) |  scans   | (job defs)  |
     +-----+------+          +-------------+
           |
     +-----v------+
     |  JobRun(s)  |  (goroutines)
     +-------------+
```

The **JobQueue** holds job definitions loaded from disk at startup. The **RunningPool** is the scheduler — it periodically scans the queue for eligible jobs and starts them as child processes, each in its own goroutine. The **REST API** allows external tools (and the web dashboard) to observe and control the system.

---

## 2. Job Designer

A job definition is a single JSON file placed in the `jobs_definition_dir` directory (configured in the oflow config file). oflow scans this directory at startup and loads every `*.json` file as a job.

### File Format

```json
{
  "name": "etl-daily",
  "command_line": ["python", "/opt/scripts/etl.py", "--full"],
  "priority": 10,
  "first_run_attempt": "2026-01-01T06:00:00Z",
  "restart_after_seconds": 86400,
  "max_runs": 3,
  "max_run_time_seconds": 3600
}
```

Each file defines exactly one job. The file name does not matter — oflow uses the `name` field as the unique identifier.

### Environment Variable Templates

Job definition files support **environment variable substitution** using Go's [text/template](https://pkg.go.dev/text/template) syntax. Any occurrence of `{{.VAR_NAME}}` in the JSON file is replaced with the value of the environment variable `VAR_NAME` when oflow loads the file at startup.

This is useful when the same job definitions are deployed across multiple environments (dev, staging, production) and only paths, hostnames, or credentials differ between them.

#### Syntax

Use `{{.VAR_NAME}}` anywhere in the JSON file — inside string values, inside array elements, etc. The placeholder is replaced with the literal value of the environment variable before JSON parsing.

```json
{
  "name": "etl-daily",
  "command_line": ["python", "{{.SCRIPT_DIR}}/etl.py", "--db={{.DB_HOST}}"],
  "priority": 10,
  "first_run_attempt": "2026-01-01T06:00:00Z",
  "restart_after_seconds": 86400,
  "max_runs": 3,
  "max_run_time_seconds": 3600
}
```

If the environment has `SCRIPT_DIR=/opt/scripts` and `DB_HOST=db.prod.local`, the loaded job will have:

```json
"command_line": ["python", "/opt/scripts/etl.py", "--db=db.prod.local"]
```

#### Error on missing variables

If any referenced environment variable is **not set**, oflow refuses to start and prints an error listing all missing variables:

```
error loading job definitions: loading job from etl_daily.json: expanding env templates: environment variable(s) not set: SCRIPT_DIR, DB_HOST
```

This is intentional — a job with unresolved placeholders would execute with broken arguments. oflow fails fast so the operator can set the required variables before starting.

#### Rules and notes

- **Only `{{.VAR_NAME}}` syntax is supported.** Shell-style `$VAR` or `${VAR}` is not recognized.
- **Job definition files only.** Environment variable templates work **only** in job definition JSON files loaded from `jobs_definition_dir`, not in the main oflow config file (e.g., the file passed to `-config`). The main config file is loaded directly without template expansion.
- **Expansion happens once at startup.** Changing an environment variable after oflow has started has no effect on already-loaded job definitions.
- **No templates = no change.** Files without any `{{...}}` placeholders are loaded exactly as before — this feature is fully backward compatible.
- **All missing variables are reported at once.** If a file references three undefined variables, the error message lists all three, not just the first one.
- **The variable must exist.** An empty string (`VAR=""`) is a valid value and will be substituted. Only truly unset variables cause an error.
- **Path handling (Windows).** When using environment variables for file paths (especially on Windows), backslashes in the path are automatically escaped to produce valid JSON. For example, `F:\Logs` becomes `F:\\Logs` in the JSON output, which is correct.

### Field Reference

#### `name` (string, required)

Unique identifier for the job. Must be unique across all job definition files — oflow refuses to start if two files contain the same name.

**Used internally:** The scheduler uses this name to check whether a job is already in the pool (running, retrying, or dead). A job will not be started again while any JobRun with the same name exists in the pool.

#### `command_line` (string array, required)

The command and its arguments. The first element is the executable; the rest are arguments passed to it.

```json
"command_line": ["python", "/opt/scripts/etl.py", "--full"]
```

oflow executes this using Go's `os/exec` package. The executable must be in the system PATH or specified as an absolute path. On Windows, this means `.exe`, `.bat`, `.cmd`, or any executable recognized by the OS. On Linux, the file must have execute permission.

**Used internally:** Passed directly to `exec.Command(command_line[0], command_line[1:]...)`. stdout and stderr of the process are captured and stored on the JobRun for inspection via the API.

#### `priority` (integer, required)

Higher number = higher priority. When the scheduler has more eligible jobs than available capacity slots, it starts higher-priority jobs first.

**Used internally:** The scheduler sorts eligible jobs by `priority` descending, then by time-since-last-change ascending (as a fairness tiebreaker). Jobs with higher priority values are started before jobs with lower priority values.

**Example:** If you have a critical ETL job and a nice-to-have report, give the ETL `priority: 100` and the report `priority: 10`.

#### `first_run_attempt` (timestamp, required)

The earliest time the job may be scheduled for its first run. Format: ISO 8601 (`"2026-01-01T06:00:00Z"` for UTC, or `"2026-01-01T06:00:00"` for local time).

**Used internally:** The scheduler checks `first_run_attempt <= now` before considering a job eligible. If the timestamp is in the future, the job is skipped until that time arrives. This lets you define jobs in advance that should not start until a specific date.

**Runtime override:** The `PUT /set_job_first_run_attempt/{name}` API endpoint can change this value at runtime, allowing you to pause a job by pushing the timestamp into the future or re-enable it by setting it to the past.

#### `restart_after_seconds` (integer, required, >= 0)

Minimum number of seconds that must pass since the job's last **successful** completion before the scheduler will start a new instance. This controls how frequently a recurring job runs.

**Used internally:** After a job succeeds and is removed from the pool, the scheduler will not start a new run of the same job until `restart_after_seconds` have elapsed since the successful completion. Set to `0` to allow immediate re-scheduling after success.

**Important:** This only applies to new scheduling cycles. It does **not** affect auto-retries after failure — those are controlled by `retry_backoff_seconds` (a global config setting, not per-job).

#### `max_runs` (integer, required, >= 1)

Maximum number of execution attempts. If a job fails, oflow retries it automatically up to `max_runs` times. After that, the job is moved to `failed_final` status and stops retrying.

**Used internally:**

- **Attempt 1:** Job starts for the first time. `RunCount = 1`.
- **Failure (RunCount < max_runs):** Status becomes `failed_restart`. The job holds its pool slot and retries automatically after `retry_backoff_seconds`.
- **Failure (RunCount >= max_runs):** Status becomes `failed_final`. The job is moved to the dead jobs graveyard, freeing its pool slot. It will not run again unless manually restarted via the API.
- **Success at any attempt:** Status becomes `succeeded`. The job is removed from the pool entirely.

**Example scenarios:**

| `max_runs` | Behavior                                                     |
| ---------- | ------------------------------------------------------------ |
| `1`        | No retries. Fails once → `failed_final`.                     |
| `3`        | Up to 2 automatic retries (3 total attempts).                |
| `10`       | Up to 9 automatic retries. Useful for flaky network scripts. |

#### `max_run_time_seconds` (integer, required, >= 0)

Maximum wall-clock time the process may run, in seconds. If the process is still running after this many seconds, oflow kills it.

**Used internally:**

- **`0`:** No time limit. The process runs until it finishes on its own.
- **`> 0`:** A deadline is set when the process starts. If the deadline is exceeded, oflow sends a kill signal to the process. The killed process is treated as a **failure** — it follows the same `max_runs` retry logic as a non-zero exit code. The `termination_reason` in the log will be `"timeout"`.

**Why this matters:** Without a time limit, a hung process would hold its pool slot forever, blocking other jobs. Always set a reasonable `max_run_time_seconds` for production jobs.

**Example:** A script that normally takes 5 minutes should have `max_run_time_seconds: 600` (10 minutes) to allow for occasional slowness while still catching genuine hangs.

### Complete Examples

**Daily ETL job — runs once per day, retries up to 3 times, 1 hour timeout:**

```json
{
  "name": "etl-daily",
  "command_line": ["python", "/opt/scripts/etl.py", "--full"],
  "priority": 100,
  "first_run_attempt": "2026-01-01T06:00:00Z",
  "restart_after_seconds": 86400,
  "max_runs": 3,
  "max_run_time_seconds": 3600
}
```

**Frequent health check — every 5 minutes, no retries, 30 second timeout:**

```json
{
  "name": "health-check",
  "command_line": ["/usr/local/bin/check-services.sh"],
  "priority": 1,
  "first_run_attempt": "2026-01-01T00:00:00Z",
  "restart_after_seconds": 300,
  "max_runs": 1,
  "max_run_time_seconds": 30
}
```

**One-shot migration — run once at a specific time, retry up to 5 times, no timeout:**

```json
{
  "name": "db-migration-v42",
  "command_line": ["python", "/opt/scripts/migrate.py", "--version", "42"],
  "priority": 50,
  "first_run_attempt": "2026-04-01T02:00:00Z",
  "restart_after_seconds": 999999999,
  "max_runs": 5,
  "max_run_time_seconds": 0
}
```

Setting `restart_after_seconds` to a very large value effectively makes the job run only once — after the first success, the scheduler will not re-start it for ~31 years.

**Windows job — runs a PowerShell script:**

```json
{
  "name": "cleanup-temp",
  "command_line": ["powershell", "-File", "C:\\Scripts\\cleanup.ps1"],
  "priority": 5,
  "first_run_attempt": "2026-01-01T00:00:00Z",
  "restart_after_seconds": 3600,
  "max_runs": 2,
  "max_run_time_seconds": 120
}
```

**Job using environment variable templates — outputs log to directory from `ONDP_TENANT_LOG_DIR`:**

This example shows a job that uses environment variable templates to reference the tenant log directory. The `ONDP_TENANT_LOG_DIR` environment variable must be set before oflow starts.

```json
{
  "name": "tenant-report",
  "command_line": ["python", "/opt/scripts/generate_report.py", "--output", "{{.ONDP_TENANT_LOG_DIR}}/report.log"],
  "priority": 50,
  "first_run_attempt": "2026-01-01T12:00:00Z",
  "restart_after_seconds": 86400,
  "max_runs": 3,
  "max_run_time_seconds": 1800
}
```

Before starting oflow, set the environment variable:

```bash
export ONDP_TENANT_LOG_DIR="/var/log/oflow/tenants"
oflow -config /etc/oflow/config.json
```

When oflow loads this job at startup, it will expand `{{.ONDP_TENANT_LOG_DIR}}` to the actual directory path (e.g., `/var/log/oflow/tenants`), resulting in:

```json
"command_line": ["python", "/opt/scripts/generate_report.py", "--output", "/var/log/oflow/tenants/report.log"]
```

### Validation Rules

oflow validates every job definition at startup and refuses to start if any file is invalid:

- `name` must be non-empty and unique across all files
- `command_line` must have at least one element
- `max_runs` must be >= 1
- `max_run_time_seconds` must be >= 0
- `restart_after_seconds` must be >= 0
- All environment variable templates (`{{.VAR_NAME}}`) must resolve to set variables (see [Environment Variable Templates](#environment-variable-templates))

---

## 3. Job Execution and Transitions

### Lifecycle Overview

A job goes through several phases from the moment oflow starts to the moment the job finishes:

```
Job definition (JSON file on disk)
  │
  ▼
JobQueue (loaded at startup)
  │
  ├──► scheduler tick (every running_pool_sleep_seconds)
  │      │
  │    Eligible? ──no──► skip (check again next tick)
  │      │
  │      yes
  │      │
  │    Capacity available? ──no──► skip (check again next tick)
  │      │
  │      yes
  │      ▼
  │    Start process ──► JobRun created (status: running)
  │
  └──► API: GET /start_job/{name}  (immediate, bypasses scheduler loop)
         │
       Not in pool? ──no──► 409 Conflict (already_in_pool)
         │
         yes
         │
         ▼
       Start process ──► JobRun created (status: running)
       (starts even if pool is full — oversubscription)
  │
  ▼
Process finishes
  │
  ├── exit code 0 ──────────────────────────► succeeded (removed from pool)
  │
  ├── exit code != 0 or timeout
  │     ├── RunCount < max_runs ────────────► failed_restart (retry after backoff)
  │     └── RunCount >= max_runs ───────────► failed_final (moved to dead jobs)
  │
  └── cancelled via API ────────────────────► cancelled (moved to dead jobs)
```

### Scheduling: How Jobs Become Eligible

Every `running_pool_sleep_seconds` seconds, the scheduler wakes up and evaluates all job definitions in the queue. A job is **eligible** to run when all of these are true:

1. **`first_run_attempt` is in the past** — the scheduled start time has arrived.
2. **Enough time since last success** — at least `restart_after_seconds` have passed since this job last completed successfully. For a job that has never run, this condition is always met.
3. **Not already in the pool** — no JobRun with this job's name exists in the pool, neither active (running, failed_restart) nor dead (failed_final, cancelled). A dead job blocks re-scheduling until it is explicitly removed via the `/restart_job` API.

When multiple jobs are eligible but capacity is limited, the scheduler sorts them by:

1. **`priority` descending** — higher-priority jobs first.
2. **Last change ascending** — among equal priority, the job that has waited longest goes first (fairness).

Jobs are started from this sorted list until the pool is full (`len(active_jobs) >= running_pool_cap`).

### Execution: What Happens When a Job Runs

When the scheduler starts a job:

1. A new **JobRun** is created with a unique sequential ID, `status: running`, and `RunCount: 1`.
2. The JobRun is added to the pool's active jobs map (consumes one capacity slot).
3. A new goroutine launches the process via `os/exec`.
4. stdout and stderr are captured in memory. When the job finishes, the log entry contains `stdout_head` and `stderr_head` (the first 2400 characters). If the output exceeds 4800 characters, the log also contains `stdout_tail` / `stderr_tail` (the last 2400 characters). Outputs of 4800 characters or fewer are stored entirely in the `_head` field.
5. If `max_run_time_seconds > 0`, a deadline timer is set. When it fires, the process is killed.
6. The goroutine waits for the process to exit.

### How Each Field Affects Execution

#### `max_run_time_seconds` in action

When the process starts, oflow creates a context with a deadline:

- The process has exactly `max_run_time_seconds` wall-clock seconds to complete.
- If it finishes before the deadline: normal completion (exit code determines success/failure).
- If it exceeds the deadline: oflow kills the process. The log entry will contain `"termination_reason": "timeout"`. The kill is treated as a **failure** — not a cancellation — so retry logic applies based on `max_runs`.

This is deliberate: a timeout might be caused by temporary system load, so retrying makes sense. Only explicit API cancellation produces the terminal `cancelled` status.

#### `max_runs` in action

`max_runs` controls how many times oflow will attempt to run the process before giving up:

```
Attempt 1 (RunCount=1): process fails
  → RunCount (1) < max_runs (3) → status: failed_restart
  → wait retry_backoff_seconds...

Attempt 2 (RunCount=2): process fails again
  → RunCount (2) < max_runs (3) → status: failed_restart
  → wait retry_backoff_seconds...

Attempt 3 (RunCount=3): process fails again
  → RunCount (3) >= max_runs (3) → status: failed_final
  → moved to dead jobs, slot freed, no more retries
```

The same JobRun object is reused across retries — the ID stays the same, `RunCount` increments, and stdout/stderr are cleared before each new attempt.

#### `restart_after_seconds` in action

This field controls recurring execution. After a job **succeeds**:

1. The JobRun is removed from the pool (frees the slot, removes the name block).
2. On the next scheduler tick, the job definition is eligible again — but only if `restart_after_seconds` have passed since the successful completion.

This creates a natural recurring pattern: job runs → succeeds → waits → runs again.

**Note:** `restart_after_seconds` has no effect on failure retries. Failed jobs use `retry_backoff_seconds` (a global config value) for the delay between retry attempts. The distinction:

| Scenario                       | Delay field             | Scope                       |
| ------------------------------ | ----------------------- | --------------------------- |
| After success, before next run | `restart_after_seconds` | Per-job (in job definition) |
| After failure, before retry    | `retry_backoff_seconds` | Global (in oflow config)    |

### Status Transitions

```
  running        ──► succeeded        (exit code 0)
  running        ──► failed_restart   (exit code != 0 OR timeout, RunCount < max_runs)
  running        ──► failed_final     (exit code != 0 OR timeout, RunCount >= max_runs)
  running        ──► cancelled        (API cancel request only)
  failed_restart ──► running          (automatic, after retry_backoff_seconds)
  failed_final   ──► [removed]        (API restart: removes from dead jobs, re-eligible for scheduler)
  cancelled      ──► [removed]        (API restart: removes from dead jobs, re-eligible for scheduler)
```

#### Status details

| Status           | Meaning                             |           Consumes slot?            |  Blocks re-scheduling?  | Available actions |
| ---------------- | ----------------------------------- | :---------------------------------: | :---------------------: | ----------------- |
| `running`        | Process is executing                |                 Yes                 |           Yes           | Cancel            |
| `failed_restart` | Failed, waiting for automatic retry | Yes (holds its slot during backoff) |           Yes           | Cancel            |
| `failed_final`   | Failed, all retries exhausted       |       No (moved to dead jobs)       | Yes (name still blocks) | Restart           |
| `cancelled`      | Explicitly cancelled via API        |       No (moved to dead jobs)       | Yes (name still blocks) | Restart           |
| `succeeded`      | Process exited with code 0          |        No (removed entirely)        |           No            | —                 |

#### What "Restart" does (for failed_final / cancelled)

The `/restart_job/{id}` API endpoint removes the dead JobRun from the graveyard. This unblocks the job's name, making the job definition eligible for the scheduler again. The job is **not** started immediately — it goes through the normal scheduling loop on the next tick, respecting capacity limits and `first_run_attempt`.

#### What "Cancel" does (for running / failed_restart)

The `/cancel_job/{id}` API endpoint:

- **For `running` jobs:** Kills the process. The endpoint waits up to 5 seconds for the process to terminate before responding.
- **For `failed_restart` jobs:** Aborts the pending auto-retry immediately. No process is running, so there is nothing to kill.

In both cases, the status becomes `cancelled` and the JobRun is moved to dead jobs.

### Auto-Retry Mechanism

When a job enters `failed_restart`:

1. The JobRun stays in the active pool, holding its capacity slot. This prevents the scheduler from starting a different job in its place (the retry is already "booked").
2. oflow waits for `retry_backoff_seconds` (global config).
3. After the backoff: `RunCount` is incremented, stdout/stderr are cleared, status is set back to `running`, and the process starts again.
4. This repeats until the job succeeds, exhausts `max_runs`, or is cancelled via the API.

---

## 4. State Handling

### In-Memory Model

All runtime state lives in memory. There is no database. The two core data structures are:

- **JobQueue** — the set of job definitions, loaded from JSON files at startup. Read-only during runtime (except `first_run_attempt` which can be changed via the API).
- **RunningPool** — the scheduler's working state: active jobs (running, failed_restart) and dead jobs (failed_final, cancelled), capacity settings, and statistics counters.

### State File Persistence

oflow can save and restore its pool state to a JSON file (configured via `state_file`). This provides **restartability** — the ability to shut down and restart oflow without losing track of which jobs have run, failed, or are waiting for retry.

**When state is saved:**

- During graceful shutdown (SIGINT, SIGTERM, or `/shutdown` API). The shutdown sequence sets pool capacity to 0, waits for all running jobs to finish, then writes the state file.

**When state is loaded:**

- At startup, if the `state_file` exists. oflow restores the pool from the file, then re-links each restored JobRun to its corresponding job definition loaded from disk. If a job definition no longer exists (the file was removed), the orphaned JobRun is discarded.

**What is saved:**

- All active JobRuns (running, failed_restart) — their ID, status, run count, stdout, stderr, timestamps, and job name.
- All dead JobRuns (failed_final, cancelled) — same fields.
- The ID counter (so new IDs continue from where they left off).
- Pool metadata (capacity, sleep interval, running-since timestamp).

**What is NOT saved:**

- Statistics counters (total executed, total restarts to success) — these reset on restart.
- Job definitions — these are always loaded fresh from the `jobs_definition_dir` at startup.

### Restartability Behavior

After a restart, previously `failed_restart` jobs will remain in the pool but their retry timers are gone — the scheduler will need to re-evaluate them. Previously `running` jobs are restored with `running` status but no process is actually running — the execution goroutine is gone. In practice, these jobs should be cancelled and restarted manually, or the operator should clear the state file for a clean start.

**Clean start:** Delete the state file before starting oflow to start with an empty pool.

---

## 5. Logging

### Format and Output

oflow writes structured JSON logs to a rotating log file. Each log line is a single JSON object:

```json
{"time":"2026-03-25T10:05:00.123Z","level":"INFO","msg":"job started","job_name":"etl-daily","command":"python /opt/scripts/etl.py --full","run_count":1,"max_runs":3}
```

The log file path, rotation, and behavior are controlled by the oflow config file (see [Configuration](#6-configuration)).

### Log Rotation

oflow uses lumberjack for log rotation:

| Config field    | Effect                                                                                  |
| --------------- | --------------------------------------------------------------------------------------- |
| `log_file_name` | Full path to the log file. The directory is created automatically if it does not exist. |
| `max_size_mb`   | Maximum size of a single log file in megabytes before rotation.                         |
| `max_backups`   | Number of old rotated log files to keep.                                                |
| `max_age_days`  | Days to retain old rotated files.                                                       |
| `compress_logs` | Whether to gzip rotated files.                                                          |

### Log Levels

oflow supports four log levels, configurable via `log_level` in the config file. The default is `"info"`.

| Level     | Purpose                                                    | When to use                                                                       |
| --------- | ---------------------------------------------------------- | --------------------------------------------------------------------------------- |
| **DEBUG** | Operational trace. Noisy.                                  | Troubleshooting — turn on temporarily to see exactly what the scheduler is doing. |
| **INFO**  | Business events. What the system is doing at a high level. | Normal production operation.                                                      |
| **WARN**  | Suspicious conditions.                                     | Monitoring — worth investigating but not necessarily broken.                      |
| **ERROR** | Failures requiring attention.                              | Alerting — something went wrong that an operator should look at.                  |

**What each level includes:**

| Event                                            | Level |
| ------------------------------------------------ | ----- |
| oflow starting/stopping                          | INFO  |
| Job started                                      | INFO  |
| Job succeeded                                    | INFO  |
| Job failed (any reason)                          | ERROR |
| Job exhausted retries (failed_final)             | ERROR |
| Job cancelled                                    | ERROR |
| State save failure                               | ERROR |
| Auth failure (wrong/missing token)               | WARN  |
| Cancel-wait timeout                              | WARN  |
| PID assignment                                   | DEBUG |
| Scheduler tick (eligible/started/capacity stats) | DEBUG |
| Auto-retry scheduling                            | DEBUG |
| API request logging                              | DEBUG |
| Pool drain waiting (during shutdown)             | DEBUG |
| Dead job removal / restart via API               | DEBUG |

**Recommendation:** Use `"info"` for production. Switch to `"debug"` temporarily when investigating scheduling issues or unexpected behavior. Avoid `"debug"` in long-running production — it generates a log entry on every scheduler tick (every few seconds).

### Source Location

When `log_source_of_message` is set to `true` in the config, every log record includes a `"source"` object with the Go function name, source file, and line number:

```json
{"time":"...","level":"INFO","source":{"function":"...","file":"executor.go","line":142},"msg":"job started",...}
```

This is disabled by default. Enable it for development or when debugging issues where you need to know exactly which code path emitted a log.

### The `termination_reason` Field

Job completion logs include a `termination_reason` field that tells you **how** the process ended:

| Value             | Meaning                                                        |
| ----------------- | -------------------------------------------------------------- |
| *(empty string)*  | Success — process exited with code 0.                          |
| `"timeout"`       | Killed by oflow because `max_run_time_seconds` was exceeded.   |
| `"cancelled"`     | Killed because of an API cancel request or scheduler shutdown. |
| `"process_exit"`  | Process exited on its own with a non-zero exit code.           |
| `"start_failure"` | Process could not be started (e.g., executable not found).     |

**Why this matters:** Without `termination_reason`, a timeout kill and a genuine process failure both look like "exit code -1" in the logs. This field lets you tell them apart — critical when a process takes close to its `max_run_time_seconds` and you need to know whether it was killed or failed on its own.

**Example log entries:**

Success:
```json
{"level":"INFO","msg":"job succeeded","job_name":"etl-daily","exit_code":0,"status":"succeeded","termination_reason":"","run_count":1}
```

Timeout:
```json
{"level":"ERROR","msg":"job failed","job_name":"etl-daily","exit_code":-1,"status":"failed_restart","termination_reason":"timeout","run_count":1,"error":"signal: killed"}
```

Process failure:
```json
{"level":"ERROR","msg":"job failed","job_name":"etl-daily","exit_code":1,"status":"failed_final","termination_reason":"process_exit","run_count":3,"error":"exit status 1"}
```

---

## 6. Configuration

oflow is configured via a JSON file. The path is provided as a command-line flag:

```bash
oflow -config /etc/oflow/config.json
```

### Complete Example

```json
{
  "log_file_name": "/var/log/oflow/oflow.log",
  "max_size_mb": 100,
  "max_backups": 10,
  "max_age_days": 30,
  "compress_logs": true,
  "state_file": "/var/lib/oflow/state.json",
  "jobs_definition_dir": "/etc/oflow/jobs",
  "api_port": 4444,
  "running_pool_cap": 10,
  "running_pool_sleep_seconds": 5,
  "retry_backoff_seconds": 30,
  "log_source_of_message": false,
  "log_level": "info"
}
```

### Field Reference

| Field                        | Type   | Required | Default  | Description                                                                         |
| ---------------------------- | ------ | :------: | -------- | ----------------------------------------------------------------------------------- |
| `log_file_name`              | string |   yes    | —        | Full path to the log file. Directory is created automatically.                      |
| `max_size_mb`                | int    |   yes    | —        | Max log file size (MB) before rotation. Must be > 0.                                |
| `max_backups`                | int    |   yes    | —        | Number of old rotated log files to retain. Must be >= 0.                            |
| `max_age_days`               | int    |   yes    | —        | Days to retain old rotated log files. Must be >= 0.                                 |
| `compress_logs`              | bool   |   yes    | —        | Gzip rotated log files.                                                             |
| `state_file`                 | string |   yes    | —        | Path to the JSON state file for persistence.                                        |
| `jobs_definition_dir`        | string |   yes    | —        | Directory containing job definition `*.json` files.                                 |
| `api_port`                   | int    |   yes    | —        | Port for the REST API. Must be > 0.                                                 |
| `running_pool_cap`           | int    |   yes    | —        | Maximum number of concurrent active jobs (running + failed_restart). Must be > 0.   |
| `running_pool_sleep_seconds` | int    |   yes    | —        | Seconds between scheduler queue scans. Must be > 0.                                 |
| `retry_backoff_seconds`      | int    |   yes    | —        | Seconds to wait before retrying a failed job. Must be > 0.                          |
| `log_source_of_message`      | bool   |    no    | `false`  | Include function name, file, and line number in log records.                        |
| `log_level`                  | string |    no    | `"info"` | Minimum log level: `"debug"`, `"info"`, `"warn"`, `"error"`.                        |
| `tls_cert_file`              | string |    no    | `""`     | Path to PEM-encoded TLS certificate file. If set, `tls_key_file` must also be set.  |
| `tls_key_file`               | string |    no    | `""`     | Path to PEM-encoded TLS private key file. If set, `tls_cert_file` must also be set. |

### Environment Variables

| Variable            | Required | Description                                                                                                |
| ------------------- | :------: | ---------------------------------------------------------------------------------------------------------- |
| `ONDP_OFLOW_AUTH`   |   yes    | Bearer token for API authentication. oflow refuses to start if not set.                                    |
| `ONDP_TENANT_LOG_DIR` |   no   | Directory containing job log files (`<job_name>.log`). Required for the `GET /job_log/{name}` endpoint. Can be used in job definition files via template syntax (e.g., `"command_line": ["script", "{{.ONDP_TENANT_LOG_DIR}}/output.log"]`). |

### Startup Checks

oflow performs these checks at startup (in order):

1. `-config` flag is provided and points to a readable file.
2. Config file is valid JSON and passes all field validation.
3. `ONDP_OFLOW_AUTH` environment variable is set (non-empty).
4. No other oflow instance is running on the same port (sends `GET /status` to `127.0.0.1:{api_port}`).
5. `jobs_definition_dir` exists and all `*.json` files inside are valid job definitions. This includes resolving any environment variable templates (`{{.VAR_NAME}}`) — all referenced variables must be set.
6. State file (if it exists) is valid and restorable.

If any check fails, oflow prints an error to stderr and exits with code 1.

**Note on `ONDP_TENANT_LOG_DIR`:** Unlike `ONDP_OFLOW_AUTH`, the `ONDP_TENANT_LOG_DIR` environment variable is **optional** and is **not checked at startup**. It is only verified at runtime when a request arrives at the `GET /job_log/{name}` endpoint. If `ONDP_TENANT_LOG_DIR` is not set, the endpoint will return a 500 error, but oflow will start successfully. If you use `ONDP_TENANT_LOG_DIR` in a job definition template (e.g., `"command_line": ["script", "{{.ONDP_TENANT_LOG_DIR}}/output.log"]`), the variable **must** be set at startup, otherwise job loading will fail during check #5.

### TLS / HTTPS (Optional)

oflow supports opt-in TLS. When `tls_cert_file` and `tls_key_file` are both set in the config, the REST API serves HTTPS instead of HTTP. When both fields are absent or empty, behavior is identical to plain HTTP — no existing deployment is affected.

**There is no mixed mode.** A server is either fully HTTP or fully HTTPS. HTTP requests to an HTTPS port fail with a TLS handshake error; there is no automatic redirect.

**Example config with TLS enabled:**

```json
{
  "log_file_name": "/var/log/oflow/oflow.log",
  "max_size_mb": 100,
  "max_backups": 10,
  "max_age_days": 30,
  "compress_logs": true,
  "state_file": "/var/lib/oflow/state.json",
  "jobs_definition_dir": "/etc/oflow/jobs",
  "api_port": 4444,
  "running_pool_cap": 10,
  "running_pool_sleep_seconds": 5,
  "retry_backoff_seconds": 30,
  "log_level": "info",
  "tls_cert_file": "/etc/oflow/tls/server.crt",
  "tls_key_file": "/etc/oflow/tls/server.key"
}
```

**Validation rules:**

- Both fields must be either both set or both empty. Setting only one is a startup error.
- When set, both files must exist and be readable.
- The certificate and key must form a valid pair (`tls.LoadX509KeyPair` must succeed).
- Expired certificates are **not** rejected at startup — Go's TLS stack serves them and clients decide whether to accept.

**Startup instance check:** When TLS is configured, the `isAlreadyRunning` check probes the preferred protocol first (HTTPS), then falls back to the other (HTTP) with a WARN log. This handles the case where a previous instance was started with a different TLS setting.

**Certificate management:** oflow does not handle automatic certificate provisioning or rotation. Operators provide the cert and key files. To rotate certificates, replace the files on disk and restart oflow.

---

## 7. REST API

The REST API listens on the port configured in `api_port`. All responses are JSON.

### Authentication

Protected endpoints require a bearer token in the `Authorization` header:

```
Authorization: Bearer <token>
```

The token value must match the `ONDP_OFLOW_AUTH` environment variable. Missing or invalid tokens return `401 Unauthorized`.

**Public endpoints** (no token required): `GET /status`, `GET /jobs`, `GET /job/{name}`, `GET /next_jobs`.

**Protected endpoints** (token required): `GET /start_job/{name}`, `POST /start_jobs`, `GET /set_pool_capacity/{capacity}`, `GET /cancel_job/{id}`, `GET /restart_job/{id}`, `PUT /set_job_first_run_attempt/{name}`, `GET /job_stats/{name}`, `GET /job_log/{name}`, `GET /shutdown`.

> **HTTPS:** When TLS is configured (see [TLS / HTTPS](#tls--https-optional)), the API is served over HTTPS only. Replace `http://` with `https://` in all examples below. For self-signed certificates, use `curl -k` (skip verification) or `curl --cacert /path/to/ca.crt` (custom CA). The bearer token is transmitted in the clear over HTTP — **enabling TLS is strongly recommended** for any non-localhost deployment.

### Error Format

All errors return a consistent JSON structure:

```json
{"error": "error message"}
```

### Endpoints

#### GET /status

Returns the current state of oflow — pool capacity, active and dead jobs.

```bash
curl http://localhost:4444/status

# HTTPS (self-signed cert)
curl -k https://localhost:4444/status
```

**Response 200:**

```json
{
  "status": "running",
  "running_since": "2026-03-25T10:00:00Z",
  "pool": {
    "capacity": 10,
    "used": 3,
    "sleep_seconds": 5,
    "total_executed": 47,
    "total_restarts_to_success": 5,
    "current_failed": 1,
    "jobs": [
      {
        "id": 12,
        "job_name": "etl-daily",
        "status": "failed_final",
        "run_count": 3,
        "last_change": "2026-03-25T10:01:00Z"
      },
      {
        "id": 15,
        "job_name": "report-gen",
        "status": "failed_restart",
        "run_count": 2,
        "last_change": "2026-03-25T10:03:00Z"
      },
      {
        "id": 18,
        "job_name": "health-check",
        "status": "running",
        "run_count": 1,
        "last_change": "2026-03-25T10:05:00Z"
      }
    ]
  }
}
```

The jobs list is sorted by status priority (failed_final first, then failed_restart, cancelled, running, succeeded), then by last change (oldest first).

**Pool fields:**

| Field                       | Meaning                                                                         |
| --------------------------- | ------------------------------------------------------------------------------- |
| `capacity`                  | Current max concurrent active jobs                                              |
| `used`                      | Number of active jobs (running + failed_restart) — these consume capacity slots |
| `sleep_seconds`             | Scheduler tick interval                                                         |
| `total_executed`            | Total jobs completed since oflow started (resets on restart)                    |
| `total_restarts_to_success` | Jobs that succeeded after at least one retry                                    |
| `current_failed`            | Number of `failed_final` jobs in the dead pool                                  |

**jq examples:**

```bash
# Pretty-print the full status
curl -s http://localhost:4444/status | jq .

# Pool capacity and usage
curl -s http://localhost:4444/status | jq '{capacity: .pool.capacity, used: .pool.used}'

# List job names and their statuses
curl -s http://localhost:4444/status | jq '.pool.jobs[] | {name: .job_name, status: .status}'

# Only failed jobs (failed_final or failed_restart)
curl -s http://localhost:4444/status | jq '[.pool.jobs[] | select(.status | startswith("failed"))]'

# Get IDs of all failed_final jobs (useful for scripted restarts)
curl -s http://localhost:4444/status | jq '[.pool.jobs[] | select(.status == "failed_final") | .id]'

# Count running jobs
curl -s http://localhost:4444/status | jq '[.pool.jobs[] | select(.status == "running")] | length'
```

#### GET /jobs

Returns the names of all configured job definitions. Supports optional `mask` query parameter for filtering (case-insensitive substring match).

```bash
# All jobs
curl http://localhost:4444/jobs

# Filter by name
curl "http://localhost:4444/jobs?mask=etl"
```

**Response 200:**

```json
{"jobs": ["etl-daily", "etl-hourly", "etl-weekly"]}
```

#### GET /job/{name}

Returns the full definition of a single job by exact name.

```bash
curl http://localhost:4444/job/etl-daily
```

**Response 200:**

```json
{
  "name": "etl-daily",
  "command_line": ["python", "/opt/scripts/etl.py", "--full"],
  "priority": 100,
  "first_run_attempt": "2026-01-01T06:00:00",
  "restart_after_seconds": 86400,
  "max_runs": 3,
  "max_run_time_seconds": 3600
}
```

**Response 404:**

```json
{"error": "job not found"}
```

#### GET /next_jobs

Returns the jobs that will run next, sorted by soonest first. Jobs currently in the pool are excluded.

Supports an optional `limit` query parameter to cap the number of results (default 50, max 500).

```bash
curl http://localhost:4444/next_jobs

# Limit to 10 results
curl "http://localhost:4444/next_jobs?limit=10"
```

**Response 200:**

```json
{
  "next_jobs": [
    {
      "job_name": "etl-hourly",
      "next_run": "2026-03-25T11:00:00",
      "reason": "restart_after_seconds",
      "seconds_until": 120
    },
    {
      "job_name": "etl-daily",
      "next_run": "2026-03-26T06:00:00",
      "reason": "first_run_attempt",
      "seconds_until": 72000
    }
  ],
  "limit": 50
}
```

| Field           | Meaning                                                                        |
| --------------- | ------------------------------------------------------------------------------ |
| `job_name`      | Name of the job                                                                |
| `next_run`      | Earliest time the job becomes eligible (local server time)                     |
| `reason`        | Why this is the next run time (`first_run_attempt` or `restart_after_seconds`) |
| `seconds_until` | Seconds from now until `next_run`                                              |

#### GET /set_pool_capacity/{capacity}

Change the maximum pool capacity at runtime. Requires authentication.

```bash
# Increase capacity to 20
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/set_pool_capacity/20

# Set to 0 to prevent new jobs from starting (existing jobs continue)
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/set_pool_capacity/0
```

**Response 200:**

```json
{"capacity": 20}
```

**Response 400:** if capacity is not a valid non-negative integer.

#### GET /cancel_job/{id}

Cancel a running or `failed_restart` job. Requires authentication.

For `running` jobs, the process is killed. The endpoint waits up to 5 seconds for the process to terminate before responding. For `failed_restart` jobs, the pending retry is aborted immediately.

```bash
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/cancel_job/15
```

**Response 200:**

```json
{"cancelled": true, "id": 15}
```

**Response 404:** job ID not found.

**Response 400:** job is not in `running` or `failed_restart` status (e.g., it already finished).

#### GET /restart_job/{id}

Queue a `failed_final` or `cancelled` job for re-scheduling. Requires authentication.

The dead JobRun is removed, unblocking the job's name. The job goes through normal scheduling on the next tick — it is not started immediately.

```bash
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/restart_job/12
```

**Response 200:**

```json
{"queued": true, "old_id": 12}
```

**Response 404:** job ID not found.

**Response 400:** job is not in `failed_final` or `cancelled` status.

**Note:** Jobs in `failed_restart` cannot be restarted — they are already being retried. To force a fresh start, cancel the job first, then restart it:

```bash
# Stop the auto-retry
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/cancel_job/15

# Queue for re-scheduling
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/restart_job/15
```

#### GET /start_job/{name}

Start a job immediately by name, bypassing the normal scheduling loop. Requires authentication.

The job is started regardless of whether the pool has free capacity (oversubscription is allowed). When the pool is full, the job still starts but the `oversubscribed` flag in the response is set to `true` and a WARN log is emitted. No other jobs will be scheduled by the normal loop until a slot frees up.

**Duplicate prevention:** A job cannot be started if any JobRun with the same name already exists in the pool — active (running, failed_restart) or dead (failed_final, cancelled). The check and start are performed atomically, so there is no race condition. This guarantees that no two instances of the same job can ever run concurrently.

```bash
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/start_job/etl-daily
```

**Response 200:**

```json
{"started": true, "job_name": "etl-daily", "oversubscribed": false}
```

**Response 200 (pool was full — job started anyway):**

```json
{"started": true, "job_name": "etl-daily", "oversubscribed": true}
```

**Response 404:** job name not found in the job definitions.

**Response 409:** a JobRun with this job name already exists in the pool (running, retrying, or dead). To start a fresh run, first remove the existing one:

- If the job is `running` or `failed_restart`: cancel it (`/cancel_job/{id}`), then remove it (`/restart_job/{id}`), then start (`/start_job/{name}`).
- If the job is `failed_final` or `cancelled`: remove it (`/restart_job/{id}`), then start (`/start_job/{name}`).

#### POST /start_jobs

Start multiple jobs immediately by name. Requires authentication.

Each job is checked independently — jobs already in the pool or not found are reported as errors while valid jobs are started. The entire batch is processed atomically: if the same job name appears twice in the list, the second occurrence is rejected as `already_in_pool`.

```bash
curl -X POST \
  -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"job_names": ["etl-daily", "report-gen", "nonexistent"]}' \
  http://localhost:4444/start_jobs
```

**Request body:**

```json
{"job_names": ["etl-daily", "report-gen", "nonexistent"]}
```

**Response 200:**

```json
{
  "results": [
    {"name": "etl-daily", "started": true, "oversubscribed": false},
    {"name": "report-gen", "started": true, "oversubscribed": true},
    {"name": "nonexistent", "started": false, "error": "not_found"}
  ]
}
```

Each entry in `results` corresponds to one requested job name (same order). Possible `error` values: `"not_found"` (no such job definition), `"already_in_pool"` (job is already running or dead in the pool).

**Response 400:** missing or empty `job_names`, or invalid JSON body.

#### PUT /set_job_first_run_attempt/{name}

Change the `first_run_attempt` of a job definition. Requires authentication.

This allows pausing a job by pushing `first_run_attempt` into the future, or re-enabling it by setting it to the past. Only affects new scheduling — does not stop in-progress execution or auto-retries.

```bash
# Pause a job until April 1st
curl -X PUT \
  -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"first_run_attempt": "2026-04-01T08:00:00"}' \
  http://localhost:4444/set_job_first_run_attempt/etl-daily

# Re-enable immediately (set to past time)
curl -X PUT \
  -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"first_run_attempt": "2020-01-01T00:00:00"}' \
  http://localhost:4444/set_job_first_run_attempt/etl-daily
```

The time value is in local server time format: `YYYY-MM-DDTHH:MM:SS`.

**Response 200:**

```json
{"job_name": "etl-daily", "first_run_attempt": "2026-04-01T08:00:00"}
```

**Response 404:** job name not found.

**Response 400:** missing body, missing `first_run_attempt`, or unparseable time.

> **Note:** The updated `first_run_attempt` value lives only in memory. It is **not persisted** to the state file on shutdown. After a restart, `first_run_attempt` reverts to whatever is defined in the job configuration file.

#### GET /job_stats/{name}

Returns the job definition together with execution statistics — both for the current session and all-time aggregated across restarts. Requires authentication.

```bash
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/job_stats/etl-daily
```

**Response 200:**

```json
{
  "job": {
    "name": "etl-daily",
    "command_line": ["python", "/opt/scripts/etl.py", "--full"],
    "priority": 100,
    "first_run_attempt": "2026-01-01T06:00:00",
    "restart_after_seconds": 86400,
    "max_runs": 3,
    "max_run_time_seconds": 3600
  },
  "since_last_start": {
    "total_runs": 5,
    "successful_runs": 4,
    "failed_runs": 1,
    "last_success": "2026-03-25T10:00:00Z",
    "last_failure": "2026-03-24T10:00:00Z"
  },
  "all_time": {
    "total_runs": 120,
    "successful_runs": 115,
    "failed_runs": 5,
    "last_success": "2026-03-25T10:00:00Z",
    "last_failure": "2026-03-24T10:00:00Z"
  }
}
```

**Response 404:** job name not found.

#### GET /job_log/{name}

Returns the last N bytes of a job's log file. Requires authentication.

The log file is expected at `<ONDP_TENANT_LOG_DIR>/<name>.log`. The `ONDP_TENANT_LOG_DIR` environment variable must be set for this endpoint to work.

Supports an optional `bytes` query parameter to control how many bytes to read from the end of the file (default 1024).

```bash
# Last 1024 bytes (default)
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/job_log/etl-daily

# Last 4096 bytes
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  "http://localhost:4444/job_log/etl-daily?bytes=4096"
```

**Response 200:**

```json
{
  "job_name": "etl-daily",
  "content": "2026-04-27 10:05:00 INFO Processing batch 42...\n2026-04-27 10:05:01 INFO Done.\n",
  "bytes_requested": 1024,
  "bytes_returned": 78,
  "file_size": 78
}
```

| Field             | Meaning                                              |
| ----------------- | ---------------------------------------------------- |
| `job_name`        | Name of the job                                      |
| `content`         | The last N bytes of the log file as a string          |
| `bytes_requested` | Number of bytes requested (from `bytes` query param) |
| `bytes_returned`  | Actual number of bytes returned (may be less if file is smaller) |
| `file_size`       | Total size of the log file in bytes                  |

**Response 404:** log directory not found, or log file not found (`<name>.log` does not exist in `ONDP_TENANT_LOG_DIR`).

**Response 500:** `ONDP_TENANT_LOG_DIR` environment variable is not set, or file I/O error.

#### GET /shutdown

Initiate graceful shutdown. Requires authentication.

```bash
curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/shutdown
```

**Response 200:**

```json
{"shutdown": "initiated"}
```

After this response, oflow begins the shutdown sequence: sets capacity to 0, waits for running jobs to finish, saves state, and exits.

### Common Patterns

**Monitor job status in a loop:**

```bash
watch -n 5 'curl -s http://localhost:4444/status | python -m json.tool'
```

**Check if oflow is running (useful in scripts):**

```bash
if curl -sf http://localhost:4444/status > /dev/null 2>&1; then
  echo "oflow is running"
else
  echo "oflow is not reachable"
fi
```

**Restart all failed jobs:**

```bash
curl -s http://localhost:4444/status | \
  python -c "
import sys, json
data = json.load(sys.stdin)
for job in data['pool']['jobs']:
    if job['status'] in ('failed_final', 'cancelled'):
        print(job['id'])
" | while read id; do
  curl -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
    "http://localhost:4444/restart_job/$id"
done
```

---

## 8. Web Frontend (oflow-web)

### What Is oflow-web

oflow-web is a separate web application that provides browser-based access to oflow. It is a standalone binary that connects to oflow's REST API as an HTTP client. You can deploy, start, and stop it independently of oflow.

```
  Browser                  oflow-web                     oflow
  ┌──────┐    HTML/htmx    ┌──────────┐   REST + Bearer  ┌──────────┐
  │ User ├───────────────►│ :web_port │──────────────────►│ :api_port│
  │      │◄───────────────│ Go server │◄──────────────────│ REST API │
  └──────┘   HTML pages    └──────────┘   JSON responses  └──────────┘
```

The web app is **stateless** — all data comes from oflow's API on every page load. It uses server-rendered HTML with [htmx](https://htmx.org/) for dynamic updates, so there is no JavaScript framework or build step.

### Starting oflow-web

oflow-web is configured entirely via environment variables:

| Variable                       | Required | Default                 | Description                                                                                                                                           |
| ------------------------------ | :------: | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ONDP_OFLOW_AUTH`              |   yes    | —                       | Bearer token for oflow API (same value oflow uses).                                                                                                   |
| `ONDP_OFLOW_WEB_USER`          |   yes    | —                       | Login username for the web UI.                                                                                                                        |
| `ONDP_OFLOW_WEB_PASSWORD`      |   yes    | —                       | Login password for the web UI.                                                                                                                        |
| `ONDP_OFLOW_WEB_PORT`          |    no    | `8080`                  | Port for the web server.                                                                                                                              |
| `ONDP_OFLOW_API_URL`           |    no    | `http://127.0.0.1:4444` | Base URL of the oflow REST API. Use `https://` when oflow has TLS enabled.                                                                            |
| `ONDP_OFLOW_WEB_SESSION_HOURS` |    no    | `8`                     | Session expiry in hours.                                                                                                                              |
| `ONDP_OFLOW_WEB_TLS_CERT`      |    no    | `""`                    | Path to PEM-encoded TLS certificate for the web server. If set, `ONDP_OFLOW_WEB_TLS_KEY` must also be set.                                            |
| `ONDP_OFLOW_WEB_TLS_KEY`       |    no    | `""`                    | Path to PEM-encoded TLS private key for the web server. If set, `ONDP_OFLOW_WEB_TLS_CERT` must also be set.                                           |
| `ONDP_OFLOW_TLS_SKIP_VERIFY`   |    no    | `"false"`               | When `"true"`, the oflow API client skips TLS certificate verification. Use for self-signed certs in development. **Not recommended for production.** |

**Example startup:**

```bash
export ONDP_OFLOW_AUTH="my-secret-token"
export ONDP_OFLOW_WEB_USER="admin"
export ONDP_OFLOW_WEB_PASSWORD="secure-password"
export ONDP_OFLOW_WEB_PORT="8080"
export ONDP_OFLOW_API_URL="http://localhost:4444"

./oflow-web
```

**Example startup with TLS (oflow-web serves HTTPS, connects to oflow over HTTPS):**

```bash
export ONDP_OFLOW_AUTH="my-secret-token"
export ONDP_OFLOW_WEB_USER="admin"
export ONDP_OFLOW_WEB_PASSWORD="secure-password"
export ONDP_OFLOW_WEB_PORT="8080"
export ONDP_OFLOW_API_URL="https://localhost:4444"
export ONDP_OFLOW_WEB_TLS_CERT="/etc/oflow/tls/web.crt"
export ONDP_OFLOW_WEB_TLS_KEY="/etc/oflow/tls/web.key"
export ONDP_OFLOW_TLS_SKIP_VERIFY="true"

./oflow-web
```

oflow-web refuses to start if `ONDP_OFLOW_AUTH`, `ONDP_OFLOW_WEB_USER`, or `ONDP_OFLOW_WEB_PASSWORD` is missing.

### Authentication

oflow-web has its own login page. Users authenticate with the username and password configured in the environment variables. After login, a session cookie is set (valid for `ONDP_OFLOW_WEB_SESSION_HOURS` hours, default 8).

- Navigate to `http://localhost:8080` → redirected to `/login`.
- Enter username and password → on success, redirected to the dashboard.
- Click "Logout" or let the session expire → redirected to `/login`.

The bearer token for the oflow API stays server-side — it is never exposed to the browser.

> **Session cookie security:** When oflow-web is serving HTTPS (TLS configured), the session cookie is set with the `Secure` flag, so browsers only send it over encrypted connections. When serving plain HTTP, the `Secure` flag is not set (allows development on localhost).

### Dashboard

After login, the dashboard shows controls at the top and live state below. The two sections are visually separated — controls are rendered once and never replaced by auto-refresh, so user inputs (capacity field, job selects, datetime pickers) are never clobbered.

**Admin view:**

```
┌─────────────────────────────────────────────────────────┐
│  oflow-web                                    [Logout]  │
├─────────────────────────────────────────────────────────┤
│  [flash messages]                                       │
│                                                         │
│  ┌─ CONTROLS (never auto-refreshed) ─────────────────┐  │
│  │                                                    │  │
│  │  Pool Capacity                                     │  │
│  │  [___] [Apply]                                     │  │
│  │                                                    │  │
│  │  Job Actions                                       │  │
│  │  Search [________]   Job [▾ select ▾]              │  │
│  │  [Show Definition]  [Show Stats]  [View Log]       │  │
│  │  [Start Now]                                       │  │
│  │                                                    │  │
│  │  First Run                                         │  │
│  │  [datetime-local picker]  [Set First Run]          │  │
│  │                                                    │  │
│  │  ──────────────────────────────────────────────     │  │
│  │  Danger Zone                                       │  │
│  │  [Shutdown oflow]                                  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                         │
│  ═══════════════════════════════════════════════════════  │
│                                                         │
│  ┌─ POOL STATUS (refreshes at selected interval) ─────┐  │
│  │  Status        running       Total Executed   142  │  │
│  │  Running Since 2026-04-21    Restarts→OK        3  │  │
│  │  Pool          3 / 5 used    Currently Failed   1  │  │
│  │  Sleep         30 s                                │  │
│  └────────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─ RUNNING JOBS (refreshes at selected interval) ────┐  │
│  │  ID │ Name       │ Status        │ Runs │ Actions  │  │
│  │  ───┼────────────┼───────────────┼──────┼────────  │  │
│  │   1 │ etl-daily  │ 🟢 running    │    1 │ [Cancel] │  │
│  │   2 │ report-gen │ 🟡 failed_rst │    2 │ [Cancel] │  │
│  │   3 │ cleanup    │ 🔴 failed_fin │    3 │[Restart] │  │
│  │   4 │ archive    │ ⚪ cancelled  │    1 │[Restart] │  │
│  └────────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─ DISPLAY SETTINGS ─────────────────────────────────┐  │
│  │  Refresh [5 s ▾]   Show [10 ▾]                     │  │
│  └────────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─ NEXT JOBS (refreshes at selected interval) ───────┐  │
│  │  ┌─ (refreshes at selected interval) ─────────────┐  │  │
│  │  │  # │ Job Name   │ Next Run          │ In      │  │  │
│  │  │  1 │ etl-daily  │ 2026-04-21 09:00  │ 25 min  │  │  │
│  │  │  2 │ report-gen │ 2026-04-21 09:15  │ 40 min  │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Viewer view:** Viewers see only the state section (Pool Status, Running Jobs, Next Jobs) — no controls. The jobs table shows status but no action buttons.

#### Status indicators

| Color    | Status           | Meaning                             |
| -------- | ---------------- | ----------------------------------- |
| 🟢 Green  | `running`        | Process is executing                |
| 🟡 Yellow | `failed_restart` | Failed, waiting for automatic retry |
| 🔴 Red    | `failed_final`   | Failed, all retries exhausted       |
| ⚪ Grey   | `cancelled`      | Explicitly cancelled                |

#### Available actions

| Job status       | Button      | Effect                            |
| ---------------- | ----------- | --------------------------------- |
| `running`        | **Cancel**  | Kills the process.                |
| `failed_restart` | **Cancel**  | Aborts the pending retry.         |
| `failed_final`   | **Restart** | Queues the job for re-scheduling. |
| `cancelled`      | **Restart** | Queues the job for re-scheduling. |

**Immediate start (Job Actions section):**

| Button        | Effect                                                                                                                                                                                                                                        |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Start Now** | Starts the selected job immediately, bypassing the scheduler loop. Uses `GET /start_job/{name}`. If the job is already in the pool (running or dead), an error flash is shown. If the pool is full, the job starts anyway (oversubscription). |
| **View Log**  | Opens a modal overlay showing the last 1024 bytes of the job's log file (`<ONDP_TENANT_LOG_DIR>/<name>.log`). The content auto-refreshes every 10 seconds while the modal is open. Close the modal to stop refreshing. Admin only.            |

#### Auto-refresh

All data areas on the dashboard share a single configurable refresh interval, controlled by the **Refresh** selector (visible to all roles). The default is 5 seconds; options range from 5 to 60 seconds in 5-second increments.

- **Pool Status**, **Running Jobs**, **Next Jobs**, and **Execution History** all refresh at the selected interval.
- **Log modal** (when open) also refreshes at the same interval.
- **Controls** are rendered once on page load and never replaced by polling.

Changing the refresh interval takes effect immediately — no page reload needed.

When an admin performs an action (e.g., cancel a job, set capacity), the server responds with a flash message and an `HX-Trigger: refreshState` header. This causes all data areas to re-fetch themselves immediately — without touching the controls section. User inputs are never clobbered.

#### Set Capacity

Enter a new capacity value and click "Apply" to change the pool size at runtime. Setting capacity to 0 prevents new jobs from starting (existing jobs continue to run).

#### Job Definition Lookup

Type a partial job name in the search box to filter job definitions. Select a job from the dropdown and click "Show" to view its full definition (command line, priority, max runs, timeout, etc.).

#### Set First Run

Select a job from the dropdown, enter a date/time, and click "Apply" to change the job's `first_run_attempt`. Use a future time to pause the job; use a past time to re-enable it.

#### Shutdown

Click "Shutdown oflow" to initiate a graceful shutdown of the **oflow scheduler** (not oflow-web). A confirmation dialog appears before the request is sent.

### Error Handling

- **oflow unreachable:** If oflow is not running or not reachable, the state section displays a banner: "oflow is not reachable at `<url>`". Controls remain visible above (admin view) but actions will return error flash messages. Auto-refresh continues — the dashboard will recover automatically when oflow comes back.
- **Action errors:** If an API call fails (e.g., trying to cancel an already-finished job), the error message is shown as a dismissible alert at the top of the page.

### Logging

oflow-web logs to **stdout** (not a file) in structured JSON format. This makes it suitable for container environments or systemd journal capture. It logs startup, login attempts (never passwords), API calls to oflow, and shutdown.

---

## 9. API Quick Reference

All endpoints in one place. Replace `localhost:4444` with your oflow address. Protected endpoints require the `Authorization` header — examples assume `$ONDP_OFLOW_AUTH` is set in your shell.

### Public Endpoints

```bash
# Status — pool capacity, active and dead jobs
curl -s http://localhost:4444/status | jq .

# List all job definitions
curl -s http://localhost:4444/jobs | jq .

# List job definitions matching a name pattern
curl -s "http://localhost:4444/jobs?mask=etl" | jq .

# Show a single job definition
curl -s http://localhost:4444/job/etl-daily | jq .
```

### Protected Endpoints

```bash
# Set pool capacity
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/set_pool_capacity/20 | jq .

# Cancel a running or failed_restart job (by ID)
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/cancel_job/15 | jq .

# Restart a failed_final or cancelled job (by ID)
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/restart_job/12 | jq .

# Start a job immediately by name (bypasses scheduler loop)
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/start_job/etl-daily | jq .

# Start multiple jobs immediately
curl -s -X POST \
  -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"job_names": ["etl-daily", "report-gen"]}' \
  http://localhost:4444/start_jobs | jq .

# Change a job's first_run_attempt (pause / re-enable)
curl -s -X PUT \
  -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"first_run_attempt": "2026-04-01T08:00:00"}' \
  http://localhost:4444/set_job_first_run_attempt/etl-daily | jq .

# Graceful shutdown
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/shutdown | jq .

# View last 1024 bytes of a job's log file
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/job_log/etl-daily | jq .

# View last 4096 bytes of a job's log file
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  "http://localhost:4444/job_log/etl-daily?bytes=4096" | jq .
```

### Useful Combinations

```bash
# Pretty status with capacity overview
curl -s http://localhost:4444/status | jq '{capacity: .pool.capacity, used: .pool.used, failed: .pool.current_failed}'

# Names and statuses of all jobs in the pool
curl -s http://localhost:4444/status | jq '.pool.jobs[] | {name: .job_name, status: .status}'

# IDs of all failed_final jobs
curl -s http://localhost:4444/status | jq '[.pool.jobs[] | select(.status == "failed_final") | .id]'

# Restart every failed_final job in one shot
curl -s http://localhost:4444/status | \
  jq -r '.pool.jobs[] | select(.status == "failed_final") | .id' | \
  while read id; do
    curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
      "http://localhost:4444/restart_job/$id" | jq .
  done

# Start a specific job immediately (bypasses scheduler loop)
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/start_job/etl-daily | jq .

# Start multiple jobs at once
curl -s -X POST \
  -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"job_names": ["etl-daily", "report-gen", "health-check"]}' \
  http://localhost:4444/start_jobs | jq .

# Start all eligible jobs that match a pattern (combine /jobs with /start_jobs)
JOBS=$(curl -s "http://localhost:4444/jobs?mask=etl" | jq -c '.jobs')
curl -s -X POST \
  -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  -H "Content-Type: application/json" \
  -d "{\"job_names\": $JOBS}" \
  http://localhost:4444/start_jobs | jq .

# Drain the pool (set capacity to 0, then wait for running jobs to finish)
curl -s -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  http://localhost:4444/set_pool_capacity/0 | jq .
watch -n 5 'curl -s http://localhost:4444/status | jq .pool.used'

# Check if oflow is reachable (for scripts)
curl -sf http://localhost:4444/status > /dev/null 2>&1 && echo "up" || echo "down"
```

### HTTPS Variants

When oflow is configured with TLS, use `https://` and add `-k` for self-signed certificates or `--cacert` for a custom CA:

```bash
# Self-signed certificate — skip verification
curl -sk https://localhost:4444/status | jq .

# Custom CA certificate
curl -s --cacert /etc/oflow/tls/ca.crt https://localhost:4444/status | jq .

# Protected endpoint over HTTPS
curl -sk -H "Authorization: Bearer $ONDP_OFLOW_AUTH" \
  https://localhost:4444/set_pool_capacity/20 | jq .

# Check if HTTPS oflow is reachable
curl -skf https://localhost:4444/status > /dev/null 2>&1 && echo "up" || echo "down"
```

## 10. PowerShell API Reference

PowerShell includes `Invoke-RestMethod` (alias `irm`) which can replace every `curl` example in this manual. No external tools are needed — this works on any Windows machine with PowerShell 5.1+ or PowerShell 7+.

### Setup

Store the bearer token in a variable and define a reusable headers hashtable:

```powershell
$Token = $env:ONDP_OFLOW_AUTH
$Headers = @{ Authorization = "Bearer $Token" }
$BaseUrl = "http://localhost:4444"
```

For HTTPS with a self-signed certificate (PowerShell 7+):

```powershell
$BaseUrl = "https://localhost:4444"
# Add -SkipCertificateCheck to every Invoke-RestMethod call below
```

### Public Endpoints

```powershell
# Status — pool capacity, active and dead jobs
Invoke-RestMethod "$BaseUrl/status"

# List all job definitions
Invoke-RestMethod "$BaseUrl/jobs"

# List job definitions matching a name pattern
Invoke-RestMethod "$BaseUrl/jobs?mask=etl"

# Show a single job definition
Invoke-RestMethod "$BaseUrl/job/etl-daily"

# Next jobs to run
Invoke-RestMethod "$BaseUrl/next_jobs"

# Next jobs — limit to 10
Invoke-RestMethod "$BaseUrl/next_jobs?limit=10"
```

### Protected Endpoints

```powershell
# Set pool capacity
Invoke-RestMethod "$BaseUrl/set_pool_capacity/20" -Headers $Headers

# Cancel a running or failed_restart job (by ID)
Invoke-RestMethod "$BaseUrl/cancel_job/15" -Headers $Headers

# Restart a failed_final or cancelled job (by ID)
Invoke-RestMethod "$BaseUrl/restart_job/12" -Headers $Headers

# Start a job immediately by name
Invoke-RestMethod "$BaseUrl/start_job/etl-daily" -Headers $Headers

# Start multiple jobs immediately
$Body = @{ job_names = @("etl-daily", "report-gen") } | ConvertTo-Json
Invoke-RestMethod "$BaseUrl/start_jobs" -Method Post -Headers $Headers `
  -ContentType "application/json" -Body $Body

# Change a job's first_run_attempt
$Body = @{ first_run_attempt = "2026-04-01T08:00:00" } | ConvertTo-Json
Invoke-RestMethod "$BaseUrl/set_job_first_run_attempt/etl-daily" `
  -Method Put -Headers $Headers -ContentType "application/json" -Body $Body

# View job stats
Invoke-RestMethod "$BaseUrl/job_stats/etl-daily" -Headers $Headers

# View last 1024 bytes of a job's log file
Invoke-RestMethod "$BaseUrl/job_log/etl-daily" -Headers $Headers

# View last 4096 bytes of a job's log file
Invoke-RestMethod "$BaseUrl/job_log/etl-daily?bytes=4096" -Headers $Headers

# Graceful shutdown
Invoke-RestMethod "$BaseUrl/shutdown" -Headers $Headers
```

### Useful Combinations

```powershell
# Pool capacity overview
$s = Invoke-RestMethod "$BaseUrl/status"
[PSCustomObject]@{
    Capacity = $s.pool.capacity
    Used     = $s.pool.used
    Failed   = $s.pool.current_failed
}

# Names and statuses of all jobs in the pool
$s = Invoke-RestMethod "$BaseUrl/status"
$s.pool.jobs | Select-Object job_name, status

# Only failed jobs
$s = Invoke-RestMethod "$BaseUrl/status"
$s.pool.jobs | Where-Object { $_.status -like "failed*" }

# Restart every failed_final job in one shot
$s = Invoke-RestMethod "$BaseUrl/status"
$s.pool.jobs |
  Where-Object { $_.status -eq "failed_final" } |
  ForEach-Object {
    Invoke-RestMethod "$BaseUrl/restart_job/$($_.id)" -Headers $Headers
  }

# Start all jobs matching a pattern
$jobs = (Invoke-RestMethod "$BaseUrl/jobs?mask=etl").jobs
$Body = @{ job_names = $jobs } | ConvertTo-Json
Invoke-RestMethod "$BaseUrl/start_jobs" -Method Post -Headers $Headers `
  -ContentType "application/json" -Body $Body

# Drain the pool (set capacity to 0, then poll until empty)
Invoke-RestMethod "$BaseUrl/set_pool_capacity/0" -Headers $Headers
do {
    Start-Sleep -Seconds 5
    $used = (Invoke-RestMethod "$BaseUrl/status").pool.used
    Write-Host "Active jobs: $used"
} while ($used -gt 0)

# Check if oflow is reachable (for scripts)
try {
    Invoke-RestMethod "$BaseUrl/status" -ErrorAction Stop | Out-Null
    Write-Host "up"
} catch {
    Write-Host "down"
}
```

### HTTPS with Self-Signed Certificates

PowerShell 7+ supports `-SkipCertificateCheck` natively:

```powershell
$BaseUrl = "https://localhost:4444"

# Public endpoint
Invoke-RestMethod "$BaseUrl/status" -SkipCertificateCheck

# Protected endpoint
Invoke-RestMethod "$BaseUrl/set_pool_capacity/20" -Headers $Headers -SkipCertificateCheck
```

On PowerShell 5.1 (Windows PowerShell), there is no `-SkipCertificateCheck` flag. Use this workaround once per session before making requests:

```powershell
# PowerShell 5.1 only — disable cert validation for self-signed certs
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint sp, X509Certificate cert,
        WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll
```

### Notes

- `Invoke-RestMethod` automatically parses JSON responses into PowerShell objects, so you can access fields directly (e.g., `$result.pool.capacity`) without a `jq` equivalent.
- The alias `irm` can be used in place of `Invoke-RestMethod` for brevity.
- On PowerShell 5.1, `ConvertTo-Json` defaults to a depth of 2. For deeply nested request bodies, add `-Depth 10`.

---

## 11. Windows firewall settings

Při spuštění se systém táže, zda je bezpečné pustit program do sítí. Dává na vybranou tři místa:

- local
- private
- public

Pro správné fungování programu je nutné zvolit jak local, tak i private. Public nikoliv.
Změnu nastavení může provést pouze admin. Při prvním nastavení se tedy definuje politika, co je povoleno.

Pokud jsme zadali oprávnění špatně, je možné se k nim vrátit takto:

- menu Start
- hledám `Windows Security`
- jdu na `Firewall & network protection`
- kliknu na link `Allow an app through firewall`
- na dalším dialogu kliknu na tlačítko `Change settings`
- najdu příslušnou aplikaci podle plného názvu (oflow), a vyberu:
  - `Domain`
  - `Private`

### 11.1 Troubleshooting: web front end not reachable

When `oflow-web` starts normally (prints `oflow-web started on port ...`) but is not reachable from another machine, the problem is almost always Windows Defender Firewall blocking inbound TCP connections.

#### Step 1 — Check which network profile is active

Windows Firewall rules apply per-profile. The active profile determines which rules are evaluated.

```powershell
# Show active network profile(s) and firewall state
Get-NetConnectionProfile
Get-NetFirewallProfile | Select-Object Name, Enabled
```

Typical output:

| Name    | Enabled |
| ------- | ------- |
| Domain  | True    |
| Private | True    |
| Public  | True    |

The `InterfaceAlias` field in `Get-NetConnectionProfile` tells you which adapter is active and its category (`DomainAuthenticated`, `Private`, or `Public`). If the network is categorized as `Public`, firewall rules scoped to Domain/Private will not apply.

#### Step 2 — List existing rules for oflow

```powershell
# List all inbound rules whose name contains "oflow" (case-insensitive)
Get-NetFirewallRule -Direction Inbound |
  Where-Object { $_.DisplayName -like '*oflow*' } |
  Format-Table DisplayName, Enabled, Profile, Action
```

If no rules appear, or the rule exists but is disabled or scoped to the wrong profile, inbound connections will be silently dropped.

#### Step 3 — Check whether the port is listening

```powershell
# Replace 8080 with the actual oflow-web port
Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
```

If this returns nothing, the server process has not bound to the port (check the oflow-web stdout/stderr).

#### Step 4 — Test connectivity from the remote machine

From the machine where you want to open the web UI:

```powershell
# Replace <WEB_HOST> and <PORT> with the actual values
Test-NetConnection -ComputerName <WEB_HOST> -Port <PORT>
```

If `TcpTestSucceeded` is `False`, the firewall is blocking. If `True` but the browser shows nothing, check the protocol (HTTP vs HTTPS) and the URL path.

#### Step 5 — Create or fix the firewall rule

All commands below require an **elevated** (Run as Administrator) PowerShell session.

**Option A — Allow by port (recommended for oflow-web)**

```powershell
# Create an inbound rule for oflow-web port(s)
# Adjust -LocalPort to match your ONDP_OFLOW_WEB_PORT value(s)
New-NetFirewallRule `
  -DisplayName "OFLOW-WEB" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 8081,8082,8083 `
  -Action Allow `
  -Profile Domain,Private `
  -Description "Allow inbound TCP to oflow-web front end"
```

**Option B — Allow by executable path**

```powershell
New-NetFirewallRule `
  -DisplayName "OFLOW-WEB (exe)" `
  -Direction Inbound `
  -Protocol TCP `
  -Program "F:\Git\oflow\oflow-web-windows-amd64.exe" `
  -Action Allow `
  -Profile Domain,Private `
  -Description "Allow inbound TCP to oflow-web executable"
```

**Enable an existing but disabled rule:**

```powershell
Enable-NetFirewallRule -DisplayName "OFLOW-WEB"
```

**Remove a rule (to recreate it):**

```powershell
Remove-NetFirewallRule -DisplayName "OFLOW-WEB"
```

#### Step 6 — Verify the fix

After creating the rule, repeat the connectivity test from the remote machine:

```powershell
Test-NetConnection -ComputerName <WEB_HOST> -Port <PORT>
```

`TcpTestSucceeded` should now be `True`, and the web UI should load in a browser at `http://<WEB_HOST>:<PORT>/login`.

### 11.2 Startup diagnostics

`oflow-web` includes built-in startup diagnostics that run automatically after the HTTP server starts. Look for log lines tagged `[DIAG]` in the JSON stdout output. These diagnostics:

1. **Enumerate network interfaces** — lists all interfaces, their flags, and IP addresses. Confirms which addresses the server is reachable on.
2. **Probe loopback** — connects to `127.0.0.1:<port>` to verify the listener is actually bound.
3. **Probe LAN interfaces** — connects to each non-loopback IPv4 address on the configured port. A failure here while loopback succeeds strongly suggests a firewall block.
4. **Probe oflow API** — sends `GET /status` to the configured `ONDP_OFLOW_API_URL` to verify the backend is reachable.

Example log output (abbreviated):

```json
{"level":"INFO","msg":"[DIAG] === startup diagnostics begin ==="}
{"level":"INFO","msg":"[DIAG] network interface","interface":"Ethernet","addresses":["10.0.1.50/24"]}
{"level":"INFO","msg":"[DIAG] listen port probe OK","addr":"127.0.0.1:8081"}
{"level":"WARN","msg":"[DIAG] interface probe FAILED","addr":"10.0.1.50:8081","hint":"Windows Firewall may be blocking inbound connections"}
{"level":"INFO","msg":"[DIAG] oflow API probe OK","url":"http://10.0.1.100:8010/status"}
{"level":"INFO","msg":"[DIAG] === startup diagnostics complete ==="}
```

The pattern **loopback OK + LAN FAILED** is the classic signature of Windows Firewall blocking inbound connections. Follow the steps in section 11.1 to resolve it.
