# vmware-cli

一个 Qoder / Claude / Kimi 风格的 **Agent Skill**：让 AI 助手准确操作 VMware 命令行，完整覆盖四套工具链。

- **VMware Workstation / Fusion** — `vmrun`、`vmcli`、`vmware-vdiskmanager`
- **ESXi 主机** — `esxcli`、`vim-cmd`
- **vSphere** — PowerCLI

本版本基于 [LiaoZiqi-GZFLS/qoder-skill-vmware-cli](https://github.com/LiaoZiqi-GZFLS/qoder-skill-vmware-cli) 改造，保留原工具链与 MIT 许可证，新增 macOS Fusion 支持并强化危险操作确认规则。

## 解决什么问题

AI 助手凭记忆写 VMware 命令时，常见错误包括：Workstation/Fusion 工具不在 PATH、`vmcli` 的模块名大小写敏感、guest 操作忘了 VMware Tools 与凭据的前提、路径未正确引用，以及混淆优雅关机、强制断电和删除操作。

本技能提供命令速查、工具选型表与安全准则，并附带 Windows、macOS/Linux 环境探测脚本。

## 安装

把仓库内容放入技能的搜索目录，目录名保持 `vmware-cli`，然后重载技能。描述中已包含触发词，提到 `vmrun`、`vmcli`、`esxcli` 或 PowerCLI 时可自动选用。

## 环境探测

```bash
# macOS / Linux（默认最多显示 20 台，--list-all 显示全部）
bash scripts/probe-vmware.sh

# Windows PowerShell（-ListAll 显示全部）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/probe-vmware.ps1
```

输出已安装的本地 VMware 工具、PowerCLI 状态、运行中虚拟机，以及默认目录下的 `.vmx` 清单。探测过程不修改虚拟机。

## 结构

```
SKILL.md                    技能入口：工具选型、通用准则、端到端示例
references/workstation.md   vmrun / vmcli 模块表 / vdiskmanager / .vmx 配置
references/esxi.md          vim-cmd 虚拟机与快照、esxcli 进程/网络/存储
references/powercli.md      连接、生命周期、快照克隆、Invoke-VMScript
scripts/probe-vmware.sh     macOS/Linux 环境探测脚本
scripts/probe-vmware.ps1    Windows 环境探测脚本
```

## 注意

命令速查基于 VMware Workstation 17.6 / Fusion（vmrun 1.17 / vmcli 0.1）整理，其他版本参数可能略有差异，以本机帮助输出为准。技能按“先探测、破坏性操作前确认并建议快照”的原则编排，涉及真实生产虚拟机时必须人工确认。

## License

MIT，见 [LICENSE](LICENSE)。原版权归属与许可声明保持不变。
