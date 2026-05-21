#!/usr/bin/env bash
# Builds ~/Applications/Virt-Manager.app so virt-manager is reachable from
# Spotlight, Launchpad and the dock — not just from a fish terminal.
#
# launcher.sh and Info.plist are symlinked back into this repo, so edits in
# the repo are immediately live. Re-run after editing those if you need
# Launch Services to re-register the bundle.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${HOME}/Applications/Virt-Manager.app"
ICON_SRC="/opt/homebrew/share/icons/hicolor/256x256/apps/virt-manager.png"

[[ -x /opt/homebrew/bin/virt-manager ]] \
    || { echo "error: /opt/homebrew/bin/virt-manager not found — run install.sh first" >&2; exit 1; }
[[ -f "${ICON_SRC}" ]] \
    || { echo "error: icon source ${ICON_SRC} not found" >&2; exit 1; }

echo "==> Rebuilding ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

# Symlinks back into the repo — repo is source of truth.
chmod +x "${SRC_DIR}/launcher.sh"
ln -sf "${SRC_DIR}/launcher.sh" "${APP_DIR}/Contents/MacOS/virt-manager-launcher"
ln -sf "${SRC_DIR}/Info.plist"  "${APP_DIR}/Contents/Info.plist"

# 8-byte PkgInfo: "APPL" + 4-char signature ("????" = unsigned local app)
printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

# AppIcon.icns is a generated artifact built from Homebrew's PNG.
echo "==> Building AppIcon.icns"
TMP="$(mktemp -d)"
ICONSET="${TMP}/AppIcon.iconset"
mkdir -p "${ICONSET}"
for spec in "16 icon_16x16.png" \
            "32 icon_16x16@2x.png" \
            "32 icon_32x32.png" \
            "64 icon_32x32@2x.png" \
            "128 icon_128x128.png" \
            "256 icon_128x128@2x.png" \
            "256 icon_256x256.png" \
            "512 icon_256x256@2x.png" \
            "512 icon_512x512.png" \
            "1024 icon_512x512@2x.png"; do
    size="${spec% *}"
    name="${spec#* }"
    sips -z "${size}" "${size}" "${ICON_SRC}" --out "${ICONSET}/${name}" >/dev/null
done
iconutil -c icns "${ICONSET}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
rm -rf "${TMP}"

echo "==> Refreshing Launch Services registration"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "${APP_DIR}" || true

xattr -dr com.apple.quarantine "${APP_DIR}" 2>/dev/null || true

echo "==> Done. Launch with: open '${APP_DIR}'  (or type 'virt' in Spotlight)"
