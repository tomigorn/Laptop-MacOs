# xxhc latency benchmark

## Goal
Comparable connect times per host and setup version, so a change's effect on latency is visible.

## What it does
- `xxhc-bench [-n N] [--net LABEL] [host…]` (fish function in `terminal/`), defaults: hosts `root6` (via jump host j2admin) and `itet-ifa-comp01` (ETH direct), `N=5`.
- Each run: `xxhc <host> +hc fish_greeting`, a full real connect (upload, greeting, history merge, cleanup) without an interactive session.
- Per run it records the greeting's `Connected in X s` (connect until the prompt would appear) and the wall time of the whole `xxhc` call (connect + teardown).
- Per host it appends one row to `terminal/benchmarks.md`: date, setup version, host, route (`jump` / `direct`, from `ssh -G`), network label, runs, connect avg / min / max, total avg.
- A failed run (no `Connected in` line) counts as failed, shows in the row (`4/5`), and is left out of the averages.
- Terminal tool rules: `--help`, fish completion (hosts from `~/.ssh/config`, flags with descriptions), a hint at the end (`open terminal/benchmarks.md`) and on errors.

## Done-list
- [ ] `xxhc-bench` with no arguments runs 5 connects each to root6 and itet-ifa-comp01 and appends 2 rows to `terminal/benchmarks.md`
- [x] `-n`, `--net`, explicit hosts work; `--help` / `-h`; tab completion lists flags and hosts
- [x] a failed connect shows as `n/N` and doesn't skew the averages
- [ ] `benchmarks.md` starts with the 3.2.2 baseline for both hosts
- [x] offline tests (stubbed `xxhc`) for parsing, averaging, failed runs and the row format
- [x] `terminal.md` documents the tool; the old one-off root6 numbers point to `benchmarks.md`
- [ ] terminal minor bump (3.3.0)

## Untouched
`xxhc` itself, the remote setup, the upload path.

## Decisions
- 2026-11-20: `--net` defaults to `-`; times rounded to 0.1 s; Total avg also counts successful runs only; files: `terminal/.config/fish/functions/xxhc-bench.fish`, completion in `terminal/.config/fish/completions/`, `XXHC_BENCH_FILE` overrides the output file (tests).
- 2026-11-20: baseline run on office network (owner).
- 2026-11-20: hosts root6 + itet-ifa-comp01 (owner, ⭐ option).
- 2026-11-20: 5 runs per host, `+hc fish_greeting` as the run (owner OK with the spec).
