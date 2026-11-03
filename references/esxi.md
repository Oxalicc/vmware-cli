# ESXi 主机命令速查（esxcli / vim-cmd）

前提：SSH 登录 ESXi（`ssh root@<host>`；网页 Client → 主机 → 操作 → 服务 → 启用 SSH）。
注意：Shell 中路径/引号规则与本地不同，复杂命令建议先在主机上单独执行验证。

## 虚拟机管理（vim-cmd）

- `vim-cmd vmsvc/getallvms` — 列出所有虚拟机（含 Vmid、名称、路径）
- `vim-cmd vmsvc/power.getstate <vmid>` / `power.on` / `power.off` / `power.reboot` / `power.reset`
- `vim-cmd vmsvc/snapshot.create <vmid> <名称> <描述> <内存? 0|1> <quiesce? 0|1>`
- `vim-cmd vmsvc/snapshot.get <vmid>` / `snapshot.remove <vmid> <snapshotId>` / `snapshot.revert <vmid> <snapshotId>`
- `vim-cmd vmsvc/unregister <vmid>` — 仅从清单移除，保留文件；`vim-cmd vmsvc/destroy <vmid>` — 删除虚拟机及其文件，执行前必须确认
- `vim-cmd vmsvc/device.getdevices <vmid>` / `device.add` / `device.edit` — 查看/调整虚拟硬件

## 虚拟机进程（esxcli）

虚拟机卡死时按进程级别处理：

```
esxcli vm process list                      # 列出 World ID 与 VMX 路径
esxcli vm process kill --type=hard --world-id=<wid>   # hard / soft / force
```

## 主机常用（esxcli）

- 系统：`esxcli system version get`、`esxcli system hostname get`、`esxcli system maintenanceMode set --enable true|false`
- 网络：`esxcli network nic list`、`esxcli network vswitch standard list`、`esxcli network vm list`（哪个 VM 用哪个端口）
- 存储：`esxcli storage core path list`、`esxcli storage vmfs extent list`、`esxcli storage filesystem list`（挂载点含 `[datastore1]`）
- 软件与补丁：`esxcli software vib list`、`esxcli software vib update -v <vib>`
- 性能快照：`esxtop`（交互式）、`esxcli vm process list` 看内存占用

## 文件与数据存储

- 数据存储路径形如 `/vmfs/volumes/<datastore>/<vm目录>/`
- 传文件：`scp local user@esxi:/vmfs/volumes/datastore1/...`（或启用 Datastore Browser）
- 列目录：`ls /vmfs/volumes/datastore1/`（大目录加 grep）

## 旧接口

`vmware-cmd -H <host> -l` 及 `vmware-cmd <vmx> <op>` 是遗留工具，优先用 vim-cmd/esxcli。
