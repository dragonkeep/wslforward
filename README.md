# wslforward
Windows 到 WSL 的端口转发管理工具。


# 简介
为了便于Windows主机跟WSL进行端口转发编写的powershell脚本，使用方式也十分简单，会自动添加防火墙规则以及端口映射规则，使用需要有管理员权限。


# 使用
使用方法: wslforward.ps1 [命令] [参数]

可用命令:

  add     - 添加端口转发 (需要 -winport 和 -wslport)
  
  delete  - 删除端口转发 (需要 -winport)
  
  update  - 更新转发目标 (需要 -winport 和 -wslport)
  
  list    - 查看所有规则
  
  clear   - 清除所有规则

参数选项:

  -winport   - Windows 监听端口

  -wslport   - WSL 目标端口

  -help (-h) - 显示帮助信息

示例:

  添加端口转发
  
  wslforward.ps1 add -winport 35050 -wslport 2333
  
  更新转发目标
  
  wslforward.ps1 update -winport 35050 -wslport 2334
  
  删除端口转发
    
  wslforward.ps1 delete -winport 35050
  
  查看所有规则
  
  wslforward.ps1 list
  
  显示帮助
  
  wslforward.ps1 -help
