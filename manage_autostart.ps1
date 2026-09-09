# ====================================================
# TraeWorkCheckin - 开机自启管理 (PowerShell 交互式)
# ====================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if (-not $scriptDir) {
    $scriptDir = (Get-Location).Path
}

function Invoke-InstallTask {
    param([bool]$interactive = $true)
    $ws = New-Object -ComObject WScript.Shell
    $s = [Environment]::GetFolderPath('Startup')
    # 先清理可能存在的旧版本快捷方式
    $oldP = Join-Path $s 'TraeWorkAutoCheckin.lnk'
    if (Test-Path $oldP) { Remove-Item $oldP -Force -ErrorAction SilentlyContinue }

    $p = Join-Path $s 'TraeWorkCheckin.lnk'
    $lnk = $ws.CreateShortcut($p)
    $lnk.TargetPath = Join-Path $scriptDir 'run_checkin.cmd'
    $lnk.Arguments = '--silent'
    $lnk.WorkingDirectory = $scriptDir
    $lnk.WindowStyle = 7
    $lnk.Save()
    Write-Host ""
    if (Test-Path $p) {
        Write-Host "[成功] 开机自动签到任务已成功安装！" -ForegroundColor Green
        Write-Host "效果：每次开机登录 Windows 桌面后，系统将自动在后台静默运行并在右下角弹出结果提醒。" -ForegroundColor Cyan
    } else {
        Write-Host "[失败] 快捷方式生成失败，请检查系统目录权限。" -ForegroundColor Red
    }
    if ($interactive) {
        Write-Host ""
        Write-Host "请按任意键返回主菜单..." -ForegroundColor Yellow
        if (-not [Console]::IsInputRedirected) {
            [Console]::ReadKey($true) > $null
        }
    }
}

function Invoke-UninstallTask {
    param([bool]$interactive = $true)
    $dir = [Environment]::GetFolderPath('Startup')
    $p = Join-Path $dir 'TraeWorkCheckin.lnk'
    $oldP = Join-Path $dir 'TraeWorkAutoCheckin.lnk'
    Write-Host ""
    $removed = $false
    if (Test-Path $p) {
        Remove-Item $p -Force
        $removed = $true
    }
    if (Test-Path $oldP) {
        Remove-Item $oldP -Force
        $removed = $true
    }
    if ($removed) {
        Write-Host "[成功] 已成功移除开机启动快捷方式！" -ForegroundColor Green
    } else {
        Write-Host "[提示] 未检测到已安装的开机启动快捷方式。" -ForegroundColor Yellow
    }
    Unregister-ScheduledTask -TaskName 'TraeWorkCheckin' -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName 'TraeWorkAutoCheckin' -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "[完成] 开机自启配置已全部清理干净。" -ForegroundColor Green
    if ($interactive) {
        Write-Host ""
        Write-Host "请按任意键返回主菜单..." -ForegroundColor Yellow
        if (-not [Console]::IsInputRedirected) {
            [Console]::ReadKey($true) > $null
        }
    }
}

function Invoke-RunCheckin {
    param([bool]$interactive = $true)
    Write-Host ""
    Write-Host "[启动] 正在调用签到执行器..." -ForegroundColor Cyan
    & (Join-Path $scriptDir "run_checkin.cmd")
    if ($interactive) {
        Write-Host ""
        Write-Host "请按任意键返回主菜单..." -ForegroundColor Yellow
        if (-not [Console]::IsInputRedirected) {
            [Console]::ReadKey($true) > $null
        }
    }
}

# 命令行非交互式参数处理
$firstArg = $args[0]
if ($firstArg -in @('--install', '-i', 'install')) {
    Invoke-InstallTask -interactive $false
    exit 0
}
if ($firstArg -in @('--uninstall', '-u', 'uninstall')) {
    Invoke-UninstallTask -interactive $false
    exit 0
}
if ($firstArg -in @('--run', '-r', 'run')) {
    Invoke-RunCheckin -interactive $false
    exit 0
}

# 菜单选项定义
$options = @(
    @{ Text = "安装开机自启任务 (开机登录桌面后后台静默签到并弹窗通知)"; Action = "install" },
    @{ Text = "卸载开机自启任务 (彻底移除已配置的开机自启启动项)"; Action = "uninstall" },
    @{ Text = "立即测试执行签到 (查看当前运行效果与实时控制台输出)"; Action = "run" },
    @{ Text = "退出管理程序"; Action = "exit" }
)

function Render-Menu {
    param([int]$curIndex)
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "         TraeWorkCheckin - 开机自启管理" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  提示：使用键盘 [↑ / ↓] 键移动光标，按 [Enter] 确认选择" -ForegroundColor DarkGray
    Write-Host "        亦可直接按下对应数字键 [1 / 2 / 3 / 0] 快速选择" -ForegroundColor DarkGray
    Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    for ($i = 0; $i -lt $options.Count; $i++) {
        $keyHint = if ($i -eq $options.Count - 1) { "0" } else { "$($i + 1)" }
        if ($i -eq $curIndex) {
            Write-Host " ▶ " -ForegroundColor Green -NoNewline
            Write-Host "[$keyHint] " -ForegroundColor Green -NoNewline
            Write-Host "$($options[$i].Text)" -ForegroundColor Green
        } else {
            Write-Host "   " -NoNewline
            Write-Host "[$keyHint] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($options[$i].Text)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
}

# 交互式键盘监听循环
$selectedIndex = 0

if ([Console]::IsInputRedirected) {
    Write-Host "[提示] 检测到重定向非交互环境，如需操作请传入参数：--install 或 --uninstall" -ForegroundColor Yellow
    exit 0
}

while ($true) {
    Render-Menu -curIndex $selectedIndex
    $keyInfo = [Console]::ReadKey($true)

    switch ($keyInfo.Key) {
        ([ConsoleKey]::UpArrow) {
            $selectedIndex = ($selectedIndex - 1 + $options.Count) % $options.Count
        }
        ([ConsoleKey]::DownArrow) {
            $selectedIndex = ($selectedIndex + 1) % $options.Count
        }
        ([ConsoleKey]::Enter) {
            $act = $options[$selectedIndex].Action
            if ($act -eq "install") { Invoke-InstallTask -interactive $true }
            elseif ($act -eq "uninstall") { Invoke-UninstallTask -interactive $true }
            elseif ($act -eq "run") { Invoke-RunCheckin -interactive $true }
            elseif ($act -eq "exit") {
                Write-Host ""
                Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
                exit 0
            }
        }
        ([ConsoleKey]::D1) { Invoke-InstallTask -interactive $true }
        ([ConsoleKey]::NumPad1) { Invoke-InstallTask -interactive $true }
        ([ConsoleKey]::D2) { Invoke-UninstallTask -interactive $true }
        ([ConsoleKey]::NumPad2) { Invoke-UninstallTask -interactive $true }
        ([ConsoleKey]::D3) { Invoke-RunCheckin -interactive $true }
        ([ConsoleKey]::NumPad3) { Invoke-RunCheckin -interactive $true }
        ([ConsoleKey]::D0) {
            Write-Host ""
            Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
            exit 0
        }
        ([ConsoleKey]::NumPad0) {
            Write-Host ""
            Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
            exit 0
        }
        ([ConsoleKey]::Escape) {
            Write-Host ""
            Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
            exit 0
        }
        ([ConsoleKey]::Q) {
            Write-Host ""
            Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
            exit 0
        }
    }
}