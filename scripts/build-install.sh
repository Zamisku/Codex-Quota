#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DERIVED_DATA="${DERIVED_DATA:-${ROOT_DIR}/.build/DerivedData}"
PROJECT="${ROOT_DIR}/Codex-Quota.xcodeproj"
SCHEME="Codex-Quota"
APP_NAME="Codex Quota.app"
APP_PATH="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}"
INSTALL_PATH="/Applications/${APP_NAME}"
EXPECTED_BUNDLE_ID="com.Zamisku.Codex-Quota"
EXPECTED_WIDGET_BUNDLE_ID="com.Zamisku.Codex-Quota.widget"
EXPECTED_APP_GROUP="X9MB8SQZHF.com.Zamisku.CodexQuota.shared"
WIDGET_RELATIVE_PATH="Contents/PlugIns/CodexQuotaWidgetExtension.appex"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

for tool in xcodegen xcodebuild codesign lipo ditto mdfind pluginkit; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        if [[ "${tool}" == "xcodegen" ]]; then
            print -u2 "缺少 XcodeGen。请先运行：brew install xcodegen"
        else
            print -u2 "缺少构建工具：${tool}"
        fi
        exit 1
    fi
done
test -x "${LSREGISTER}"

unregister_duplicate_app() {
    local candidate="$1"
    [[ -d "${candidate}" && "${candidate}" != "${INSTALL_PATH}" ]] || return 0

    local bundle_id
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${candidate}/Contents/Info.plist" 2>/dev/null || true)"
    [[ "${bundle_id}" == "${EXPECTED_BUNDLE_ID}" ]] || return 0

    local candidate_extension="${candidate}/${WIDGET_RELATIVE_PATH}"
    if [[ -d "${candidate_extension}" ]]; then
        /usr/bin/pluginkit -r "${candidate_extension}" >/dev/null 2>&1 || true
    fi
    "${LSREGISTER}" -u "${candidate}" >/dev/null 2>&1 || true
}

cd "${ROOT_DIR}"
xcodegen generate

xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -destination "platform=macOS" \
    -derivedDataPath "${DERIVED_DATA}" \
    test

xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "${DERIVED_DATA}" \
    build

test -d "${APP_PATH}"
EXTENSION_PATH="${APP_PATH}/${WIDGET_RELATIVE_PATH}"
test -d "${EXTENSION_PATH}"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP_PATH}/Contents/Info.plist")" = "${EXPECTED_BUNDLE_ID}"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${EXTENSION_PATH}/Contents/Info.plist")" = "${EXPECTED_WIDGET_BUNDLE_ID}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

for executable in \
    "${APP_PATH}/Contents/MacOS/Codex Quota" \
    "${EXTENSION_PATH}/Contents/MacOS/CodexQuotaWidgetExtension"; do
    architectures="$(/usr/bin/lipo -archs "${executable}")"
    [[ " ${architectures} " == *" arm64 "* && " ${architectures} " == *" x86_64 "* ]]
done

host_entitlements="$(/usr/bin/codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null)"
widget_entitlements="$(/usr/bin/codesign -d --entitlements :- "${EXTENSION_PATH}" 2>/dev/null)"
[[ "${host_entitlements}" == *"${EXPECTED_APP_GROUP}"* ]]
[[ "${widget_entitlements}" == *"${EXPECTED_APP_GROUP}"* ]]
[[ "${widget_entitlements}" == *"com.apple.security.app-sandbox"* ]]

test -f "${APP_PATH}/Contents/Resources/THIRD_PARTY_NOTICES.md"
test -f "${APP_PATH}/Contents/Resources/LICENSE"
test -f "${APP_PATH}/Contents/Resources/NOTICE"

if [[ ! -w "/Applications" ]]; then
    print -u2 "没有写入 /Applications 的权限；脚本不会自动使用 sudo。"
    exit 1
fi

/usr/bin/pkill -x "Codex Quota" 2>/dev/null || true
for _ in {1..40}; do
    if ! /usr/bin/pgrep -x "Codex Quota" >/dev/null 2>&1; then
        break
    fi
    /bin/sleep 0.25
done
if /usr/bin/pgrep -x "Codex Quota" >/dev/null 2>&1; then
    print -u2 "旧版 Codex Quota 未能在 10 秒内退出，已取消安装。"
    exit 1
fi

if [[ -e "${INSTALL_PATH}" ]]; then
    installed_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INSTALL_PATH}/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "${installed_bundle_id}" != "${EXPECTED_BUNDLE_ID}" ]]; then
        print -u2 "拒绝覆盖 bundle id 不匹配的应用：${INSTALL_PATH}"
        exit 1
    fi
    backup_path="${TMPDIR:-/tmp}/Codex Quota-backup-$(date +%Y%m%d-%H%M%S).app"
    /bin/mv "${INSTALL_PATH}" "${backup_path}"
    print "旧版本已备份到：${backup_path}"
fi

/usr/bin/ditto "${APP_PATH}" "${INSTALL_PATH}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${INSTALL_PATH}"

# xcodebuild 会把 DerivedData 中的 App 与 Widget 一并注册到系统。若同一
# Bundle ID 留有多份记录，WidgetKit 可能继续启动旧构建而不是 /Applications。
for candidate in \
    "${DERIVED_DATA}/Build/Products/Debug/${APP_NAME}" \
    "${APP_PATH}"; do
    unregister_duplicate_app "${candidate}"
done
while IFS= read -r candidate; do
    unregister_duplicate_app "${candidate}"
done < <(/usr/bin/mdfind "kMDItemCFBundleIdentifier == '${EXPECTED_BUNDLE_ID}'")

INSTALLED_EXTENSION="${INSTALL_PATH}/${WIDGET_RELATIVE_PATH}"
"${LSREGISTER}" -f -R -trusted "${INSTALL_PATH}"
/usr/bin/pluginkit -a "${INSTALLED_EXTENSION}"
/usr/bin/pkill -x CodexQuotaWidgetExtension 2>/dev/null || true
/usr/bin/pkill -x chronod 2>/dev/null || true
/usr/bin/pkill -x NotificationCenter 2>/dev/null || true
/usr/bin/killall Dock 2>/dev/null || true
/bin/sleep 1
/usr/bin/open "${INSTALL_PATH}"

print "WidgetKit 已切换到：${INSTALLED_EXTENSION}"
print "安装完成：${INSTALL_PATH}"
