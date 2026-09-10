# ====================================================
# TraeWorkCheckin - 开机自启管理控制台 (PowerShell 交互式)
# ====================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $Host.UI.RawUI.WindowTitle = "TraeWorkCheckin - 开机自启管理控制台"
} catch {}

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if (-not $scriptDir) {
    $scriptDir = (Get-Location).Path
}

function Invoke-InstallTask {
    param([bool]$interactive = $true)
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "   TraeWorkCheckin - 安装开机自启任务" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[处理中] 正在配置系统启动项并清理旧任务..." -ForegroundColor DarkGray

    $ws = New-Object -ComObject WScript.Shell
    $startupDir = [Environment]::GetFolderPath('Startup')

    # 先清理可能存在的旧版本或同名快捷方式
    $lnkPath = Join-Path $startupDir 'TraeWorkCheckin.lnk'
    $oldLnkPath = Join-Path $startupDir 'TraeWorkAutoCheckin.lnk'
    if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $oldLnkPath) { Remove-Item $oldLnkPath -Force -ErrorAction SilentlyContinue }

    # 极速清理所有带有 TraeWork 字样的计划任务（采用 schtasks，毫秒级响应，杜绝卡顿）
    schtasks /Delete /TN 'TraeWorkCheckin_Retry' /F 2>$null | Out-Null
    schtasks /Delete /TN 'TraeWorkCheckin' /F 2>$null | Out-Null
    schtasks /Delete /TN 'TraeWork每日签到' /F 2>$null | Out-Null
    schtasks /Delete /TN 'TraeWorkAutoCheckin' /F 2>$null | Out-Null

    # 创建指向 run_traework_checkin.cmd 的开机快捷方式（专属命名避免启动项与其他应用重名）
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath = Join-Path $scriptDir 'run_traework_checkin.cmd'
    $lnk.Arguments = '--silent'
    $lnk.WorkingDirectory = $scriptDir
    $lnk.WindowStyle = 7 # 7 = 最小化后台静默启动
    $lnk.Description = 'TraeWork 每日自动检测签到'
    $lnk.Save()

    Write-Host ""
    if (Test-Path $lnkPath) {
        Write-Host "[成功] TraeWorkCheckin 开机自动签到任务已成功安装！" -ForegroundColor Green
        Write-Host ""
        Write-Host "运行机制与安全保障：" -ForegroundColor Cyan
        Write-Host "  1. 每次开机登录 Windows 桌面后，系统将自动在后台静默运行；" -ForegroundColor Gray
        Write-Host "  2. 自动检测今日是否已签到：若已签到秒级自动跳过，绝不重复调用接口（防风控）；" -ForegroundColor Gray
        Write-Host "  3. 若开机时尚未联网，脚本自动静默等待网络就绪并自愈恢复启动；" -ForegroundColor Gray
        Write-Host "  4. 具备三重兜底保障机制（网络故障自动注册 TraeWorkCheckin_Retry 单次重试任务）；" -ForegroundColor Gray
        Write-Host "  5. 运行完毕后，屏幕右下角自动弹出原生通知提醒，进程随即安全退出，零内存驻留。" -ForegroundColor Gray
    } else {
        Write-Host "[失败] 快捷方式生成失败，请检查启动目录权限。" -ForegroundColor Red
    }

    if ($interactive) {
        Write-Host ""
        Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "请按任意键返回主菜单..." -ForegroundColor Yellow
        try {
            while ([Console]::KeyAvailable) { [Console]::ReadKey($true) > $null }
            if (-not [Console]::IsInputRedirected) {
                [Console]::ReadKey($true) > $null
            } else {
                Read-Host "按回车键返回主菜单" > $null
            }
        } catch {
            Read-Host "按回车键返回主菜单" > $null
        }
    }
}

