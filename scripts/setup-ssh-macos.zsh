#!/usr/bin/env zsh
# 仅供用户在 macOS 本机交互终端运行；Agent 不得代跑初始授权。
set -euo pipefail

usage() {
    print -u2 -- '用法：setup-ssh-macos.zsh <guest-user>@<guest-host> [别名] [私钥路径]'
    print -u2 -- '示例：setup-ssh-macos.zsh ubuntu@192.168.1.20 ubuntu-lab'
    print -u2 -- '默认别名：vmware-guest；默认私钥：~/.ssh/id_ed25519_vmware_cli'
}

if [[ $(uname -s) != Darwin ]]; then
    print -u2 -- '拒绝执行：此设置脚本仅支持 macOS。'
    exit 2
fi
if [[ ! -t 0 || ! -t 1 ]]; then
    print -u2 -- '拒绝执行：初始授权只能由用户在本机交互终端完成。'
    exit 2
fi
if [[ $# -lt 1 || $# -gt 3 ]]; then
    usage
    exit 2
fi

TARGET=$1
ALIAS=${2:-vmware-guest}
KEY_PATH=${3:-"$HOME/.ssh/id_ed25519_vmware_cli"}
USER_PART=${TARGET%%@*}
HOST_PART=${TARGET#*@}

if [[ "$TARGET" != *@* || -z "$USER_PART" || -z "$HOST_PART" ]]; then
    print -u2 -- '目标必须写成 <guest-user>@<guest-host>。'
    exit 2
fi
if [[ ! "$USER_PART" =~ '^[A-Za-z0-9._-]+$' ]]; then
    print -u2 -- '用户名含有不支持的字符。'
    exit 2
fi
if [[ ! "$HOST_PART" =~ '^[A-Za-z0-9._:%-]+$' ]]; then
    print -u2 -- '主机地址含有不支持的字符。'
    exit 2
fi
if [[ ! "$ALIAS" =~ '^[A-Za-z0-9._-]+$' ]]; then
    print -u2 -- '别名只能包含字母、数字、点、下划线和连字符。'
    exit 2
fi
if [[ "$KEY_PATH" == "~/"* ]]; then
    KEY_PATH="$HOME/${KEY_PATH#\~/}"
fi
if [[ "$KEY_PATH" != /* || "$KEY_PATH" == *'"'* || "$KEY_PATH" == *$'\n'* ]]; then
    print -u2 -- '私钥路径必须是绝对路径，且不能包含双引号或换行。'
    exit 2
fi
for CMD in ssh ssh-add ssh-copy-id ssh-keygen; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        print -u2 -- "缺少命令：$CMD"
        exit 1
    fi
done

umask 077
install -d -m 700 "$HOME/.ssh" "$HOME/.ssh/vmware-cli"
install -d -m 700 "${KEY_PATH:h}"

if [[ ! -f "$KEY_PATH" ]]; then
    if [[ -e "$KEY_PATH.pub" ]]; then
        print -u2 -- "发现公钥但缺少私钥，拒绝覆盖：$KEY_PATH.pub"
        exit 1
    fi
    print -- '创建专用 Ed25519 密钥。建议设置私钥口令；下一步会把它存入 macOS 钥匙串。'
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "vmware-cli-$ALIAS"
elif [[ ! -f "$KEY_PATH.pub" ]]; then
    print -- '私钥已存在，只补齐公钥，不会重新生成或覆盖私钥。'
    ssh-keygen -y -f "$KEY_PATH" > "$KEY_PATH.pub"
    chmod 644 "$KEY_PATH.pub"
else
    print -- '复用现有密钥，不会重新生成或覆盖。'
fi

print -- '接下来由 ssh-copy-id 在本机终端提示客户机密码；不要把密码发给 Agent。'
ssh-copy-id -i "$KEY_PATH.pub" "$TARGET"

print -- '把私钥和私钥口令交给 macOS ssh-agent 与钥匙串管理。'
ssh-add --apple-use-keychain "$KEY_PATH"

CONFIG_PATH="$HOME/.ssh/vmware-cli/$ALIAS.conf"
TEMP_CONFIG=$(mktemp "$HOME/.ssh/vmware-cli/.$ALIAS.XXXXXX")
trap 'rm -f "$TEMP_CONFIG"' EXIT
cat > "$TEMP_CONFIG" <<EOF
Host $ALIAS
    HostName $HOST_PART
    User $USER_PART
    IdentityFile "$KEY_PATH"
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
    BatchMode yes
    StrictHostKeyChecking yes
EOF
chmod 600 "$TEMP_CONFIG"
mv "$TEMP_CONFIG" "$CONFIG_PATH"
trap - EXIT

print -- '验证非交互连接；此步骤不应再要求输入客户机密码。'
ssh -F "$CONFIG_PATH" "$ALIAS" true

print -- "设置完成。别名：$ALIAS"
print -- "非敏感配置：$CONFIG_PATH"
print -- '后续 Agent 可使用：'
print -- "ssh -F \"$CONFIG_PATH\" \"$ALIAS\" '<只读命令>'"
