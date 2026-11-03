# 客户机认证与 SSH 引导安全指引

## 强制边界

1. Agent 不得在对话中索取或接收真实密码、令牌、私钥内容或私钥口令，也不得代跑包含这些信息的脚本。用户名、主机地址、Host 别名和密钥路径是非敏感连接配置，可以保存和复用。
2. Agent 只能先执行只读的 `checkToolsState`；不得通过无凭据 guest 命令试探认证，因为 `vmrun` 可能显示 `Guest user:` / `Guest password:`。
3. 初始密码认证由用户在本机交互终端完成。不要自制加密密码文件：如果解密密钥与密文放在一起，只会形成新的明文等价物。优先使用 SSH 公钥和操作系统钥匙串/agent。
4. 不得用 Base64、十六进制或变量拼接“隐藏”密码；这些都不是加密。禁止 `VM_PASS_B64`、`echo "$PASS" | sudo -S` 及同类做法。
5. 不得把真实密钥、用户路径或部署专用公钥写入通用技能。公钥可以交给用户，但模板必须使用占位符；私钥始终留在用户本机。

## 阶段一：macOS 一次性设置

1. 用只读命令确认 `.vmx`、电源状态、VMware Tools 和 IP。先确认 guest 用户名，不要尝试宿主机默认用户名。
2. 把以下命令交给用户在本机终端执行一次；Agent 不得代跑：

```zsh
zsh <skill目录>/scripts/setup-ssh-macos.zsh \
  <guest-user>@<guest-ip> <别名>
```

脚本会：
- 复用 `~/.ssh/id_ed25519_vmware_cli`，不存在时才创建；绝不主动覆盖已有私钥。
- 运行一次 `ssh-copy-id`，由用户在本机输入客户机密码。
- 运行 `ssh-add --apple-use-keychain`，把私钥口令交给 macOS 钥匙串；建议用户为私钥设置口令，不要为了自动化选择空口令。
- 生成权限为 600 的 `~/.ssh/vmware-cli/<别名>.conf`，其中只有 Host、HostName、User、IdentityFile 等非敏感配置。
- 在用户终端验证一次非交互 SSH。用户只需回复成功或失败以及可公开的错误文本，不要发送密码或私钥。

不要假定默认公钥存在，不要先让用户盲目运行 `ssh-copy-id` 再处理 `No identities found`。设置脚本已经处理密钥缺失和公钥缺失。

## 阶段二：授权后由 Agent 接手

1. 用户确认设置成功后，Agent 必须在自己的执行环境中验证同一配置，不能仅凭用户说“已解锁”就承诺后续无需认证：

```bash
ssh -F "$HOME/.ssh/vmware-cli/<别名>.conf" -o BatchMode=yes <别名> true
```

2. 验证成功后，只读统计、检查、构建等后续命令默认由 Agent 执行，不得再次交给用户：

```bash
ssh -F "$HOME/.ssh/vmware-cli/<别名>.conf" -o BatchMode=yes <别名> \
  'df -h /; du -sh /var/cache/apt "$HOME/.cache" 2>/dev/null'
```

3. 配置文件必须保留 `IdentitiesOnly=yes`、`UseKeychain yes`、`BatchMode=yes` 和 `StrictHostKeyChecking yes`。Agent 只使用配置和密钥路径，不读取、复制、上传或输出私钥内容。
4. 清理、安装、写文件、改权限或启动服务等修改类命令，先展示确切范围并取得确认，然后同样由 Agent 执行。
5. 需要 sudo 时先尝试用户已授权的 `sudo -n <确切命令>`；不得用 `sudo -S`。如果 sudo 仍需交互密码，才把该条 sudo 命令交给用户本机执行，并明确说明原因。

## 禁止重复解锁与环境分裂

- 不要为单次任务创建新的 `SSH_AUTH_SOCK`，不要把 Agent 私有 socket 交给用户再次 `ssh-add`。这会造成“默认 agent 已解锁、Agent 仍无法认证”的反复操作。
- macOS 持久方案是钥匙串加固定 SSH 配置，不是每条命令前运行 `ssh-add`。如果 Agent 环境没有 `SSH_AUTH_SOCK`，仍使用 `UseKeychain yes` 的配置验证；不要自行启动临时 agent 代替验证。
- 非 macOS 平台优先复用用户已有的持久 ssh-agent 或系统凭据设施。Agent 必须先验证自己的进程能使用同一设施；不能要求用户反复解锁不同 agent。
- 只有尚未建立免密 SSH、钥匙串/agent 不可用、需要交互式 sudo，或用户明确要求手动操作时，才继续交给用户，并说明具体原因。

## vmrun 与 SSH 服务边界

- 仅有 vmrun 密码认证且尚未建立 SSH 时，把 `scripts/run-guest-local.zsh` 交给用户本机执行。该启动器在非交互终端拒绝执行，不读取密码变量，并禁止 `-gu`、`-gp`、`-vp` 参数。
- 不要用 `vmrun` 把 Base64 密码传给 `sudo -S` 安装或启动 SSH。
- 如果 SSH 服务缺失，先展示命令并取得确认，再让用户在虚拟机终端自行执行并输入 sudo 密码：

```bash
sudo apt-get update
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
```

- 写入 `authorized_keys`、修改 `$HOME` 或 `.ssh` 权限均属于状态变更；必须展示确切命令并获得确认。避免无必要地修改 `$HOME` 权限。

## 完整案例暴露的错误模式

- 在聊天中要求用户提供密码、临时密码或私钥口令。
- Agent 直接运行会触发交互式凭据提示的 `vmrun`。
- 用 `VM_PASS_B64` 封装密码后传给 `vmrun` 和 `sudo -S`。
- 未确认真实 guest 用户名就反复尝试 SSH。
- 假定默认公钥存在；生成带口令密钥后却没有配置钥匙串。
- 用户解锁默认 agent 后，又要求解锁任务专用 agent。
- 把一次性部署路径、公钥和私钥位置固化为通用技能内容。