function Invoke-UninstallTask {
    param([bool]$interactive = $true)
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "   TraeWorkCheckin - 卸载开机自启任务" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[处理中] 正在清理启动项与计划任务..." -ForegroundColor DarkGray

    $startupDir = [Environment]::GetFolderPath('Startup')
    $lnkPath = Join-Path $startupDir 'TraeWorkCheckin.lnk'
    $oldLnkPath = Join-Path $startupDir 'TraeWorkAutoCheckin.lnk'

    $removed = $false
    if (Test-Path $lnkPath) {
        Remove-Item $lnkPath -Force -ErrorAction SilentlyContinue
        $removed = $true
    }
    if (Test-Path $oldLnkPath) {
        Remove-Item $oldLnkPath -Force -ErrorAction SilentlyContinue
        $removed = $true
    }

    # 极速清理所有带有 TraeWork 字样的计划任务与兜底重试任务（采用 schtasks，毫秒级响应）
    schtasks /Delete /TN 'TraeWorkCheckin_Retry' /F 2>$null | Out-Null
    schtasks /Delete /TN 'TraeWorkCheckin' /F 2>$null | Out-Null
    schtasks /Delete /TN 'TraeWork每日签到' /F 2>$null | Out-Null
    schtasks /Delete /TN 'TraeWorkAutoCheckin' /F 2>$null | Out-Null

    Write-Host ""
    if ($removed) {
        Write-Host "[成功] 已成功移除开机启动快捷方式！" -ForegroundColor Green
    } else {
        Write-Host "[提示] 未在系统启动目录检测到已安装的快捷方式。" -ForegroundColor Yellow
    }
    Write-Host "[完成] 开机自启配置与所有 TraeWork 计划/重试任务已全部清理干净。" -ForegroundColor Green

    if ($interactive) {
        Write-Host ""
        Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "请按任意键返回主菜单..." -ForegroundColor Yellow
        try {
            while ([Console]::KeyAvailable) { [Console]::ReadKey($true) > $null }
            if (-not [Console]::IsInputRedirected) {
                [Console]::ReadKey($true) > $null
            } else {
                Read-Host "按回车键返回主菜单" > $null
            }
        } catch {
            Read-Host "按回车键返回主菜单" > $null
        }
    }
}

function Invoke-RunCheckin {
    param([bool]$interactive = $true)
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "   TraeWorkCheckin - 立即测试执行签到" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[启动] 正在调用签到执行器..." -ForegroundColor Cyan
    Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
    & (Join-Path $scriptDir "run_traework_checkin.cmd")
    Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
    if ($interactive) {
        Write-Host ""
        Write-Host "请按任意键返回主菜单..." -ForegroundColor Yellow
        try {
            while ([Console]::KeyAvailable) { [Console]::ReadKey($true) > $null }
            if (-not [Console]::IsInputRedirected) {
                [Console]::ReadKey($true) > $null
            } else {
                Read-Host "按回车键返回主菜单" > $null
            }
        } catch {
            Read-Host "按回车键返回主菜单" > $null
        }
    }
}

# 处理命令行快速传参
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

# 交互式菜单选项定义
$options = @(
    @{ Text = "安装开机自启任务 (开机后台静默检测签到，右下角弹窗通知)"; Action = "install" },
    @{ Text = "卸载开机自启任务 (彻底移除开机自启动项与 TraeWork 兜底任务)"; Action = "uninstall" },
    @{ Text = "立即测试执行签到 (查看实时控制台输出与积分状态播报)"; Action = "run" },
    @{ Text = "退出管理程序"; Action = "exit" }
)

