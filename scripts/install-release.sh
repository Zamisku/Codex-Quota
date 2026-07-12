#!/bin/zsh
set -euo pipefail

REPOSITORY="Zamisku/Codex-Quota"
ARCHIVE_NAME="Codex-Quota-macOS-universal.zip"
CHECKSUM_NAME="SHA256SUMS"
RELEASE_BASE_URL="${CODEX_QUOTA_RELEASE_BASE_URL:-https://github.com/${REPOSITORY}/releases/latest/download}"
INSTALL_DIR="${CODEX_QUOTA_INSTALL_DIR:-/Applications}"
BACKUP_DIR="${CODEX_QUOTA_BACKUP_DIR:-${HOME}/Library/Application Support/Codex Quota/Backups}"
APP_NAME="Codex Quota.app"
INSTALL_PATH="${INSTALL_DIR}/${APP_NAME}"
EXPECTED_BUNDLE_ID="com.Zamisku.Codex-Quota"
EXPECTED_WIDGET_BUNDLE_ID="com.Zamisku.Codex-Quota.widget"
WIDGET_RELATIVE_PATH="Contents/PlugIns/CodexQuotaWidgetExtension.appex"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

for tool in /usr/bin/curl /usr/bin/ditto /usr/bin/shasum /usr/bin/codesign /usr/libexec/PlistBuddy; do
    [[ -x "${tool}" ]] || { print -u2 "系统缺少安装工具：${tool}"; exit 1; }
done

WORK_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-quota-install.XXXXXX")"
trap '/bin/rm -rf "${WORK_DIR}"' EXIT
ARCHIVE_PATH="${WORK_DIR}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${WORK_DIR}/${CHECKSUM_NAME}"

curl_options=(--fail --location --retry 3 --silent --show-error)
if [[ "${RELEASE_BASE_URL}" == https://* ]]; then
    curl_options+=(--proto "=https" --tlsv1.2)
fi

print "正在下载 Codex Quota 最新发行版…"
/usr/bin/curl "${curl_options[@]}" \
    "${RELEASE_BASE_URL}/${ARCHIVE_NAME}" \
    --output "${ARCHIVE_PATH}"
/usr/bin/curl "${curl_options[@]}" \
    "${RELEASE_BASE_URL}/${CHECKSUM_NAME}" \
    --output "${CHECKSUM_PATH}"

expected_checksum="$(/usr/bin/awk -v asset="${ARCHIVE_NAME}" '$2 == asset { print $1 }' "${CHECKSUM_PATH}")"
[[ "${expected_checksum}" =~ ^[0-9a-f]{64}$ ]] || { print -u2 "发行版校验文件无效"; exit 1; }
actual_checksum="$(/usr/bin/shasum -a 256 "${ARCHIVE_PATH}" | /usr/bin/awk '{ print $1 }')"
[[ "${actual_checksum}" == "${expected_checksum}" ]] || {
    print -u2 "下载文件 SHA-256 校验失败"
    exit 1
}

EXTRACT_DIR="${WORK_DIR}/extract"
/bin/mkdir -p "${EXTRACT_DIR}"
/usr/bin/ditto -x -k "${ARCHIVE_PATH}" "${EXTRACT_DIR}"
SOURCE_APP="${EXTRACT_DIR}/${APP_NAME}"
SOURCE_WIDGET="${SOURCE_APP}/${WIDGET_RELATIVE_PATH}"
[[ -d "${SOURCE_APP}" && -d "${SOURCE_WIDGET}" ]] || { print -u2 "发行包结构无效"; exit 1; }

host_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${SOURCE_APP}/Contents/Info.plist")"
widget_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${SOURCE_WIDGET}/Contents/Info.plist")"
[[ "${host_bundle_id}" == "${EXPECTED_BUNDLE_ID}" ]] || { print -u2 "宿主 Bundle ID 校验失败"; exit 1; }
[[ "${widget_bundle_id}" == "${EXPECTED_WIDGET_BUNDLE_ID}" ]] || { print -u2 "Widget Bundle ID 校验失败"; exit 1; }
/usr/bin/codesign --verify --deep --strict "${SOURCE_APP}"

/bin/mkdir -p "${INSTALL_DIR}"
[[ -w "${INSTALL_DIR}" ]] || {
    print -u2 "没有写入 ${INSTALL_DIR} 的权限。请使用具有管理员权限的 macOS 账户。"
    exit 1
}

backup_path=""
if [[ -e "${INSTALL_PATH}" ]]; then
    installed_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INSTALL_PATH}/Contents/Info.plist" 2>/dev/null || true)"
    [[ "${installed_bundle_id}" == "${EXPECTED_BUNDLE_ID}" ]] || {
        print -u2 "拒绝覆盖 Bundle ID 不匹配的应用：${INSTALL_PATH}"
        exit 1
    }

    /usr/bin/pkill -x "Codex Quota" 2>/dev/null || true
    for _ in {1..40}; do
        /usr/bin/pgrep -x "Codex Quota" >/dev/null 2>&1 || break
        /bin/sleep 0.25
    done
    if /usr/bin/pgrep -x "Codex Quota" >/dev/null 2>&1; then
        print -u2 "旧版 Codex Quota 未能退出，安装已取消。"
        exit 1
    fi

    /bin/mkdir -p "${BACKUP_DIR}"
    backup_path="${BACKUP_DIR}/Codex Quota-$(/bin/date +%Y%m%d-%H%M%S).app"
    /bin/mv "${INSTALL_PATH}" "${backup_path}"
fi

if ! /usr/bin/ditto "${SOURCE_APP}" "${INSTALL_PATH}"; then
    /bin/rm -rf "${INSTALL_PATH}"
    [[ -n "${backup_path}" && -d "${backup_path}" ]] && /bin/mv "${backup_path}" "${INSTALL_PATH}"
    print -u2 "安装失败，已恢复旧版本。"
    exit 1
fi

if ! /usr/bin/codesign --verify --deep --strict "${INSTALL_PATH}"; then
    /bin/rm -rf "${INSTALL_PATH}"
    [[ -n "${backup_path}" && -d "${backup_path}" ]] && /bin/mv "${backup_path}" "${INSTALL_PATH}"
    print -u2 "安装后签名校验失败，已恢复旧版本。"
    exit 1
fi

if [[ "${CODEX_QUOTA_SKIP_REGISTER:-0}" != "1" ]]; then
    "${LSREGISTER}" -f -R -trusted "${INSTALL_PATH}"
    /usr/bin/pluginkit -a "${INSTALL_PATH}/${WIDGET_RELATIVE_PATH}" >/dev/null 2>&1 || true
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INSTALL_PATH}/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${INSTALL_PATH}/Contents/Info.plist")"
print "安装完成：${INSTALL_PATH}"
print "版本：${version} (${build})"
[[ -n "${backup_path}" ]] && print "旧版本备份：${backup_path}"

if [[ "${CODEX_QUOTA_SKIP_LAUNCH:-0}" != "1" ]]; then
    /usr/bin/open "${INSTALL_PATH}"
fi

print "打开应用并完成一次刷新后，即可在桌面小组件库中搜索 Codex Quota。"
