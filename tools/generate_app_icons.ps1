$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot

function New-Color {
    param(
        [Parameter(Mandatory = $true)][string]$Hex,
        [int]$Alpha = 255
    )

    $rgb = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    return [System.Drawing.Color]::FromArgb($Alpha, $rgb.R, $rgb.G, $rgb.B)
}

function New-RoundedPath {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.RectangleF]$Rect,
        [Parameter(Mandatory = $true)][float]$Radius
    )

    $diameter = $Radius * 2
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Fill-RoundedRect {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory = $true)][System.Drawing.Brush]$Brush,
        [Parameter(Mandatory = $true)][System.Drawing.RectangleF]$Rect,
        [Parameter(Mandatory = $true)][float]$Radius
    )

    $path = New-RoundedPath -Rect $Rect -Radius $Radius
    $Graphics.FillPath($Brush, $path)
    $path.Dispose()
}

function Draw-RoundedRect {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory = $true)][System.Drawing.Pen]$Pen,
        [Parameter(Mandatory = $true)][System.Drawing.RectangleF]$Rect,
        [Parameter(Mandatory = $true)][float]$Radius
    )

    $path = New-RoundedPath -Rect $Rect -Radius $Radius
    $Graphics.DrawPath($Pen, $path)
    $path.Dispose()
}

