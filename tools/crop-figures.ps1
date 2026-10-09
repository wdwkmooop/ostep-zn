# crop-figures.ps1
# 依据 tools\crops.json 的裁剪框，从原书 PDF 高 DPI 渲染并裁出插图。
# 为避免边缘内容被截断，实际输出框会在配置框四周各增加 10% 的宽/高余量。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\tools\crop-figures.ps1 -Chapter 4
#   powershell -ExecutionPolicy Bypass -File .\tools\crop-figures.ps1 -Chapter 4 -Only fig4.1,fig4.2
#
# crops.json 格式（见 AGENTS.md §7）：
# {
#   "ch04": {
#     "fig4.1": { "page": 47, "x": 250, "y": 1400, "w": 2050, "h": 700, "dpi": 300 }
#   }
# }
#   page  : PDF 页码（1-based）
#   x,y   : 裁剪框左上角（渲染像素，原点在页面左上角）
#   w,h   : 裁剪框宽高（渲染像素）
#   dpi   : 可选，覆盖默认渲染分辨率（默认 300）
#   paddingRatio : 可选，覆盖四周余量比例（默认 0.10）
#
# 输出：..\docs\assets\figures\chNN\<name>.png

param(
    [Parameter(Mandatory = $true)][int]$Chapter,
    [string[]]$Only = @()
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Pdftoppm = "D:\texlive\2026\bin\windows\pdftoppm.exe"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Pdf = Join-Path (Split-Path -Parent $ProjectRoot) "ostep part1.pdf"
$CropsFile = Join-Path $PSScriptRoot "crops.json"
$DefaultDpi = 300
$DefaultPaddingRatio = 0.10

if (-not (Test-Path -LiteralPath $Pdftoppm)) { throw "找不到 pdftoppm.exe: $Pdftoppm" }
if (-not (Test-Path -LiteralPath $Pdf)) { throw "找不到原书 PDF: $Pdf" }
if (-not (Test-Path -LiteralPath $CropsFile)) { throw "找不到裁剪配置: $CropsFile" }

$crops = Get-Content -LiteralPath $CropsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$chTag = "ch{0:D2}" -f $Chapter
if (-not $crops.PSObject.Properties.Name.Contains($chTag)) {
    throw "crops.json 中没有 $chTag 的条目"
}

$outDir = Join-Path $ProjectRoot "docs\assets\figures\$chTag"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$tmpDir = Join-Path $env:TEMP "ostep-crop-$chTag"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$entries = $crops.$chTag.PSObject.Properties
foreach ($e in $entries) {
    $name = $e.Name
    if ($Only.Count -gt 0 -and ($Only -notcontains $name)) { continue }

    $c = $e.Value
    $dpi = if ($c.PSObject.Properties.Name.Contains("dpi")) { [int]$c.dpi } else { $DefaultDpi }
    $page = [int]$c.page

    $paddingRatio = if ($c.PSObject.Properties.Name.Contains("paddingRatio")) {
        [double]$c.paddingRatio
    } else {
        $DefaultPaddingRatio
    }
    if ($paddingRatio -lt 0) { throw "$chTag/$name 的 paddingRatio 不能小于 0" }

    Write-Host "[crop] $chTag/$name : p$page @ ${dpi}dpi  (x=$($c.x) y=$($c.y) w=$($c.w) h=$($c.h), padding=$($paddingRatio * 100)%)"

    # 先整页渲染到临时 PNG，再按框裁剪（pdftoppm 的 -x/-y 也是像素，可直接用）
    $prefix = Join-Path $tmpDir "$name-full"
    & $Pdftoppm -png -r $dpi -f $page -l $page $Pdf $prefix 2>$null
    $rendered = Get-ChildItem -LiteralPath $tmpDir -Filter "$name-full*.png" |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $rendered) { Write-Warning "  渲染失败，跳过 $name"; continue }

    $dest = Join-Path $outDir "$name.png"
    Add-Type -AssemblyName System.Drawing
    $src = [System.Drawing.Image]::FromFile($rendered.FullName)
    try {
        $baseX = [int]$c.x
        $baseY = [int]$c.y
        $baseW = [int]$c.w
        $baseH = [int]$c.h
        $padX = [int][Math]::Ceiling($baseW * $paddingRatio)
        $padY = [int][Math]::Ceiling($baseH * $paddingRatio)
        $cropX = [Math]::Max(0, $baseX - $padX)
        $cropY = [Math]::Max(0, $baseY - $padY)
        $cropRight = [Math]::Min($src.Width, $baseX + $baseW + $padX)
        $cropBottom = [Math]::Min($src.Height, $baseY + $baseH + $padY)
        $rect = New-Object System.Drawing.Rectangle($cropX, $cropY, ($cropRight - $cropX), ($cropBottom - $cropY))
        $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $rect.Width, $rect.Height)), $rect, [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose()
        $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        Write-Host "        -> $dest  (x=$($rect.X) y=$($rect.Y) w=$($rect.Width) h=$($rect.Height))"
    }
    finally {
        $src.Dispose()
        Remove-Item -LiteralPath $rendered.FullName -Force -ErrorAction SilentlyContinue
    }
}

Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[crop] 完成。"
