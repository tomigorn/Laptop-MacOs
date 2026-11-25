# Model fallback for shared desks

Open office: no fixed desk, every desk a new monitor UUID. Layout must follow the monitor model.

## Lookup
UUID → name with a layout line → model rule → `default`.

- `model <Product-Name> <name>` in zones.conf, spaces in the product name written as `-` (`model HP-E34m-G4 Work-HP-Ultrawide`).
- A UUID line whose name has no layout line (`mon-XXXX`) falls through to the model rule.
- Model of a display: `ioreg -lw0`, lines with `"DisplayAttributes"` holding `ProductName`, `NativeFormatHorizontalPixels`, `NativeFormatVerticalPixels`. A yabai display matches the ioreg entries whose pixel aspect ratio is within 2% of its frame w/h; used only if all matches share one product name.
- ioreg runs only when the UUID lookup gives no layout.

## Registration
An unknown display whose model matches a rule is not appended (no clutter from weekly desks). Others are appended as before, with the product name in the comment.

## Connected block
Extra `model` column (product name, `-` when none).

## Testability
PATH is appended to, not prepended, so stubbed `yabai`/`ioreg` win in tests. Test: `window-manager/tests/model-fallback.sh` (bash 5), stubs yabai + ioreg, checks `connected` output and zones.conf.
