# build.ps1
# 生成静态站点到 build\ 目录。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
#   powershell -ExecutionPolicy Bypass -File .\tools\build.ps1 -Serve   # 本地预览

param(
    [switch]$Serve,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Python = "C:\Pythons\Python312\python3.exe"

if (-not (Test-Path -LiteralPath $Python)) { throw "找不到 Python: $Python" }

Push-Location $ProjectRoot
try {
    if ($Serve) {
        Write-Host "[build] mkdocs serve -> http://127.0.0.1:8000"
        & $Python -m mkdocs serve
    }
    elseif ($Strict) {
        Write-Host "[build] mkdocs build --strict"
        & $Python -m mkdocs build --strict
    }
    else {
        Write-Host "[build] mkdocs build"
        & $Python -m mkdocs build
    }
}
finally {
    Pop-Location
}
