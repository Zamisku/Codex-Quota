#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DERIVED_DATA="${DERIVED_DATA:-${ROOT_DIR}/.build/ReleaseDerivedData}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/.build/release}"
APP_NAME="Codex Quota.app"
EXPECTED_BUNDLE_ID="com.Zamisku.Codex-Quota"
EXPECTED_WIDGET_BUNDLE_ID="com.Zamisku.Codex-Quota.widget"
EXPECTED_APP_GROUP="X9MB8SQZHF.com.Zamisku.CodexQuota.shared"
WIDGET_RELATIVE_PATH="Contents/PlugIns/CodexQuotaWidgetExtension.appex"
ARCHIVE_NAME="Codex-Quota-macOS-universal.zip"
DMG_NAME="Codex-Quota-macOS-universal.dmg"
CHECKSUM_NAME="SHA256SUMS"
SKIP_BUILD="${SKIP_BUILD:-0}"
RUN_TESTS="${RUN_TESTS:-1}"
REQUIRE_NOTARIZED="${REQUIRE_NOTARIZED:-0}"

for tool in /usr/bin/codesign /usr/bin/ditto /usr/bin/hdiutil /usr/bin/lipo /usr/bin/shasum; do
    [[ -x "${tool}" ]] || { print -u2 "缺少发行工具：${tool}"; exit 1; }
done

if [[ "${SKIP_BUILD}" != "1" ]]; then
    for tool in xcodegen xcodebuild; do
        command -v "${tool}" >/dev/null 2>&1 || {
            print -u2 "缺少构建工具：${tool}"
            exit 1
        }
    done

    cd "${ROOT_DIR}"
    xcodegen generate

    if [[ "${RUN_TESTS}" == "1" ]]; then
        test_arch="$(/usr/bin/uname -m)"
        xcodebuild \
            -project Codex-Quota.xcodeproj \
            -scheme Codex-Quota \
            -configuration Debug \
            -destination "platform=macOS,arch=${test_arch}" \
            -derivedDataPath "${DERIVED_DATA}" \
            CODE_SIGNING_ALLOWED=NO \
            ONLY_ACTIVE_ARCH=YES \
            ARCHS="${test_arch}" \
            test
    fi

    xcodebuild \
        -project Codex-Quota.xcodeproj \
        -scheme Codex-Quota \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -derivedDataPath "${DERIVED_DATA}" \
        build
fi

SOURCE_APP="${APP_PATH:-${DERIVED_DATA}/Build/Products/Release/${APP_NAME}}"
[[ -d "${SOURCE_APP}" ]] || {
    print -u2 "找不到已构建应用：${SOURCE_APP}"
    exit 1
}

WORK_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-quota-release.XXXXXX")"
trap '/bin/rm -rf "${WORK_DIR}"' EXIT

STAGED_APP="${WORK_DIR}/${APP_NAME}"
/usr/bin/ditto "${SOURCE_APP}" "${STAGED_APP}"
WIDGET_PATH="${STAGED_APP}/${WIDGET_RELATIVE_PATH}"
[[ -d "${WIDGET_PATH}" ]] || { print -u2 "发行包缺少 Widget Extension"; exit 1; }

HOST_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${STAGED_APP}/Contents/Info.plist")"
WIDGET_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${WIDGET_PATH}/Contents/Info.plist")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${STAGED_APP}/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${STAGED_APP}/Contents/Info.plist")"

[[ "${HOST_BUNDLE_ID}" == "${EXPECTED_BUNDLE_ID}" ]] || { print -u2 "宿主 Bundle ID 不匹配"; exit 1; }
[[ "${WIDGET_BUNDLE_ID}" == "${EXPECTED_WIDGET_BUNDLE_ID}" ]] || { print -u2 "Widget Bundle ID 不匹配"; exit 1; }
[[ "${VERSION}" == <->.<->.<-> ]] || { print -u2 "版本号格式无效：${VERSION}"; exit 1; }
if [[ -n "${RELEASE_VERSION:-}" && "${VERSION}" != "${RELEASE_VERSION}" ]]; then
    print -u2 "构建版本 ${VERSION} 与 RELEASE_VERSION=${RELEASE_VERSION} 不一致"
    exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "${STAGED_APP}"

for executable in \
    "${STAGED_APP}/Contents/MacOS/Codex Quota" \
    "${WIDGET_PATH}/Contents/MacOS/CodexQuotaWidgetExtension"; do
    architectures="$(/usr/bin/lipo -archs "${executable}")"
    [[ " ${architectures} " == *" arm64 "* && " ${architectures} " == *" x86_64 "* ]] || {
        print -u2 "发行文件不是 Universal Binary：${executable} (${architectures})"
        exit 1
    }
done

host_entitlements="$(/usr/bin/codesign -d --entitlements :- "${STAGED_APP}" 2>/dev/null)"
widget_entitlements="$(/usr/bin/codesign -d --entitlements :- "${WIDGET_PATH}" 2>/dev/null)"
[[ "${host_entitlements}" == *"${EXPECTED_APP_GROUP}"* ]] || { print -u2 "宿主缺少 App Group"; exit 1; }
[[ "${widget_entitlements}" == *"${EXPECTED_APP_GROUP}"* ]] || { print -u2 "Widget 缺少 App Group"; exit 1; }
[[ "${widget_entitlements}" == *"com.apple.security.app-sandbox"* ]] || { print -u2 "Widget 未启用沙盒"; exit 1; }

