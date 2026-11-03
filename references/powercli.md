# vSphere PowerCLI 速查

PowerShell 模块，管理 vCenter / ESXi（远程 API，不需要 SSH）。

## 安装与连接

```powershell
Install-Module VMware.PowerCLI -Scope CurrentUser
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false   # 自签名证书
Connect-VIServer -Server <vcenter或esxi> -User <user> -Password <pass>      # 也可省略密码交互输入
Get-VMHost | Select Name, ConnectionState
```

## 虚拟机生命周期

```powershell
Get-VM                                  # 全部 VM；加 -Name "win-*" 过滤
Get-VM web-01 | Select Name, PowerState, NumCpu, MemoryGB, @{n='IP';e={$_.Guest.IPAddress}}
Start-VM web-01 ; Stop-VMGuest web-01 -Confirm:$false  # 启动 / 优雅关闭客户机（需 Tools）
Stop-VM web-01                             # 关闭虚拟机电源，执行前确认
Stop-VM web-01 -Kill                       # 强制终止，破坏性操作，必须明确确认
Suspend-VM web-01 ; Restart-VMGuest web-01              # 挂起 / 重启客户机
New-VM -Name lab-01 -VMTemplate tmpl-ubuntu22 -Datastore ds1 -VMHost esxi01
New-VM -Name lab-01 -VMHost esxi01 -DiskGB 40 -MemoryGB 4 -NumCpu 2 -NetworkName "VM Network"
```

## 快照与克隆

```powershell
New-Snapshot -VM web-01 -Name pre-upgrade -Description "升级前" -Memory:$false -Quiesce:$true
Get-Snapshot -VM web-01 | Select Name, Created
Set-VM -VM web-01 -Snapshot (Get-Snapshot -VM web-01 -Name pre-upgrade)   # 回滚到该快照
Remove-Snapshot -Snapshot (Get-Snapshot -VM web-01 -Name old) -Confirm:$false
New-VM -Name web-01-clone -VM web-01 -Location (Get-Folder Lab) -Datastore ds1   # 克隆
```

## 客户机操作（需 VMware Tools + 凭据）

```powershell
$cred = Get-Credential                      # 客户机账号
Invoke-VMScript -VM web-01 -ScriptType Bash -ScriptText "uname -a" -GuestCredential $cred
Copy-VMGuestFile -Source ./pkg.tgz -Destination /tmp/pkg.tgz -VM web-01 -GuestCredential $cred -LocalToGuest
Copy-VMGuestFile -Source /var/log/app.log -Destination ./app.log -VM web-01 -GuestCredential $cred -GuestToLocal
Get-VMGuest -VM web-01 | Select VmName, State, HostName, IPAddress
```

## 资源与配置

```powershell
Set-VM -VM web-01 -NumCpu 4 -MemoryGB 8 -Confirm:$false
Get-Datastore ds1 | Select Name, FreeSpaceGB, CapacityGB
Get-VMHost esxi01 | Get-VM | Where-Object {$_.PowerState -eq 'PoweredOn'} | Measure-Object
New-HardDisk -VM web-01 -CapacityGB 50 -StorageFormat Thin
Set-NetworkAdapter -NetworkAdapter (Get-NetworkAdapter -VM web-01) -NetworkName "DMZ"
```

## 批量与报表

```powershell
Get-VM | Where-Object {$_.MemoryGB -lt 4} | Select Name, MemoryGB, PowerState
Get-VM | ForEach-Object { New-Snapshot -VM $_ -Name "bulk-$(Get-Date -f yyyyMMdd)" }
Get-View -ViewType VirtualMachine -Filter @{"Name"="web-*"} | Select Name, Config.Uuid
```

## 陷阱

- 断开：`Disconnect-VIServer * -Confirm:$false`；脚本开头连接、结尾断开。
- 大环境 `Get-VM` 很慢，尽量用 `-Name`/`-Location` 限定或 `Get-View` 过滤。
- `Stop-VMGuest` 才是客户机优雅关机；`Stop-VM` 会关闭虚拟机电源，`-Kill` 是更激进的强制终止，执行前必须确认。
- 修改 CPU/内存（`Set-VM`）多数需要关机或热插拔支持，先确认再执行。
- 客户机文件操作依赖 VMware Tools 正常运行，失败先 `Get-VMGuest` 看 State。
