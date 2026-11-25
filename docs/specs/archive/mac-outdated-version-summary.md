# mac-outdated: version, macOS step, failures + by-hand summary, logging

Date: 2026-11-11. Trigger: the 2026-11-11 08:47 `--install` run (log `2026-11-11-084725-install.log`).

## Problems seen
- No version anywhere.
- macOS step: owner password prompt echoed the typed password (stdout/stderr go through the log pipe, so sudo's `use_pty` leaves the user's terminal in cooked mode).
- macOS step reported `installed` + "restart required" although the owner password was empty and `softwareupdate --list` still offers 27.2.1 afterwards. "restart required" came from the *pre*-install list, not from the result. Also "Downloading: 100.00%    restart required…" on one line.
- Start hint is wrong for this Mac: sudo forgets after 1 minute (`/etc/sudoers.d/mscp`: `timestamp_timeout=1`) and macOS asks a second time for the owner password.
- Summary has no failures line and no by-hand list; by-hand items (self-updating casks, pipx link conflict) are buried in tool output.

## Decisions (user, 2026-11-11)
- Version 1.0.0, file `software-updates/VERSION`, tag `mac-outdated-X.Y.Z` annotated (`mac-outdated X.Y.Z`), bumps only for changes under `software-updates/`. New `## Version (mac-outdated)` block in `CLAUDE.md`.
- Failures: always a line at the end.
- By hand lists: self-updating apps, restart required, skipped steps (admin expired), tool warnings.
- macOS step talks to the terminal directly; result checked against `softwareupdate --list` after the install, not only the exit code.

## Design

### 1. Version
- `software-updates/VERSION` (`1.0.0`), read next to the resolved script (`readlink -f`), `?` when missing.
- Header: `mac-outdated v1.0.0 · <date>` / `mac-outdated v1.0.0 --install · <date>`.
- `--version` prints `mac-outdated 1.0.0`; usage first line shows the version; fish completion gets `--version`; docs updated.

### 2. macOS step
- Runs `script -q <transcript> sudo softwareupdate --install --all` with stdout/stderr on the saved terminal fds (`OUT_FD`/`ERR_FD`; plain terminal when no log). `script` gives sudo a real terminal on all three fds, so sudo goes to raw mode and both password prompts stay hidden; the transcript holds output only (no `-r`, prompts read with echo off).
- After the run: transcript (control chars and `\r` progress folded) goes into the log; `softwareupdate --list` again.
- Result:
  | exit | listed after | transcript mentions restart | result |
  |---|---|---|---|
  | ≠0 | – | – | `failed (exit N)` |
  | 0 | none of the labels | – | `installed` |
  | 0 | still listed | yes | `installed, restart required` + by hand "restart the Mac" |
  | 0 | still listed | no | `failed (still offered after install: owner password empty or wrong?)` |
- Restart detection is best effort (pattern `restart`, case-insensitive); validated by the next real run (hand test).
- `script` unavailable → fall back to the old direct call with output to the terminal fds (no transcript), same result table without the restart column (still listed → failed).

### 3. Summary end
After the `total` row:
```
  ✓ nothing failed                       (green)
  ✗ failed: macOS (still offered …), Adobe (exit 2)   (red)
    details: <log path>
    rerun:   mac-outdated --install

 By hand
  discord, shottr: open the app, it updates itself
  macOS 27.2.1: restart the Mac
  App Store: skipped, admin expired: click Privileges, then mac-outdated --install
  pipx: ~/.local/bin/user-process links elsewhere, not to pipx's venv: rm it, then pipx reinstall user-process
```
- Failed = results counted as failed today (`failed …`, `some updates failed …`); skipped-admin steps go to By hand, not to the failed line.
- No by-hand items → `nothing to do by hand`.
- Collected in a global array during the steps (steps run in the main shell, only their output is redirected):
  - brew: `self` casks (joined in one line), third-party tap formulae held for review (`<name>: held for review, see mac-outdated`).
  - macOS: restart required.
  - any step with `STEP_STATUS` expired/expires.
  - pipx: `run_noting`'s output file scanned for `File exists at <path> … points to` → one line per package.
- Exit code unchanged (1 when anything failed or was skipped).

### 4. Start hint
`sudo asks again before a step when the last sudo was over a minute ago; the macOS step also asks for the owner password (your login password)`.

### 5. Logging
- First log lines (log only): version, command line, start time.
- Per step (log only): `step <src>: start HH:MM:SS`, `step <src>: end HH:MM:SS, <duration>, exit <rc>, <result>`.
- macOS transcript and both `--list` outputs.
- Last log line: total duration.
- Terminal output unchanged apart from the sections above.

## Tests (software-updates/tests/mac-outdated.sh, stubs)
- Header shows `v<VERSION>`; `--version` output; missing VERSION → `v?`.
- macOS: stub softwareupdate install exit 0 + still listed + no restart text → `failed (still offered …)`, in failed line; + restart text → `installed, restart required`, by hand restart line; not listed after → `installed`; exit 1 → `failed (exit 1)`. Stub `script` (runs the command, writes transcript).
- Failed line: none failed → `nothing failed`; one failed → names it, log path, rerun hint.
- By hand: self casks, held formula, admin-expired step, pipx `File exists` warning; none → `nothing to do by hand`.
- Log: step start/end lines with exit and result; header with version.

## Out of scope
Findings of the parallel security/bug review: handled after this spec, each as its own fix.
