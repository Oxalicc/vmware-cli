#!/usr/bin/env zsh
# 仅供用户在本机交互终端运行；Agent 不得代跑。
set -u

usage() {
    print -u2 -- '用法：run-guest-local.zsh <vmx路径> <guest命令> [参数...]'
    print -u2 -- '可用 VMRUN、VMWARE_HOST_TYPE 环境变量覆盖工具路径和主机类型。'
}

if [[ ! -t 0 || ! -t 1 ]]; then
    print -u2 -- '拒绝执行：此启动器只能由用户在本机交互终端运行。'
    exit 2
fi

if [[ $# -lt 2 ]]; then
    usage
    exit 2
fi

VMX=$1
COMMAND=$2
shift 2
VMRUN=${VMRUN:-"/Applications/VMware Fusion.app/Contents/Public/vmrun"}
HOST_TYPE=${VMWARE_HOST_TYPE:-fusion}

for ARG in "$@"; do
    case "$ARG" in
        -gu|-gp|-vp)
            print -u2 -- "拒绝执行：不要在参数中提供凭据（$ARG）。"
            exit 2
            ;;
    esac
done

case "$COMMAND" in
    runProgramInGuest|runScriptInGuest|copyFileFromHostToGuest|copyFileFromGuestToHost|fileExistsInGuest|directoryExistsInGuest|listDirectoryInGuest|createDirectoryInGuest|deleteFileInGuest|deleteDirectoryInGuest|renameFileInGuest|createTempfileInGuest|listProcessesInGuest|killProcessInGuest)
        ;;
    *)
        print -u2 -- "不支持的 guest 命令：$COMMAND"
        usage
        exit 2
        ;;
esac

if [[ ! -x "$VMRUN" ]]; then
    print -u2 -- "vmrun 不可执行：$VMRUN"
    exit 1
fi
if [[ ! -f "$VMX" ]]; then
    print -u2 -- "虚拟机配置不存在：$VMX"
    exit 1
fi

TOOLS_STATE=$("$VMRUN" -T "$HOST_TYPE" checkToolsState "$VMX" 2>&1) || {
    print -u2 -- "$TOOLS_STATE"
    exit 1
}
if [[ "$TOOLS_STATE" != *running* ]]; then
    print -u2 -- "VMware Tools 未正常运行：$TOOLS_STATE"
    exit 1
fi

print -- 'VMware Tools 正常。接下来仅在本机终端显示 vmrun 的凭据提示。'
"$VMRUN" -T "$HOST_TYPE" "$COMMAND" "$VMX" "$@"
