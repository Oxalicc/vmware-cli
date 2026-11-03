# Workstation / Fusion 命令行速查（vmrun / vmcli / vmware-vdiskmanager）

默认安装位置（通常不在 PATH，优先写全路径）：

| 平台 | 工具路径 |
|---|---|
| macOS Fusion | `/Applications/VMware Fusion.app/Contents/Public/vmrun` |
| macOS Fusion | `/Applications/VMware Fusion.app/Contents/Public/vmcli` |
| macOS Fusion | `/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager` |
| Windows Workstation | `C:\Program Files\VMware\VMware Workstation\vmrun.exe`（其他工具同目录） |

## vmrun

通用调用：`vmrun [AUTHENTICATION-FLAGS] COMMAND [PARAMETERS]`

认证/全局参数（必须放在命令之前）：
- `-T <hostType>` — `ws`（Workstation）/ `fusion`（Fusion）/ `player`（Player，视版本支持）
- `-vp <password>` — 加密虚拟机的解密密码
- `-gu <user>` / `-gp <password>` — 客户机凭据（guest 文件、程序和进程操作需要，且客户机已装 VMware Tools）

**安全要求**：Agent 不得在对话中索取真实密码或私钥口令，不得在工具会话中触发 `Guest user:` / `Guest password:` 提示，也不得把真实密码放入 `-gp` / `-vp` 命令。禁止用 Base64 或 `sudo -S` 间接传密码。初始 vmrun 认证按 `SKILL.md` 交给用户本机执行；macOS 优先用 `scripts/setup-ssh-macos.zsh` 完成一次密钥与钥匙串设置，不要创建任务专用 `SSH_AUTH_SOCK` 或重复 `ssh-add`。免密 SSH 建立后，后续只读命令默认由 Agent 接手，修改类命令经确认后由 Agent 执行，不得重复委托用户。

电源命令：`start <vmx> [gui|nogui]`、`stop <vmx> [hard|soft]`、`reset <vmx> [hard|soft]`、
`suspend <vmx> [hard|soft]`、`pause <vmx>`、`unpause <vmx>`

快照/克隆命令：
- `snapshot <vmx> <name>` — 创建快照
- `listSnapshots <vmx> [showTree]`、`revertToSnapshot <vmx> <name>`、`deleteSnapshot <vmx> <name> [andDeleteChildren]`
- `clone <vmx> <dest.vmx> full|linked [-snapshot=<name>] [-cloneName=<name>]` — 完整/链接克隆；链接克隆通常需要 `-snapshot`

列举与状态：
- `list` — 只列出正在运行的虚拟机
- `listProcessesInGuest <vmx>`、`checkToolsState <vmx>`、`getGuestIPAddress <vmx> [-wait]`
- `readVariable <vmx> [runtimeConfig|guestEnv|guestVar] <name>`、`writeVariable <vmx> [runtimeConfig|guestEnv|guestVar] <name> <value>`
- `captureScreen <vmx> <host路径.png>` — 截客户机屏幕

客户机操作（文件、目录、程序和进程操作都需要 `-gu`/`-gp`）：
- `copyFileFromHostToGuest <vmx> <host路径> <guest路径>`、`copyFileFromGuestToHost <vmx> <guest路径> <host路径>`
- `fileExistsInGuest`、`directoryExistsInGuest`、`listDirectoryInGuest`、`createDirectoryInGuest`
- `deleteFileInGuest`、`deleteDirectoryInGuest`、`renameFileInGuest`、`createTempfileInGuest`、`listProcessesInGuest`、`killProcessInGuest`
- `runProgramInGuest <vmx> [-noWait] [-activeWindow] [-interactive] <program路径> [args...]`
- `runScriptInGuest <vmx> [-noWait] [-activeWindow] [-interactive] <解释器路径> <脚本文本>`
- `killProcessInGuest <vmx> <pid>`

共享文件夹、设备与网络：
- `enableSharedFolders` / `disableSharedFolders`、`addSharedFolder` / `removeSharedFolder`、`setSharedFolderState`
- `connectNamedDevice` / `disconnectNamedDevice`
- `listHostNetworks`、`listPortForwardings`、`setPortForwarding`、`deletePortForwarding`
- `listNetworkAdapters`、`addNetworkAdapter`、`setNetworkAdapter`、`deleteNetworkAdapter`

