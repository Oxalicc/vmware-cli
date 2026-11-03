# 客户机认证与 SSH 引导安全指引

## 强制边界

1. Agent 不得在对话中索取或接收真实用户名、密码、令牌、私钥，也不得代跑包含这些信息的脚本。
2. Agent 只能先执行只读的 `checkToolsState`；不得通过无凭据 guest 命令试探认证，因为 `vmrun` 可能显示 `Guest user:` / `Guest password:`。
3. 需要认证时，把 `scripts/run-guest-local.zsh` 的确切调用交给用户。该启动器在非交互终端拒绝执行，不读取密码变量，并禁止 `-gu`、`-gp`、`-vp` 参数；`vmrun` 只在用户终端提示凭据。
4. 不得用 Base64、十六进制或变量拼接“隐藏”密码；这些都不是加密。禁止 `VM_PASS_B64`、`echo "$PASS" | sudo -S` 及同类做法。
5. 不得把真实密钥、用户路径或部署专用公钥写入通用技能。公钥可以交给用户，但模板必须使用占位符；私钥始终留在用户本机。

## 标准客户机命令流程

1. 用只读命令确认 `.vmx`、电源状态、VMware Tools 和 IP。
2. 说明将执行的客户机命令及其修改范围；涉及安装软件、写文件、改权限或启动服务时，先取得明确确认。
3. 给用户以下本机终端命令，不要由 Agent 执行：

```zsh
zsh <skill目录>/scripts/run-guest-local.zsh \
  "/path/to/vm.vmx" runProgramInGuest /bin/true
```

4. 用户只需回复成功或失败，以及可公开的错误文本；不要发送密码。需要用户名时，可让用户在虚拟机终端运行 `whoami`。主机名不等于 SSH 用户名。

## SSH 密钥引导

优先使用系统自带工具，让密码提示留在用户终端：

```zsh
ssh-copy-id -i "/path/to/public-key.pub" <guest-user>@<guest-ip>
```

- `ssh-copy-id` 只读取公钥；密码由用户在本机终端输入，不要通过 Agent 转交。
- 不要用 `vmrun` 把 Base64 密码传给 `sudo -S` 安装或启动 SSH。
- 如果 SSH 服务缺失，先展示命令并取得确认，再让用户在虚拟机终端自行执行并输入 sudo 密码：

```bash
sudo apt-get update
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
```

- 写入 `authorized_keys`、修改 `$HOME` 或 `.ssh` 权限均属于状态变更；必须展示确切命令并获得确认。避免无必要地修改 `$HOME` 权限。
- 连接时明确使用 `ssh <guest-user>@<guest-ip>`，不要依赖宿主机当前用户名作为默认值。

## 完整案例暴露的错误模式

- 在聊天中要求用户提供用户名和临时密码。
- Agent 直接运行会触发交互式凭据提示的 `vmrun`。
- 用 `VM_PASS_B64` 封装密码后传给 `vmrun` 和 `sudo -S`。
- 未确认真实 guest 用户名就反复尝试 SSH。
- 把一次性部署路径、公钥和私钥位置固化为通用技能内容。
