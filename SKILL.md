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
3. **客户机操作前置条件**：guest 命令要求客户机已开机、VMware Tools 正常，并提供 `-gu`/`-gp`（vmcli 用对应选项）凭据；先运行 `checkToolsState`。不要把真实密码写入回复、日志或持久化文件。
4. **只读操作可直接执行**：`list`、`listSnapshots`、`checkToolsState`、`getGuestIPAddress` 和配置查询等不修改状态。
5. **破坏性操作必须确认**：硬关机/重置、删除虚拟机或快照、恢复快照、删除/覆盖文件、修改硬件/网络/磁盘前，展示确切命令并等待用户明确确认；建议先创建快照。不要自动用 `hard` 替代失败的 `soft`。
6. **软硬两种方式**：电源操作优先 `soft`；只有用户确认后才使用 `hard`。
7. **加密虚拟机**：vmrun 需要 `-vp <密码>`；凭据仅作为当次命令参数使用，不回显。
8. **输出量控制**：`vim-cmd vmsvc/getallvms`、`esxcli ... list` 在大型环境输出很长，先过滤或限定数量。

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

在客户机内执行命令并取回结果（先检查 Tools；示例密码不是真实凭据）：

```bash
"$VMRUN" -T ws checkToolsState "D:/vm/x.vmx"
"$VMRUN" -T ws -gu user -gp 'pass' runProgramInGuest "D:/vm/x.vmx" /bin/sh -c "uname -a > /tmp/out.txt"
"$VMRUN" -T ws -gu user -gp 'pass' copyFileFromGuestToHost "D:/vm/x.vmx" /tmp/out.txt ./out.txt
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
- `references/workstation.md` — Workstation/Fusion 全命令速查
- `references/esxi.md` — ESXi 主机命令速查
- `references/powercli.md` — PowerCLI 速查
