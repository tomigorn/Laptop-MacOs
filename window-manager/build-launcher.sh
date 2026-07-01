#!/usr/bin/env bash
# Builds the Spotlight/Launchpad launcher apps into ~/Applications:
#
#   "yabai window manager.app"            -> opens ~/.config/yabai in VS Code
#   "yabai window manager - restart.app"  -> restarts the yabai + skhd services
#
# Both are searchable in Spotlight by "yabai" or "window manager". Each app's
# executable and Info.plist are symlinked back into this repo, so edits here are
# immediately live — re-run this script after editing them to re-register.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

# build_app <app-name> <exec-script> <exec-name> <plist> <icns>
#   app-name    the "<name>.app" bundle under ~/Applications
#   exec-script script in this repo to symlink as the executable
#   exec-name   MacOS executable filename (must match CFBundleExecutable in the plist)
#   plist       Info.plist in this repo to symlink
#   icns        icon file in this repo to copy (Resources/AppIcon.icns), if present
build_app() {
    local name="$1" exec_script="$2" exec_name="$3" plist="$4" icns="$5"
    local app_dir="${HOME}/Applications/${name}.app"

    echo "==> Rebuilding ${app_dir}"
    rm -rf "${app_dir}"
    mkdir -p "${app_dir}/Contents/MacOS" "${app_dir}/Contents/Resources"

    # Symlinks back into the repo — repo is the source of truth.
    chmod +x "${SRC_DIR}/${exec_script}"
    ln -sf "${SRC_DIR}/${exec_script}" "${app_dir}/Contents/MacOS/${exec_name}"
    ln -sf "${SRC_DIR}/${plist}"       "${app_dir}/Contents/Info.plist"

    # 8-byte PkgInfo: "APPL" + "????" (unsigned local app)
    printf 'APPL????' > "${app_dir}/Contents/PkgInfo"

    # Icon copied (not symlinked) so Launch Services reads it reliably. Keep the
    # basename — each plist's CFBundleIconFile points at its own icon by name.
    if [[ -f "${SRC_DIR}/${icns}" ]]; then
        cp "${SRC_DIR}/${icns}" "${app_dir}/Contents/Resources/${icns}"
        echo "==> Using ${icns}"
    else
        echo "==> No ${icns} — run make-icon.sh to generate one (generic icon for now)"
    fi

    echo "==> Refreshing Launch Services registration"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "${app_dir}" || true
    xattr -dr com.apple.quarantine "${app_dir}" 2>/dev/null || true
}

build_app "yabai window manager"           launcher.sh         yabai-window-manager         Info.plist         AppIcon.icns
build_app "yabai window manager - restart" restart-launcher.sh yabai-window-manager-restart restart-Info.plist RestartIcon.icns

echo "==> Done."
echo "    Type 'yabai' (or 'window manager') in Spotlight:"
echo "      • yabai window manager            → open the config in VS Code"
echo "      • yabai window manager - restart  → restart yabai + skhd"