for resource in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
    [[ -f "${STAGED_APP}/Contents/Resources/${resource}" ]] || {
        print -u2 "发行包缺少资源：${resource}"
        exit 1
    }
done

signature_info="$(/usr/bin/codesign -dv --verbose=4 "${STAGED_APP}" 2>&1)"
[[ "${signature_info}" == *"flags="*"runtime"* ]] || { print -u2 "发行包未启用 Hardened Runtime"; exit 1; }

notary_values=("${NOTARY_KEY:-}" "${NOTARY_KEY_ID:-}" "${NOTARY_ISSUER:-}")
notary_count=0
for value in "${notary_values[@]}"; do
    [[ -n "${value}" ]] && (( notary_count += 1 ))
done

if (( notary_count != 0 && notary_count != 3 )); then
    print -u2 "公证参数不完整：需要同时提供 NOTARY_KEY、NOTARY_KEY_ID、NOTARY_ISSUER"
    exit 1
fi

NOTARIZE=0
if (( notary_count == 3 )); then
    NOTARIZE=1
fi

if [[ "${REQUIRE_NOTARIZED}" == "1" && "${NOTARIZE}" != "1" ]]; then
    print -u2 "该发行要求公证，但未提供公证凭据"
    exit 1
fi

if [[ "${NOTARIZE}" == "1" ]]; then
    [[ "${signature_info}" == *"Authority=Developer ID Application:"* ]] || {
        print -u2 "公证发行必须使用 Developer ID Application 签名"
        exit 1
    }

    NOTARY_ZIP="${WORK_DIR}/notary-submission.zip"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "${STAGED_APP}" "${NOTARY_ZIP}"
    xcrun notarytool submit "${NOTARY_ZIP}" \
        --key "${NOTARY_KEY}" \
        --key-id "${NOTARY_KEY_ID}" \
        --issuer "${NOTARY_ISSUER}" \
        --wait
    xcrun stapler staple "${STAGED_APP}"
    xcrun stapler validate "${STAGED_APP}"
fi

if ! gatekeeper_output="$(/usr/sbin/spctl -a -t exec -vv "${STAGED_APP}" 2>&1)"; then
    if [[ "${REQUIRE_NOTARIZED}" == "1" ]]; then
        print -u2 "Gatekeeper 验证失败：${gatekeeper_output}"
        exit 1
    fi
    print -u2 "警告：当前构建未通过 Gatekeeper（通常表示使用 Apple Development 签名且未公证）。"
fi

/bin/mkdir -p "${OUTPUT_DIR}"
/bin/rm -f \
    "${OUTPUT_DIR}/${ARCHIVE_NAME}" \
    "${OUTPUT_DIR}/${DMG_NAME}" \
    "${OUTPUT_DIR}/${CHECKSUM_NAME}"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
    "${STAGED_APP}" \
    "${OUTPUT_DIR}/${ARCHIVE_NAME}"

DMG_ROOT="${WORK_DIR}/dmg"
/bin/mkdir -p "${DMG_ROOT}"
/usr/bin/ditto "${STAGED_APP}" "${DMG_ROOT}/${APP_NAME}"
/bin/ln -s /Applications "${DMG_ROOT}/Applications"
/usr/bin/hdiutil create \
    -quiet \
    -volname "Codex Quota" \
    -srcfolder "${DMG_ROOT}" \
    -ov \
    -format UDZO \
    "${OUTPUT_DIR}/${DMG_NAME}"

if [[ "${NOTARIZE}" == "1" ]]; then
    xcrun notarytool submit "${OUTPUT_DIR}/${DMG_NAME}" \
        --key "${NOTARY_KEY}" \
        --key-id "${NOTARY_KEY_ID}" \
        --issuer "${NOTARY_ISSUER}" \
        --wait
    xcrun stapler staple "${OUTPUT_DIR}/${DMG_NAME}"
    xcrun stapler validate "${OUTPUT_DIR}/${DMG_NAME}"
fi

(
    cd "${OUTPUT_DIR}"
    /usr/bin/shasum -a 256 "${ARCHIVE_NAME}" "${DMG_NAME}" > "${CHECKSUM_NAME}"
)

print "发行包已生成："
print "  版本：${VERSION} (${BUILD_NUMBER})"
print "  ZIP：${OUTPUT_DIR}/${ARCHIVE_NAME}"
print "  DMG：${OUTPUT_DIR}/${DMG_NAME}"
print "  校验：${OUTPUT_DIR}/${CHECKSUM_NAME}"
if [[ "${NOTARIZE}" == "1" ]]; then
    print "  状态：Developer ID 已签名并通过 Apple 公证"
else
    print "  状态：已签名但未公证；Finder 下载后首次启动可能需要右键选择“打开”"
fi