其他：`installTools`、`upgradevm`、`deleteVM`。删除、覆盖、硬重置、网络和磁盘变更前必须确认。

常见陷阱：
- 始终给含空格的路径加引号。Windows 参数建议用 `C:/vm/x.vmx`，避免 Git Bash 吞掉反斜杠。
- macOS 的 `.vmwarevm` 是虚拟机包，vmrun 需要包内实际的 `.vmx` 文件路径。
- `runProgramInGuest` 默认等待结束；要后台运行加 `-noWait`。
- 有交互界面的程序在客户机里跑需要 `-activeWindow` 或 `-interactive`。
- 不同版本支持的命令和选项有差异，以本机无参数运行 `vmrun` 所得帮助为准。

## vmcli（Workstation 17.6+ / Fusion 13.6+）

通用调用：`vmcli <vmx路径> <Module> <command> [选项]`（Windows 为 `vmcli.exe`，vmx 也可放最后）。
每个子命令用 `vmcli <Module> <command> --help` 查看其选项。

| Module | 用途 | 常用命令 |
|---|---|---|
| Power | 电源状态 | `query`、`Start`、`Stop`、`Pause`、`Unpause`、`Reset`、`Suspend` |
| Guest | 客户机操作（需 Tools + 凭据） | `run`、`copyTo`、`copyFrom`、`ls`、`ps`、`kill`、`mkdir`、`rm`、`mv`、`env`、`query`、`toolsproperties` |
| Disk | 虚拟磁盘 | `Create`、`Extend`、`query`、`Move`、`SetReadOnly`、`SetMode`、`ConvertAllocType` |
| MKS | 键鼠与屏幕 | `captureScreenshot`、`sendKeyEvent`、`sendKeySequence`、`SetGuestResolution`、`SetVramSize` |
| Snapshot | 快照 | 见 `vmcli Snapshot --help` |
| ConfigParams | 读写 .vmx 配置 | `query`、`SetEntry <key> <value>` |
| VM | 虚拟机操作 | 见 `vmcli VM --help` |
| VMTemplate | 模板 | 创建/部署虚拟机模板 |
| Ethernet / Sata / Nvme / Serial / Chipset / HGFS / Tools / VProbes | 对应虚拟硬件配置 | 见各自 `--help` |

注意：
- 模块名/命令名区分大小写（`Power Start` 不是 `power start`）。
- vmcli 直接操作指定 .vmx，适合脚本化做硬件配置与批量快照；简单电源/克隆用 vmrun 更短。
- `Disk Extend` 等改变磁盘布局的操作先做快照并确认 VM 关机。

## vmware-vdiskmanager

离线操作 vmdk：`vmware-vdiskmanager OPTIONS <disk-name>`（Windows 为 `vmware-vdiskmanager.exe`）

- `-c` 创建（配合 `-s <大小>`、`-t <0|1|2>`：0 单文件、1 可增长分片、2 固定分片）
- `-x <新容量>` 扩容（如 `-x 80GB`）
- `-k` 收缩（需客户机先做 shrink prepare `-p`）
- `-d` 碎片整理
- `-r <源> -t <类型>` 转换格式
- `-n <源> -t <类型>` 重命名/克隆磁盘文件
- `-R` 一致性检查修复、`-F` 修复磁盘链

要求：磁盘未被虚拟机占用（关机状态）；只有本地磁盘支持创建/扩容/收缩。操作前确认并建议备份。

## .vmx 配置

- 查看/修改单项：`vmcli <vmx> ConfigParams query` / `SetEntry <key> <value>`；或直接文本编辑 .vmx（VM 关机时）。
- 常用键：`memsize`、`numvcpus`、`ethernet0.connectionType`（nat/bridged/hostonly）、
  `guestOS`、`vhv.enable`（嵌套虚拟化）、`gui.exitOnPowerOff`。
- 修改前备份 `.vmx`；改完用 `vmcli <vmx> Power query` 确认状态，再启动。