function New-AppIconBitmap {
    param([int]$Size = 1024)

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $g.Clear([System.Drawing.Color]::Transparent)

    $scale = $Size / 1024.0
    $shadowRect = [System.Drawing.RectangleF]::new(78 * $scale, 92 * $scale, 868 * $scale, 868 * $scale)
    $iconRect = [System.Drawing.RectangleF]::new(64 * $scale, 56 * $scale, 896 * $scale, 896 * $scale)
    $corner = [float](184 * $scale)

    $shadowBrush = [System.Drawing.SolidBrush]::new((New-Color '#000000' 62))
    Fill-RoundedRect -Graphics $g -Brush $shadowBrush -Rect $shadowRect -Radius $corner
    $shadowBrush.Dispose()

    $bgBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $iconRect,
        (New-Color '#6F8058'),
        (New-Color '#29382E'),
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )
    Fill-RoundedRect -Graphics $g -Brush $bgBrush -Rect $iconRect -Radius $corner
    $bgBrush.Dispose()

    $clipPath = New-RoundedPath -Rect $iconRect -Radius $corner
    $g.SetClip($clipPath)

    $floorPen = [System.Drawing.Pen]::new((New-Color '#D2C6A9' 40), [float](8 * $scale))
    for ($i = 0; $i -le 5; $i++) {
        $x = (116 + $i * 160) * $scale
        $g.DrawLine($floorPen, [float]$x, [float](74 * $scale), [float]$x, [float](932 * $scale))
        $y = (102 + $i * 156) * $scale
        $g.DrawLine($floorPen, [float](72 * $scale), [float]$y, [float](952 * $scale), [float]$y)
    }
    $floorPen.Dispose()

    $wallBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.RectangleF]::new(0, 0, $Size, $Size),
        (New-Color '#8BA277'),
        (New-Color '#43533E'),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $wallShadow = [System.Drawing.SolidBrush]::new((New-Color '#000000' 58))
    $walls = @(
        @(134, 150, 196, 124),
        @(330, 150, 124, 284),
        @(592, 150, 262, 124),
        @(134, 524, 238, 124),
        @(724, 356, 130, 334),
        @(246, 734, 378, 124)
    )
    foreach ($wall in $walls) {
        $wallRect = [System.Drawing.RectangleF]::new($wall[0] * $scale, $wall[1] * $scale, $wall[2] * $scale, $wall[3] * $scale)
        $wallDrop = [System.Drawing.RectangleF]::new(($wall[0] + 10) * $scale, ($wall[1] + 14) * $scale, $wall[2] * $scale, $wall[3] * $scale)
        Fill-RoundedRect -Graphics $g -Brush $wallShadow -Rect $wallDrop -Radius ([float](34 * $scale))
        Fill-RoundedRect -Graphics $g -Brush $wallBrush -Rect $wallRect -Radius ([float](34 * $scale))
    }
    $wallBrush.Dispose()
    $wallShadow.Dispose()

    $pathPen = [System.Drawing.Pen]::new((New-Color '#7DD3C7' 214), [float](50 * $scale))
    $pathPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pathPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $route = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $route.AddLines([System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(196 * $scale, 666 * $scale),
        [System.Drawing.PointF]::new(470 * $scale, 666 * $scale),
        [System.Drawing.PointF]::new(470 * $scale, 504 * $scale),
        [System.Drawing.PointF]::new(650 * $scale, 504 * $scale)
    ))
    $g.DrawPath($pathPen, $route)
    $route.Dispose()

    $arrowBrush = [System.Drawing.SolidBrush]::new((New-Color '#7DD3C7' 230))
    $arrow = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $arrow.AddPolygon([System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(646 * $scale, 456 * $scale),
        [System.Drawing.PointF]::new(744 * $scale, 504 * $scale),
        [System.Drawing.PointF]::new(646 * $scale, 552 * $scale)
    ))
    $g.FillPath($arrowBrush, $arrow)
    $arrow.Dispose()
    $arrowBrush.Dispose()
    $pathPen.Dispose()

    $targetCenter = [System.Drawing.PointF]::new(688 * $scale, 666 * $scale)
    $targetShadow = [System.Drawing.SolidBrush]::new((New-Color '#000000' 52))
    $g.FillEllipse($targetShadow, ($targetCenter.X - 108 * $scale), ($targetCenter.Y - 92 * $scale), 216 * $scale, 216 * $scale)
    $targetShadow.Dispose()
    $targetPenOuter = [System.Drawing.Pen]::new((New-Color '#F3CA55'), [float](46 * $scale))
    $targetPenInner = [System.Drawing.Pen]::new((New-Color '#7E5F20'), [float](18 * $scale))
    $g.DrawEllipse($targetPenOuter, ($targetCenter.X - 86 * $scale), ($targetCenter.Y - 96 * $scale), 172 * $scale, 172 * $scale)
    $g.DrawEllipse($targetPenInner, ($targetCenter.X - 86 * $scale), ($targetCenter.Y - 96 * $scale), 172 * $scale, 172 * $scale)
    $targetPenOuter.Dispose()
    $targetPenInner.Dispose()

    $crateRect = [System.Drawing.RectangleF]::new(330 * $scale, 310 * $scale, 364 * $scale, 364 * $scale)
    $crateDrop = [System.Drawing.RectangleF]::new(350 * $scale, 334 * $scale, 364 * $scale, 364 * $scale)
    $crateShadow = [System.Drawing.SolidBrush]::new((New-Color '#000000' 86))
    Fill-RoundedRect -Graphics $g -Brush $crateShadow -Rect $crateDrop -Radius ([float](58 * $scale))
    $crateShadow.Dispose()

    $crateBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $crateRect,
        (New-Color '#E1A766'),
        (New-Color '#7B4726'),
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )
    Fill-RoundedRect -Graphics $g -Brush $crateBrush -Rect $crateRect -Radius ([float](58 * $scale))
    $crateBrush.Dispose()

    $bandBrush = [System.Drawing.SolidBrush]::new((New-Color '#6E3E22' 168))
    $g.FillRectangle($bandBrush, [System.Drawing.RectangleF]::new(330 * $scale, 310 * $scale, 70 * $scale, 364 * $scale))
    $g.FillRectangle($bandBrush, [System.Drawing.RectangleF]::new(624 * $scale, 310 * $scale, 70 * $scale, 364 * $scale))
    $bandBrush.Dispose()

    $plankPen = [System.Drawing.Pen]::new((New-Color '#4B2917' 150), [float](16 * $scale))
    $g.DrawLine($plankPen, [float](366 * $scale), [float](430 * $scale), [float](660 * $scale), [float](430 * $scale))
    $g.DrawLine($plankPen, [float](366 * $scale), [float](552 * $scale), [float](660 * $scale), [float](552 * $scale))
    $plankPen.Dispose()

    $bracePen = [System.Drawing.Pen]::new((New-Color '#573018' 190), [float](44 * $scale))
    $bracePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $bracePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($bracePen, [float](398 * $scale), [float](626 * $scale), [float](628 * $scale), [float](356 * $scale))
    $bracePen.Dispose()

    $crateHighlight = [System.Drawing.Pen]::new((New-Color '#F0BE7B' 160), [float](16 * $scale))
    $crateHighlight.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $crateHighlight.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($crateHighlight, [float](378 * $scale), [float](348 * $scale), [float](644 * $scale), [float](348 * $scale))
    $crateHighlight.Dispose()

    $crateOutline = [System.Drawing.Pen]::new((New-Color '#4A2816'), [float](18 * $scale))
    Draw-RoundedRect -Graphics $g -Pen $crateOutline -Rect $crateRect -Radius ([float](58 * $scale))
    $crateOutline.Dispose()

    $g.ResetClip()
    $clipPath.Dispose()

    $rimPen = [System.Drawing.Pen]::new((New-Color '#FFFFFF' 70), [float](10 * $scale))
    Draw-RoundedRect -Graphics $g -Pen $rimPen -Rect $iconRect -Radius $corner
    $rimPen.Dispose()

    $g.Dispose()
    return $bitmap
}