function Render-Menu {
    param([int]$curIndex)
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "      TraeWorkCheckin - 开机自启管理控制台" -ForegroundColor Cyan
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

# 标准文本菜单降级（用于不支持 Console.ReadKey 的终端环境）
function Show-StandardMenu {
    while ($true) {
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "      TraeWorkCheckin - 开机自启管理控制台" -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Cyan
        for ($i = 0; $i -lt $options.Count; $i++) {
            $keyHint = if ($i -eq $options.Count - 1) { "0" } else { "$($i + 1)" }
            Write-Host "  [$keyHint] $($options[$i].Text)" -ForegroundColor Gray
        }
        Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
        $choice = Read-Host "请输入数字选项 [1 / 2 / 3 / 0]"
        if ($null -eq $choice) {
            Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
            exit 0
        }
        switch ($choice.Trim()) {
            '1' { Invoke-InstallTask -interactive $true }
            '2' { Invoke-UninstallTask -interactive $true }
            '3' { Invoke-RunCheckin -interactive $true }
            '0' {
                Clear-Host
                Write-Host ""
                Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
                exit 0
            }
            'q' {
                Clear-Host
                Write-Host ""
                Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
                exit 0
            }
            default {
                Write-Host "[提示] 无效的选项，请输入 1、2、3 或 0。" -ForegroundColor Yellow
            }
        }
    }
}

# 检查当前终端是否支持原生 Console.ReadKey
$canUseReadKey = $false
try {
    if (-not [Console]::IsInputRedirected) {
        $canUseReadKey = $true
    }
} catch {
    $canUseReadKey = $false
}

if (-not $canUseReadKey) {
    Show-StandardMenu
    exit 0
}

# 交互式键盘监听循环
$selectedIndex = 0

while ($true) {
    Render-Menu -curIndex $selectedIndex
    try {
        $keyInfo = [Console]::ReadKey($true)
    } catch {
        # 若 ReadKey 发生异常，平滑降级为标准输入菜单
        Show-StandardMenu
        exit 0
    }

    $isEnter = ($keyInfo.Key -eq [ConsoleKey]::Enter -or $keyInfo.KeyChar -eq "`r" -or $keyInfo.KeyChar -eq "`n" -or $keyInfo.Key -eq [ConsoleKey]::Spacebar)

    if ($keyInfo.Key -eq [ConsoleKey]::UpArrow) {
        $selectedIndex = ($selectedIndex - 1 + $options.Count) % $options.Count
    }
    elseif ($keyInfo.Key -eq [ConsoleKey]::DownArrow) {
        $selectedIndex = ($selectedIndex + 1) % $options.Count
    }
    elseif ($isEnter) {
        $act = $options[$selectedIndex].Action
        if ($act -eq "install") { Invoke-InstallTask -interactive $true }
        elseif ($act -eq "uninstall") { Invoke-UninstallTask -interactive $true }
        elseif ($act -eq "run") { Invoke-RunCheckin -interactive $true }
        elseif ($act -eq "exit") {
            Clear-Host
            Write-Host ""
            Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
            exit 0
        }
    }
    elseif ($keyInfo.Key -eq [ConsoleKey]::D1 -or $keyInfo.Key -eq [ConsoleKey]::NumPad1 -or $keyInfo.KeyChar -eq '1') {
        Invoke-InstallTask -interactive $true
    }
    elseif ($keyInfo.Key -eq [ConsoleKey]::D2 -or $keyInfo.Key -eq [ConsoleKey]::NumPad2 -or $keyInfo.KeyChar -eq '2') {
        Invoke-UninstallTask -interactive $true
    }
    elseif ($keyInfo.Key -eq [ConsoleKey]::D3 -or $keyInfo.Key -eq [ConsoleKey]::NumPad3 -or $keyInfo.KeyChar -eq '3') {
        Invoke-RunCheckin -interactive $true
    }
    elseif ($keyInfo.Key -eq [ConsoleKey]::D0 -or $keyInfo.Key -eq [ConsoleKey]::NumPad0 -or $keyInfo.KeyChar -eq '0' -or $keyInfo.Key -eq [ConsoleKey]::Escape -or $keyInfo.KeyChar -eq 'q' -or $keyInfo.KeyChar -eq 'Q') {
        Clear-Host
        Write-Host ""
        Write-Host "感谢使用，程序正在退出..." -ForegroundColor Cyan
        exit 0
    }
}