# psmux Session Disappearance Investigation

Date: 2026-06-03

## Reported symptom

There were 11 psmux sessions before a short break. After returning, `PREFIX+s`
showed only 7 sessions.

The latest resurrection snapshot still listed 11 sessions, which meant the
expected session set was known even though the live session picker showed fewer.

## Confirmed finding

The missing sessions were not dead. They were still running as `psmux.exe server`
processes with live localhost TCP listeners, but their registry files under
`~\.psmux` were gone.

Missing-but-alive sessions observed:

| Session | PID | Listener port | Registry present |
| --- | ---: | ---: | --- |
| `ado-pipeline-notifier` | 77900 | 53725 | No |
| `agent-watch` | 89852 | 53795 | No |
| `callstore` | 10544 | 56378 | No |
| `common-infra` | 36292 | 56522 | No |

The live registry under `~\.psmux` only had 7 real sessions plus `__warm__`:

- `ai-skills`
- `broker`
- `call-controller`
- `convserv`
- `dashboard`
- `psmux`
- `teams-scheduler`

The latest resurrection file,
`~\.psmux\resurrect\psmux_resurrect_20260602_141429.json`, listed all 11
sessions.

## Why `PREFIX+s` hid them

`PREFIX+s` is bound to `choose-session`.

The session chooser and related listing paths discover sessions by scanning
`~\.psmux\*.port`. They do not fall back to enumerating live `psmux.exe`
processes, TCP listeners, or resurrect JSON files.

Therefore, if a live server loses its `.port` and `.key` files, it becomes
invisible to `choose-session` / `list-sessions` even though the server process is
still alive.

Relevant code paths:

- `src\help.rs`: default binding maps `s` to `choose-session`.
- `src\session.rs`: `list_session_names()` and `list_all_sessions_tree()` scan
  `.port` files.
- `src\main.rs`: CLI `list-sessions` scans `.port` files.

## Most likely root cause

`cleanup_stale_port_files()` runs at psmux startup and removes registry files
after a single failed localhost connect probe.

Current behavior:

1. Scan `~\.psmux\*.port`.
2. Read the port.
3. Attempt `TcpStream::connect_timeout(..., Duration::from_millis(5))`.
4. If that one 5 ms connect attempt fails, delete the `.port` file and matching
   `.key` file.

This is unsafe on Windows. A live localhost listener can transiently miss a 5 ms
connect window. Once the cleanup deletes the registry files, the server remains
alive but becomes undiscoverable.

Supporting evidence:

- The four missing sessions still had live `psmux.exe server -s ...` processes.
- Each missing process still owned a localhost listening port.
- Their `.port` and `.key` files were absent.
- The `~\.psmux` directory timestamp changed on 2026-06-03 around 16:09.
- An isolated probe reproduced a 5 ms timeout against a live listener.

## Other feasible but less likely cause

The server installs a global panic hook that removes the current session's
`.port` and `.key` files. A panic in a spawned thread does not necessarily
terminate the whole Rust process, so this could also leave a live server without
registry files.

This was not the strongest explanation for this event because `crash.log` was
old and was not updated near the incident.

## Recommended fix direction

Do not delete registry files after a single short timeout.

Safer options:

1. Use a longer timeout and multiple retries before declaring a port stale.
2. Preserve registry files on `TimedOut`; only delete on stronger evidence such
   as repeated connection refusal.
3. Centralize registry cleanup so all paths behave consistently.
4. Have each server periodically verify and restore its own `.port` and `.key`
   files if they disappear.
5. Add a regression test proving a live-but-slow localhost listener is not
   removed by stale cleanup.

## Immediate recovery note

Because the missing sessions no longer have `.key` files, normal authenticated
attach/switch paths cannot rediscover them from the registry alone. Recovery
would need either a server-side re-registration mechanism, a diagnostic command
that can ask the live process to re-register, or manual intervention with
process/listener discovery.
