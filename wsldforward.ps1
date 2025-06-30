# WSL 端口转发管理器
# 版本：1.0
param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Command,
    
    [Parameter(Mandatory=$false)]
    [int]$wslport,
    
    [Parameter(Mandatory=$false)]
    [int]$winport,
    
    [Alias("h")]
    [switch]$help
)

function Show-Help {
    Write-Host "`nWSL 端口转发管理器 v1.0" -ForegroundColor Cyan
    Write-Host "======================================`n"
    
    Write-Host "使用方法: wslforward.ps1 [命令] [参数]`n"
    
    Write-Host "可用命令:" -ForegroundColor Yellow
    Write-Host "  add     - 添加端口转发 (需要 -winport 和 -wslport)"
    Write-Host "  delete  - 删除端口转发 (需要 -winport)"
    Write-Host "  update  - 更新转发目标 (需要 -winport 和 -wslport)"
    Write-Host "  list    - 查看所有规则"
    Write-Host "  clear   - 清除所有规则`n"
    
    Write-Host "参数选项:" -ForegroundColor Yellow
    Write-Host "  -winport   - Windows 监听端口"
    Write-Host "  -wslport   - WSL 目标端口"
    Write-Host "  -help (-h) - 显示帮助信息`n"
    
    Write-Host "示例:" -ForegroundColor Green
    Write-Host "  # 添加端口转发"
    Write-Host "  wslforward.ps1 add -winport 35050 -wslport 2333`n"
    
    Write-Host "  # 更新转发目标"
    Write-Host "  wslforward.ps1 update -winport 35050 -wslport 2334`n"
    
    Write-Host "  # 删除端口转发"
    Write-Host "  wslforward.ps1 delete -winport 35050`n"
    
    Write-Host "  # 查看所有规则"
    Write-Host "  wslforward.ps1 list`n"
    
    Write-Host "  # 显示帮助"
    Write-Host "  wslforward.ps1 -help`n"
}

# 显示帮助（支持多种帮助请求格式）
if ($help -or $Command -in @('help', '-help', '--help', '/?') -or (-not $PSBoundParameters.Count)) {
    Show-Help
    exit 0
}

# 验证命令有效性
$validCommands = @('add', 'delete', 'update', 'list', 'clear')
if ($Command -and ($Command -notin $validCommands)) {
    Write-Host "`n错误：未知命令 '$Command'。有效命令为: $($validCommands -join ', ')`n" -ForegroundColor Red
    Show-Help
    exit 1
}

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $Command -in @('add', 'delete', 'update', 'clear')) {
    Write-Host "`n错误：此命令需要管理员权限。请以管理员身份运行 PowerShell。`n" -ForegroundColor Red
    exit 1
}

# 防火墙规则名称前缀
$firewallRulePrefix = "WSL_端口转发_"

function Add-PortForward {
    param(
        [int]$wslport,
        [int]$winport
    )
    
    # 检查端口是否已被使用
    $existingRule = netsh interface portproxy show v4tov4 | Where-Object { $_ -match ":$winport\s+" }
    if ($existingRule) {
        Write-Host "`n警告：端口 $winport 已被使用：" -ForegroundColor Yellow
        $existingRule | ForEach-Object { Write-Host "  $_" }
        Write-Host "`n请先删除现有规则或选择其他端口`n" -ForegroundColor Yellow
        return
    }
    
    # 添加端口转发
    netsh interface portproxy add v4tov4 listenport=$winport connectport=$wslport connectaddress=127.0.0.1
    
    # 创建防火墙规则
    $ruleName = $firewallRulePrefix + $winport
    if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name $ruleName -DisplayName "WSL转发端口_$winport" `
            -Direction Inbound -LocalPort $winport -Protocol TCP -Action Allow
    }
    
    Write-Host "`n成功：端口 $winport 已转发到 WSL 端口 $wslport`n" -ForegroundColor Green
}

function Remove-PortForward {
    param([int]$winport)
    
    # 删除端口转发
    netsh interface portproxy delete v4tov4 listenport=$winport listenaddress=*
    
    # 删除防火墙规则
    $ruleName = $firewallRulePrefix + $winport
    if (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -Name $ruleName
    }
    
    Write-Host "`n已移除端口 $winport 的转发规则`n" -ForegroundColor Green
}

function Update-PortForward {
    param(
        [int]$winport,
        [int]$wslport
    )
    
    # 更新操作 = 删除旧规则 + 添加新规则
    Remove-PortForward -winport $winport
    Add-PortForward -wslport $wslport -winport $winport
    
    Write-Host "`n已更新转发规则：$winport → $wslport`n" -ForegroundColor Green
}

function List-PortForwards {
    Write-Host "`n活动端口转发规则:" -ForegroundColor Cyan
    $rules = netsh interface portproxy show all
    if (-not $rules) {
        Write-Host "  无活动规则" -ForegroundColor Gray
    } else {
        $rules
    }
    
    Write-Host "`n防火墙规则:" -ForegroundColor Cyan
    $firewallRules = Get-NetFirewallRule -Name "$firewallRulePrefix*" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Direction -eq "Inbound" -and $_.Action -eq "Allow" }
    
    if (-not $firewallRules) {
        Write-Host "  无相关防火墙规则" -ForegroundColor Gray
    } else {
        $firewallRules | Format-Table Name, DisplayName, Enabled, Direction, Action -AutoSize
    }
    Write-Host ""
}

function Clear-AllForwards {
    # 确认操作
    $confirmation = Read-Host "`n确定要删除所有端口转发规则吗？(y/n)"
    if ($confirmation -ne 'y') {
        Write-Host "`n操作已取消`n" -ForegroundColor Yellow
        return
    }
    
    # 删除所有端口转发
    netsh interface portproxy reset
    
    # 删除所有相关防火墙规则
    Get-NetFirewallRule -Name "$firewallRulePrefix*" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-NetFirewallRule -Name $_.Name
    }
    
    Write-Host "`n已清除所有端口转发规则和防火墙例外`n" -ForegroundColor Green
}

# 主执行逻辑
try {
    switch ($Command) {
        "add" {
            if (-not $winport -or -not $wslport) {
                Write-Host "`n错误：add 命令需要 -winport 和 -wslport 参数`n" -ForegroundColor Red
                Show-Help
                exit 1
            }
            Add-PortForward -winport $winport -wslport $wslport
        }
        
        "delete" {
            if (-not $winport) {
                Write-Host "`n错误：delete 命令需要 -winport 参数`n" -ForegroundColor Red
                Show-Help
                exit 1
            }
            Remove-PortForward -winport $winport
        }
        
        "update" {
            if (-not $winport -or -not $wslport) {
                Write-Host "`n错误：update 命令需要 -winport 和 -wslport 参数`n" -ForegroundColor Red
                Show-Help
                exit 1
            }
            Update-PortForward -winport $winport -wslport $wslport
        }
        
        "list" {
            List-PortForwards
        }
        
        "clear" {
            Clear-AllForwards
        }
        
        default {
            if (-not $Command) {
                Write-Host "`n错误：缺少命令参数`n" -ForegroundColor Red
            } else {
                Write-Host "`n错误：未知命令 '$Command'`n" -ForegroundColor Red
            }
            Show-Help
            exit 1
        }
    }
}
catch {
    Write-Host "`n发生错误: $_`n" -ForegroundColor Red
    exit 1
}
