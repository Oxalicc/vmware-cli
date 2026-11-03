---
name: vmware-cli
description: VMware 命令行操作指南，覆盖 VMware Workstation/Fusion（vmrun / vmcli / vmware-vdiskmanager）、ESXi（esxcli / vim-cmd）、vSphere PowerCLI。当用户要启动/停止/重置/挂起虚拟机、做快照或克隆、管理虚拟磁盘、在客户机内执行命令或传文件、修改 .vmx 配置、连接 vCenter/ESXi 管理虚拟机，或提到 vmrun、vmcli、esxcli、vim-cmd、PowerCLI、Connect-VIServer 时使用。
---

# VMware 命令行

## Overview

按目标环境选择正确的 VMware 命令行工具链（Workstation/Fusion 本地、ESXi 主机或 vSphere PowerCLI），并给出准确调用方式与常见陷阱。先读取本文件完成选型，再按需读取对应参考文件。

## 第一步：探测环境

先确认目标环境和可用工具，再选工具链。探测脚本只读取环境，不修改虚拟机：

```bash
# macOS / Linux
bash <skill目录>/scripts/probe-vmware.sh

# Windows PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File <skill目录>/scripts/probe-vmware.ps1
```

脚本输出本机工具路径、运行中和默认目录下的虚拟机，以及 PowerCLI 状态。若脚本缺失或结果不全，手工确认：
- Fusion：`/Applications/VMware Fusion.app/Contents/Public/vmrun`，使用 `-T fusion`
- Workstation：默认在 `C:\Program Files\VMware\VMware Workstation\`，使用 `-T ws`
- `Get-Module -ListAvailable VMware.PowerCLI` 判断 PowerCLI
- `ssh root@<esxi-host> "esxcli system version get"` 判断 ESXi

不要凭记忆假定工具已加入 PATH；优先使用探测到的绝对路径。

## 工具选型

| 场景 | 工具 |
|---|---|
| 本机 Workstation/Fusion 虚拟机电源、快照、克隆、客户机文件/程序 | `vmrun` |
| 本机 Workstation/Fusion 虚拟硬件/磁盘/键鼠屏幕/模板等细粒度操作 | `vmcli` |
| 离线虚拟磁盘创建、扩容、压缩、转换、克隆 | `vmware-vdiskmanager` |
| ESXi 主机直接管理（SSH 登录后） | `esxcli` / `vim-cmd` |
| vCenter/ESXi 批量管理、模板、迁移、报表 | PowerCLI（PowerShell） |

命令详情见：
- `references/workstation.md` — vmrun、vmcli、vmware-vdiskmanager、vmx 配置
- `references/esxi.md` — esxcli、vim-cmd
- `references/powercli.md` — PowerCLI cmdlet

## 通用准则

1. **定位 .vmx**：Workstation/Fusion 工具以 `.vmx` 全路径为标识。用 `vmrun list` 或探测脚本获取；`vmrun list` 只显示运行中的虚拟机，不等同于完整清单。
2. **先探测再动手**：确认主机类型、工具路径、目标 `.vmx` 和当前状态。版本参数可能不同，以本机 `vmrun`、`vmcli ... --help` 输出为准。
3. **客户机操作前置条件**：guest 命令要求客户机已开机、VMware Tools 正常；先运行 `checkToolsState`。认证必须遵循下方“安全凭据流程”。
4. **只读操作可直接执行**：`list`、`listSnapshots`、`checkToolsState`、`getGuestIPAddress` 和配置查询等不修改状态。
5. **破坏性操作必须确认**：硬关机/重置、删除虚拟机或快照、恢复快照、删除/覆盖文件、修改硬件/网络/磁盘前，展示确切命令并等待用户明确确认；建议先创建快照。不要自动用 `hard` 替代失败的 `soft`。
6. **软硬两种方式**：电源操作优先 `soft`；只有用户确认后才使用 `hard`。
7. **加密虚拟机**：需要 `-vp` 时同样使用安全凭据流程，不得在 Agent 工具命令中填入真实密码。
8. **输出量控制**：`vim-cmd vmsvc/getallvms`、`esxcli ... list` 在大型环境输出很长，先过滤或限定数量。

## 安全凭据流程

- 不得在对话中索取、接收或复述真实密码、令牌、私钥内容或私钥口令；不得把它们写入回复、日志、脚本或持久化文件。用户名、主机地址、Host 别名和密钥路径属于非敏感连接配置，可以保存和复用。
- 不得在 Agent 工具会话中执行可能显示 `Guest user:`、`Guest password:` 等提示的命令，也不得无凭据试探客户机登录。不得用 Base64、变量拼接或 `sudo -S` 传递密码。
- **macOS 一次设置**：把 `scripts/setup-ssh-macos.zsh` 交给用户在本机终端运行。脚本复用或创建专用密钥、执行一次 `ssh-copy-id`、用 `ssh-add --apple-use-keychain` 保存私钥口令，并生成 `~/.ssh/vmware-cli/<别名>.conf`。Agent 不代跑初始授权。
- **不要重复解锁**：不要为单次任务创建专用 `SSH_AUTH_SOCK`，不要让用户先解锁默认 agent、又解锁另一个 agent。macOS 使用钥匙串和持久 SSH 配置；其他平台使用用户已有的持久 ssh-agent 或等价系统凭据设施。
- **授权后接手**：先用同一配置从 Agent 环境验证非交互连接。成功后，后续只读命令默认由 Agent 执行；修改类命令展示范围并经确认后，也由 Agent 执行，不得再次委托给用户。
- Agent 不得读取、复制、上传或输出私钥内容。使用配置中的 `IdentitiesOnly=yes` 和 `BatchMode=yes`，禁止密码提示。
- 只有尚未建立免密 SSH、系统钥匙串/agent 不可用、需要交互式 sudo 密码，或用户明确要求手动操作时，才交给用户本机执行，并说明具体原因。不要自制“加密密码文件”代替系统钥匙串。

macOS 初始设置（用户本机终端执行一次）：

```zsh
zsh <skill目录>/scripts/setup-ssh-macos.zsh <guest-user>@<guest-ip> <别名>
```

授权后由 Agent 执行：

```bash
ssh -F "$HOME/.ssh/vmware-cli/<别名>.conf" -o BatchMode=yes <别名> \
  'df -h /; du -sh /var/cache/apt "$HOME/.cache" 2>/dev/null'
