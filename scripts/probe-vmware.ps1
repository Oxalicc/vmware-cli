param([switch]$ListAll)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Find-Tool($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($dir in @("$env:ProgramFiles\VMware\VMware Workstation", "${env:ProgramFiles(x86)}\VMware\VMware Workstation")) {
        $p = Join-Path $dir $name
        if (Test-Path $p) { return $p }
    }
    return $null
}

Write-Output "== VMware 工具链 =="
$vmrun = Find-Tool 'vmrun.exe'
$vmcli = Find-Tool 'vmcli.exe'
$vdisk = Find-Tool 'vmware-vdiskmanager.exe'
foreach ($t in @(@('vmrun', $vmrun), @('vmcli', $vmcli), @('vmware-vdiskmanager', $vdisk))) {
    $ver = ''
    if ($t[1]) { $ver = "  (" + (((& $t[1] -v 2>&1) | Where-Object { $_ -match 'version|build' } | Select-Object -First 1) -replace '\s+$', '') + ")" }
    Write-Output ("{0,-22} {1}{2}" -f $t[0], $(if ($t[1]) { $t[1] } else { '未安装' }), $ver)
}

$powercli = Get-Module -ListAvailable VMware.PowerCLI | Select-Object -First 1
Write-Output ("{0,-22} {1}" -f 'VMware.PowerCLI', $(if ($powercli) { "已安装 v$($powercli.Version)" } else { '未安装 (Install-Module VMware.PowerCLI)' }))

$esxcli = Find-Tool 'esxcli.exe'
Write-Output ("{0,-22} {1}" -f 'esxcli (vCLI)', $(if ($esxcli) { $esxcli } else { '未安装 (ESXi 通过 ssh 使用主机自带 esxcli)' }))

Write-Output "`n== 本地 Workstation 虚拟机 =="
if ($vmrun) {
    $running = (& $vmrun -T ws list 2>&1 | Select-Object -Skip 1) | Where-Object { $_ -match '\.vmx' }
    Write-Output "运行中 ($($running.Count)):"
    if ($running) { $running | ForEach-Object { Write-Output "  $_" } } else { Write-Output "  (无)" }

    $searchRoots = @("$env:USERPROFILE\Documents\Virtual Machines", "$env:PUBLIC\Documents\Shared Virtual Machines") | Where-Object { Test-Path $_ }
    $vmxFiles = @()
    foreach ($root in $searchRoots) {
        $vmxFiles += Get-ChildItem -Path $root -Filter *.vmx -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -eq '.vmx' } | Select-Object -ExpandProperty FullName
    }
    Write-Output "已发现 .vmx ($($vmxFiles.Count)):"
    if ($vmxFiles) {
        if (-not $ListAll -and $vmxFiles.Count -gt 20) {
            $vmxFiles | Select-Object -First 20 | ForEach-Object { Write-Output "  $_" }
            Write-Output "  ... 共 $($vmxFiles.Count) 台，用 -ListAll 查看全部"
        } else {
            $vmxFiles | ForEach-Object { Write-Output "  $_" }
        }
    } else {
        Write-Output "  (未在默认目录发现，可用 Get-ChildItem -Filter *.vmx -Recurse <目录> 搜索)"
    }
} else {
    Write-Output "未找到 vmrun，跳过"
}
