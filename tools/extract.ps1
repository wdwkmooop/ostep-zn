# extract.ps1
# 按章抽取 PDF 原文，生成两种文本：普通版（按阅读顺序）与 -layout 版（保留布局，便于看图/代码）。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\tools\extract.ps1 -Chapter 4
#   powershell -ExecutionPolicy Bypass -File .\tools\extract.ps1 -Appendix A
#   powershell -ExecutionPolicy Bypass -File .\tools\extract.ps1 -Chapter 4 -StartPage 47 -EndPage 57
#   powershell -ExecutionPolicy Bypass -File .\tools\extract.ps1 -Chapter 4 -IncludeLayout
#
# 输出（位于 ..\extraction\）：
#   raw\chNN.txt           普通抽取（含分页符 \f）
#   raw\chNN.layout.txt    -layout 抽取（含分页符 \f）
#   chNN.pages.txt         用分页符切分、每页带页码标记，便于逐页翻译
#   appX.pages.txt         附录的对应分页文件
#
# 页区间默认取自 AGENTS.md §5 的映射表；不确定时可显式传 -StartPage/-EndPage。

[CmdletBinding(DefaultParameterSetName = "Chapter")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Chapter")][int]$Chapter,
    [Parameter(Mandatory = $true, ParameterSetName = "Appendix")]
    [ValidateSet("A", "B", "C", "D", "E", "F", "G", "H")][string]$Appendix,
    [int]$StartPage = 0,
    [int]$EndPage = 0,
    [switch]$IncludeLayout
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PdfText = "D:\texlive\2026\bin\windows\pdftotext.exe"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SourceRoot = Split-Path -Parent $ProjectRoot
$Pdf = if ($PSCmdlet.ParameterSetName -eq "Appendix") {
    Join-Path $SourceRoot "ostep part3.pdf"
} elseif ($Chapter -le 24) {
    Join-Path $SourceRoot "ostep part1.pdf"
} elseif ($Chapter -le 34) {
    Join-Path $SourceRoot "ostep part2.pdf"
} else {
    Join-Path $SourceRoot "ostep part3.pdf"
}

if (-not (Test-Path -LiteralPath $PdfText)) { throw "找不到 pdftotext.exe: $PdfText" }
if (-not (Test-Path -LiteralPath $Pdf)) { throw "找不到原书 PDF: $Pdf" }

# 章节 -> 页区间（与 AGENTS.md §5 保持一致）
# 注：PDF 为各章单独排版后拼接，实际页序与"章号顺序"不一致（第 7 章排在调度章最后）。
# 下表为 2026-10 用 pdftotext 逐页复核后的真实区间。
$PageMap = @{
    1  = @(22, 23);   2  = @(24, 41);   3  = @(44, 45);   4  = @(46, 56)
    5  = @(57, 68);   6  = @(69, 83);   7  = @(125, 136); 8  = @(84, 95)
    9  = @(96, 109);  10 = @(110, 122); 11 = @(123, 124); 12 = @(137, 138)
    13 = @(139, 147); 14 = @(148, 157); 15 = @(158, 171); 16 = @(172, 182)
    17 = @(183, 199); 18 = @(200, 212); 19 = @(213, 228); 20 = @(229, 243)
    21 = @(244, 254); 22 = @(255, 271); 23 = @(272, 289); 24 = @(290, 292)
    25 = @(3, 4);      26 = @(5, 19);    27 = @(20, 31);   28 = @(32, 53)
    29 = @(54, 67);    30 = @(68, 83);   31 = @(84, 101);  32 = @(102, 117)
    33 = @(118, 128);  34 = @(129, 130)
    35 = @(3, 4);       36 = @(5, 17);     37 = @(18, 33);    38 = @(34, 51)
    39 = @(52, 77);     40 = @(78, 95);    41 = @(96, 109);   42 = @(110, 130)
    43 = @(131, 146);   44 = @(147, 170);  45 = @(171, 183);  46 = @(184, 185)
    47 = @(186, 187);   48 = @(188, 203);  49 = @(204, 221);  50 = @(222, 235)
    51 = @(236, 237)
}

$AppendixMap = @{
    "A" = @(238, 238); "B" = @(239, 251); "C" = @(252, 252); "D" = @(253, 265)
    "E" = @(266, 267); "F" = @(268, 279); "G" = @(280, 283); "H" = @(284, 286)
}

if ($StartPage -le 0 -or $EndPage -le 0) {
    if ($PSCmdlet.ParameterSetName -eq "Appendix") {
        $StartPage = $AppendixMap[$Appendix][0]
        $EndPage   = $AppendixMap[$Appendix][1]
    } else {
        if (-not $PageMap.ContainsKey($Chapter)) { throw "无第 $Chapter 章的默认页区间，请显式传 -StartPage/-EndPage" }
        $StartPage = $PageMap[$Chapter][0]
        $EndPage   = $PageMap[$Chapter][1]
    }
}

$chTag = if ($PSCmdlet.ParameterSetName -eq "Appendix") { "app$Appendix" } else { "ch{0:D2}" -f $Chapter }
$rawDir = Join-Path $ProjectRoot "extraction\raw"
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

$plain  = Join-Path $rawDir "$chTag.txt"
$layout = Join-Path $rawDir "$chTag.layout.txt"

Write-Host "[extract] $chTag : PDF p$StartPage..$EndPage -> $plain"
& $PdfText -f $StartPage -l $EndPage $Pdf $plain 2>$null
if ($?) { Write-Host "  普通抽取完成" }

if ($IncludeLayout) {
    & $PdfText -layout -f $StartPage -l $EndPage $Pdf $layout 2>$null
    if ($?) { Write-Host "  布局抽取完成: $layout" }
}

# 生成带页码标记的分页文件
$txt = Get-Content -LiteralPath $plain -Raw -Encoding UTF8
$pages = $txt -split "`f"
$sb = New-Object System.Text.StringBuilder
for ($i = 0; $i -lt $pages.Count; $i++) {
    $pdfPage = $StartPage + $i
    [void]$sb.AppendLine("========== PDF PAGE $pdfPage ==========")
    [void]$sb.AppendLine($pages[$i].TrimEnd())
    [void]$sb.AppendLine("")
}
$pagesFile = Join-Path $ProjectRoot "extraction\$chTag.pages.txt"
Set-Content -LiteralPath $pagesFile -Value $sb.ToString() -Encoding UTF8
Write-Host "[extract] 分页文件 -> $pagesFile  (共 $($pages.Count) 页)"