```

完整流程、钥匙串边界、sudo 边界和反例见 `references/guest-credentials.md`。

## 典型流程示例

Fusion 上查看运行中的虚拟机、创建快照并启动：

```bash
VMRUN="/Applications/VMware Fusion.app/Contents/Public/vmrun"
VMX="/Users/me/Virtual Machines.localized/lab.vmwarevm/lab.vmx"
"$VMRUN" -T fusion list
"$VMRUN" -T fusion snapshot "$VMX" pre-change
"$VMRUN" -T fusion start "$VMX" nogui
```

Workstation 上克隆一台测试机并启动：

```bash
VMRUN="/c/Program Files/VMware/VMware Workstation/vmrun.exe"
"$VMRUN" -T ws snapshot "C:/Users/me/Documents/Virtual Machines/lab/lab.vmx" pre-clone
"$VMRUN" -T ws clone "C:/Users/me/Documents/Virtual Machines/lab/lab.vmx" \
  "C:/Users/me/Documents/Virtual Machines/lab-clone/lab-clone.vmx" full -cloneName=clone-1
"$VMRUN" -T ws start "C:/Users/me/Documents/Virtual Machines/lab-clone/lab-clone.vmx" gui
```

客户机操作先由 Agent 检查 Tools；初始认证按“安全凭据流程”处理，免密 SSH 建立后由 Agent 接手后续命令：

```bash
"$VMRUN" -T ws checkToolsState "D:/vm/x.vmx"
```

ESXi 上找到并强制关掉一台卡死的虚拟机（`kill` 前必须获得明确确认）：

```bash
ssh root@esxi01 "vim-cmd vmsvc/getallvms | grep stuck-vm"
ssh root@esxi01 "esxcli vm process list | grep -B1 -A5 stuck-vm"
ssh root@esxi01 "esxcli vm process kill --type=hard --world-id=<wid>"
```

## Resources

- `scripts/probe-vmware.sh` — macOS/Linux 环境探测与本地虚拟机清单，`--list-all` 显示全部
- `scripts/probe-vmware.ps1` — Windows 环境探测与本地虚拟机清单，`-ListAll` 显示全部
- `scripts/run-guest-local.zsh` — 仅供用户本机终端运行的安全 guest 命令启动器
- `scripts/setup-ssh-macos.zsh` — macOS 一次性 SSH 密钥、钥匙串与持久配置设置，仅供用户本机终端运行
- `references/workstation.md` — Workstation/Fusion 全命令速查
- `references/guest-credentials.md` — 客户机认证、SSH 引导与完整反例
- `references/esxi.md` — ESXi 主机命令速查
- `references/powercli.md` — PowerCLI 速查