function Resize-Bitmap {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Source,
        [Parameter(Mandatory = $true)][int]$Size
    )

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $Size, $Size))
    $g.Dispose()
    return $bitmap
}

function Save-Png {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Get-PngBytes {
    param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap)

    $stream = [System.IO.MemoryStream]::new()
    $Bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $stream.ToArray()
    $stream.Dispose()
    return $bytes
}

function Save-Ico {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Source,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int[]]$Sizes
    )

    $entries = @()
    foreach ($size in $Sizes) {
        $bitmap = Resize-Bitmap -Source $Source -Size $size
        $entries += [PSCustomObject]@{
            Size = $size
            Bytes = Get-PngBytes -Bitmap $bitmap
        }
        $bitmap.Dispose()
    }

    $directory = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null

    $stream = [System.IO.File]::Create($Path)
    $writer = [System.IO.BinaryWriter]::new($stream)
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$entries.Count)

    $offset = 6 + (16 * $entries.Count)
    foreach ($entry in $entries) {
        $dimension = if ($entry.Size -eq 256) { 0 } else { $entry.Size }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$entry.Bytes.Length)
        $writer.Write([UInt32]$offset)
        $offset += $entry.Bytes.Length
    }

    foreach ($entry in $entries) {
        $writer.Write([byte[]]$entry.Bytes)
    }

    $writer.Dispose()
    $stream.Dispose()
}

$master = New-AppIconBitmap -Size 1024

$androidIcons = @{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png' = 48
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png' = 72
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png' = 96
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png' = 144
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png' = 192
}

foreach ($relativePath in $androidIcons.Keys) {
    $size = $androidIcons[$relativePath]
    $bitmap = Resize-Bitmap -Source $master -Size $size
    Save-Png -Bitmap $bitmap -Path (Join-Path $repoRoot $relativePath)
    $bitmap.Dispose()
}

Save-Ico -Source $master -Path (Join-Path $repoRoot 'windows/runner/resources/app_icon.ico') -Sizes @(16, 24, 32, 48, 64, 128, 256)

$preview = Resize-Bitmap -Source $master -Size 512
Save-Png -Bitmap $preview -Path (Join-Path $repoRoot 'docs/app_logo.png')
$preview.Dispose()

$master.Dispose()

Write-Host 'Generated Android launcher icons, Windows ICO, and docs/app_logo.png.'
