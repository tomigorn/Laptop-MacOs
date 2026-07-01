#!/usr/bin/env bash
# Generates a launcher icon: a white SF Symbol on a blue rounded-rect. Re-run
# after changing it, then run build-launcher.sh to apply.
#   make-icon.sh [symbol] [out-name]
#     symbol    SF Symbol name          (default: rectangle.split.3x1)
#     out-name  basename of the .icns   (default: AppIcon -> AppIcon.icns)
# Examples:
#   ./make-icon.sh                              # AppIcon.icns  (config launcher)
#   ./make-icon.sh arrow.clockwise RestartIcon  # RestartIcon.icns (restart launcher)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SYMBOL="${1:-rectangle.split.3x1}"
OUT="${2:-AppIcon}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SWIFT="$TMP/mkicon.swift"; PNG="$TMP/icon.png"

cat > "$SWIFT" <<'SWIFT'
import AppKit
let args = CommandLine.arguments
let outPath = args[args.count - 1]
let symbol  = args[args.count - 2]
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S)); img.lockFocus()
let inset: CGFloat = 70
let rect = NSRect(x: inset, y: inset, width: S - 2*inset, height: S - 2*inset)
NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190).addClip()
NSGradient(colors: [NSColor(srgbRed: 0.20, green: 0.52, blue: 0.98, alpha: 1),
                    NSColor(srgbRed: 0.07, green: 0.26, blue: 0.72, alpha: 1)])!.draw(in: rect, angle: -90)
let cfg = NSImage.SymbolConfiguration(pointSize: 480, weight: .semibold)
for n in [symbol, "rectangle.split.3x1", "rectangle.split.2x1", "macwindow"] {
  if let raw = NSImage(systemSymbolName: n, accessibilityDescription: nil),
     let sym = raw.withSymbolConfiguration(cfg) {
    let t = NSImage(size: sym.size); t.lockFocus()
    sym.draw(at: .zero, from: NSRect(origin: .zero, size: sym.size), operation: .sourceOver, fraction: 1)
    NSColor.white.set(); NSRect(origin: .zero, size: sym.size).fill(using: .sourceAtop); t.unlockFocus()
    t.draw(in: NSRect(x: (S-sym.size.width)/2, y: (S-sym.size.height)/2, width: sym.size.width, height: sym.size.height))
    break
  }
}
img.unlockFocus()
let png = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
SWIFT

swift "$SWIFT" "$SYMBOL" "$PNG" 2>/dev/null
ICONSET="$TMP/AppIcon.iconset"; mkdir -p "$ICONSET"
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" \
            "256 128x128@2x" "256 256x256" "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do
  set -- $spec
  sips -z "$1" "$1" "$PNG" --out "$ICONSET/icon_$2.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$SRC_DIR/$OUT.icns"
echo "wrote $SRC_DIR/$OUT.icns (symbol: $SYMBOL)"
