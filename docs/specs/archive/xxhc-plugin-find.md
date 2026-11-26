# xxhc: plugin loader without plugins

## What it does
`xxh-config.fish` loads `*pluginrc.fish` from `plugins/*/build` only when such a directory exists. Without one it skips `find`, which would otherwise search the remote cwd (the home folder).

## Why
On `hv002` the home has a CIFS share mounted (`~/mnt/cds`). The bare `find` walked it, and `xxhc hv002` hung for minutes after `transfer:`.

## Done-list
- [x] Test fails on the old code: no plugin dirs → `find` must not run (`terminal/tests/xxhc.fish`)
- [x] Test: a plugin build dir → `find` searches it
- [x] `tests/test-all.sh` green
- [x] `xxhc hv002` reaches the prompt (18.9 s, was hanging for minutes), history merged, cleanup verified

## Decisions
- 2026-11-26: guard the loader instead of removing it, so plugins still work if added later.
