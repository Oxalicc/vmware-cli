#!/usr/bin/env bash
# Read-only VMware desktop toolchain probe for macOS and Linux.
set -u

LIST_ALL=0
if [[ "${1:-}" == "--list-all" || "${1:-}" == "-ListAll" ]]; then
    LIST_ALL=1
elif [[ $# -gt 0 ]]; then
    printf '用法：%s [--list-all]\n' "$0" >&2
    exit 2
fi

find_tool() {
    local name="$1"
    shift
    local path
    if command -v "$name" >/dev/null 2>&1; then
        command -v "$name"
        return 0
    fi
    for path in "$@"; do
        if [[ -x "$path" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
    done
    return 1
}

VMRUN=${VMRUN:-$(find_tool vmrun \
    "/Applications/VMware Fusion.app/Contents/Public/vmrun" \
    "/usr/lib/vmware/bin/vmrun" 2>/dev/null || true)}
VMCLI=${VMCLI:-$(find_tool vmcli \
    "/Applications/VMware Fusion.app/Contents/Public/vmcli" \
    "/usr/lib/vmware/bin/vmcli" 2>/dev/null || true)}
VDISKMANAGER=${VDISKMANAGER:-$(find_tool vmware-vdiskmanager \
    "/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager" \
    "/usr/lib/vmware/bin/vmware-vdiskmanager" 2>/dev/null || true)}

printf '== VMware 工具链 ==\n'
printf '%-22s %s\n' 'vmrun' "${VMRUN:-未安装}"
printf '%-22s %s\n' 'vmcli' "${VMCLI:-未安装}"
printf '%-22s %s\n' 'vmware-vdiskmanager' "${VDISKMANAGER:-未安装}"

if [[ -n "$VMRUN" ]]; then
    VERSION=$("$VMRUN" 2>&1 | grep -m1 'vmrun version' || true)
    [[ -z "$VERSION" ]] || printf '%-22s %s\n' 'vmrun 版本' "$VERSION"
fi

POWERSHELL=$(find_tool pwsh 2>/dev/null || find_tool powershell 2>/dev/null || true)
if [[ -n "$POWERSHELL" ]]; then
    POWERCLI=$("$POWERSHELL" -NoProfile -Command \
        '$m = Get-Module -ListAvailable VMware.PowerCLI | Select-Object -First 1; if ($m) { "已安装 v$($m.Version)" } else { "未安装 (Install-Module VMware.PowerCLI)" }' \
        2>/dev/null || printf '无法检测')
else
    POWERCLI='未检测（未找到 pwsh/powershell）'
fi
printf '%-22s %s\n' 'VMware.PowerCLI' "$POWERCLI"
printf '%-22s %s\n' 'esxcli / vim-cmd' '通过 ssh 登录 ESXi 后使用主机自带命令'

if [[ "$(uname -s)" == 'Darwin' ]]; then
    HOST_TYPE=${VMWARE_HOST_TYPE:-fusion}
    SEARCH_ROOTS=(
        "$HOME/Virtual Machines.localized"
        "$HOME/Documents/Virtual Machines.localized"
        "$HOME/Documents/Virtual Machines"
        "/Users/Shared/Virtual Machines.localized"
    )
else
    HOST_TYPE=${VMWARE_HOST_TYPE:-ws}
    SEARCH_ROOTS=(
        "$HOME/vmware"
        "$HOME/Virtual Machines"
        "$HOME/Documents/Virtual Machines"
    )
fi

printf '\n== 本地 VMware 虚拟机（-T %s）==\n' "$HOST_TYPE"
if [[ -z "$VMRUN" ]]; then
    printf '未找到 vmrun，跳过\n'
    exit 0
fi

RUNNING=$("$VMRUN" -T "$HOST_TYPE" list 2>&1 || true)
printf '%s\n' "$RUNNING"

COUNT=0
while IFS= read -r -d '' VMX; do
    COUNT=$((COUNT + 1))
    if [[ "$LIST_ALL" -eq 1 || "$COUNT" -le 20 ]]; then
        printf '  %s\n' "$VMX"
    fi
done < <(
    for ROOT in "${SEARCH_ROOTS[@]}"; do
        [[ -d "$ROOT" ]] && find "$ROOT" -maxdepth 4 -type f -name '*.vmx' -print0 2>/dev/null
    done
)

printf '已发现 .vmx：%d 台\n' "$COUNT"
if [[ "$LIST_ALL" -eq 0 && "$COUNT" -gt 20 ]]; then
    printf '仅显示前 20 台；用 --list-all 查看全部\n'
elif [[ "$COUNT" -eq 0 ]]; then
    printf '默认目录未发现；可指定其他目录用 find <目录> -name "*.vmx" 搜索\n'
fi
