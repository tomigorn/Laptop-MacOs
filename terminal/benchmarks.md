# xxhc benchmarks

One row per host and `xxhc-bench` run (`terminal/terminal.md`, "Benchmark"). Times in seconds; failed runs count in Runs but not in the times.

- Connect: the greeting's `Connected in`, until the prompt would appear.
- Total: the whole `xxhc` call, connect and teardown.

| Date | Version | Host | Route | Net | Runs | Connect avg | Connect min | Connect max | Total avg |
|---|---|---|---|---|---|---|---|---|---|
| 2026-11-20 | 3.2.2 | root6 | jump | office | 5/5 | 1.7 | 1.6 | 2.0 | 2.3 |
