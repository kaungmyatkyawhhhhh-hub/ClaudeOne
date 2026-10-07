# Draws the GYM ARC fits as classic Shirt templates (585 x 559 PNG, transparent where the skin should show) into
# clothing_templates/<top>_<color>.png. Run from the repo root:  powershell -File tools/clothing_templates.ps1
# Layout (muscle_v8/source/uvmap.py): torso rects F/B/R/L/U, arm rects per side; on the 128 px tall faces the upper torso
# uses 0-80 % and the lower torso 80-100 %; on the arms the upper arm 0-45 %, the lower arm 45-85 %, the hand 85-100 %.
# Plain designs, no logos; a small "GYM ARC" print on some fronts.
Add-Type -AssemblyName System.Drawing
$out = Join-Path (Get-Location) "clothing_templates"
New-Item -ItemType Directory -Force $out | Out-Null

$TORSO = @{ F = @(231, 74, 128, 128); B = @(427, 74, 128, 128); R = @(165, 74, 64, 128); L = @(361, 74, 64, 128); U = @(231, 8, 128, 64) }
$RARM = @{ F = @(217, 355, 64, 128); B = @(85, 355, 64, 128); R = @(151, 355, 64, 128); L = @(19, 355, 64, 128); U = @(217, 289, 64, 64) }
$LARM = @{ F = @(308, 355, 64, 128); B = @(440, 355, 64, 128); L = @(374, 355, 64, 128); R = @(506, 355, 64, 128); U = @(308, 289, 64, 64) }

function Hex($h) { return [System.Drawing.ColorTranslator]::FromHtml($h) }
function Shade($c, $k) { return [System.Drawing.Color]::FromArgb(255, [int]([Math]::Max(0, [Math]::Min(255, $c.R * $k))), [int]([Math]::Max(0, [Math]::Min(255, $c.G * $k))), [int]([Math]::Max(0, [Math]::Min(255, $c.B * $k)))) }

# fill a vertical band (fractions t0..t1 of the rect's height) of a rect
function Band($g, $rect, $t0, $t1, $color) {
    $x, $y, $w, $h = $rect
    $y0 = $y + [int]($h * $t0); $y1 = $y + [int]($h * $t1)
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.FillRectangle($brush, $x, $y0, $w, $y1 - $y0)
    $brush.Dispose()
}
function Line($g, $x0, $y0, $x1, $y1, $color, $width) {
    $pen = New-Object System.Drawing.Pen $color, $width
    $g.DrawLine($pen, $x0, $y0, $x1, $y1)
    $pen.Dispose()
}
function Print($g, $rect, $text, $color, $size, $fx, $fy) {
    $x, $y, $w, $h = $rect
    $font = New-Object System.Drawing.Font "Arial", $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object System.Drawing.SolidBrush $color
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($text, $font, $brush, [single]($x + $w * $fx), [single]($y + $h * $fy), $format)
    $font.Dispose(); $brush.Dispose()
}
# the torso's 4 sides + top, down to fraction $bottom
function Torso($g, $color, $bottom) {
    foreach ($k in "F", "B", "R", "L") { Band $g $TORSO[$k] 0 $bottom $color }
    Band $g $TORSO.U 0 1 $color
    # the gutters between and above the torso faces too: the trap and delt meshes stretch into them at mass monster size
    Band $g @(160, 60, 425, 14) 0 1 $color
    Band $g @(160, 74, 425, 128) 0 $bottom $color
}
# both arms' 4 sides (+ the shoulder top) down to fraction $length
function Sleeves($g, $color, $length) {
    foreach ($arm in $RARM, $LARM) {
        foreach ($k in "F", "B", "R", "L") { Band $g $arm[$k] 0 $length $color }
        Band $g $arm.U 0 1 $color
    }
    # the gutters between the arm faces too (the round shoulder caps stretch into them)
    Band $g @(0, 350, 585, 128) 0 $length $color
}
# a darker band (hem / cuff) at fraction $at on every face of a set
function Trim($g, $set, $keys, $at, $thick, $color) {
    foreach ($k in $keys) { Band $g $set[$k] ($at - $thick) $at $color }
}

$tops = [ordered]@{
    PumpCover       = @{ accent = "#6B8E6B" }
    Stringer        = @{ accent = "#C0392B" }
    Compression     = @{ accent = "#1F3B73" }
    CroppedHoodie   = @{ accent = "#2E8E8E" }
    GymTee          = @{ accent = "#3A86C8" }
    SleevelessHoodie = @{ accent = "#E07B39" }
}
$colors = [ordered]@{ Black = "#1E1E22"; Grey = "#7D8088"; White = "#EDEDED" }

foreach ($top in $tops.Keys) {
    $palette = [ordered]@{}
    foreach ($c in $colors.Keys) { $palette[$c] = $colors[$c] }
    $palette["Accent"] = $tops[$top].accent
    foreach ($cname in $palette.Keys) {
        $bmp = New-Object System.Drawing.Bitmap 585, 559, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $base = Hex $palette[$cname]
        $dark = Shade $base 0.78
        $light = if ($cname -eq "Black") { Hex "#D8D8DC" } elseif ($cname -eq "White") { Hex "#2A2A2E" } else { Hex "#F4F4F4" }
        $all = @("F", "B", "R", "L")
        switch ($top) {
            "PumpCover" {
                # oversized: the whole torso, roomy sleeves past the elbow, a dropped hem band, small chest print
                Torso $g $base 0.8
                Sleeves $g $base 0.64
                Trim $g $TORSO $all 0.8 0.05 $dark
                Trim $g $RARM $all 0.64 0.05 $dark
                Trim $g $LARM $all 0.64 0.05 $dark
                Line $g 231 74 359 74 $dark 3
                Print $g $TORSO.F "GYM ARC" $light 11 0.68 0.14
            }
            "Stringer" {
                # a stringer tank: thin straps, deep open sides, a narrow front and Y-back; arms and delts bare
                $f = $TORSO.F; $b = $TORSO.B
                $brush = New-Object System.Drawing.SolidBrush $base
                $g.FillRectangle($brush, $f[0] + 34, $f[1] + 30, 60, 72)      # front panel (low neck)
                $g.FillRectangle($brush, $f[0] + 26, $f[1] + 50, 76, 52)
                $g.FillRectangle($brush, $f[0] + 28, $f[1], 7, 34)           # straps
                $g.FillRectangle($brush, $f[0] + 93, $f[1], 7, 34)
                $g.FillRectangle($brush, $b[0] + 56, $b[1] + 18, 16, 84)     # Y-back
                $g.FillRectangle($brush, $b[0] + 30, $b[1] + 70, 68, 32)
                $g.FillRectangle($brush, $b[0] + 28, $b[1], 7, 26)
                $g.FillRectangle($brush, $b[0] + 93, $b[1], 7, 26)
                $g.FillRectangle($brush, $TORSO.U[0] + 28, $TORSO.U[1], 7, 64)
                $g.FillRectangle($brush, $TORSO.U[0] + 93, $TORSO.U[1], 7, 64)
                $brush.Dispose()
                Band $g $TORSO.R 0.6 0.8 $base
                Band $g $TORSO.L 0.6 0.8 $base
                Trim $g $TORSO $all 0.8 0.04 $dark
            }
            "Compression" {
                # tight long sleeves to the wrist; darker side panels and seams so it reads as compression
                Torso $g $base 0.8
                Sleeves $g $base 0.85
                Band $g $TORSO.R 0 0.8 $dark
                Band $g $TORSO.L 0 0.8 $dark
                foreach ($arm in $RARM, $LARM) { Band $g $arm.R 0 0.85 $dark; Band $g $arm.L 0 0.85 $dark }
                $f = $TORSO.F
                Line $g ($f[0] + 64) ($f[1] + 8) ($f[0] + 64) ($f[1] + 100) $dark 2
                Line $g ($f[0] + 10) ($f[1] + 52) ($f[0] + 118) ($f[1] + 52) $dark 2
                Print $g $TORSO.F "GYM ARC" $light 9 0.5 0.86
            }
            "CroppedHoodie" {
                # cropped above the abs (they show below the crop line); long sleeves with cuffs, drawstrings
                Torso $g $base 0.46
                Sleeves $g $base 0.85
                Trim $g $TORSO $all 0.46 0.06 $dark
                Trim $g $RARM $all 0.85 0.06 $dark
                Trim $g $LARM $all 0.85 0.06 $dark
                $f = $TORSO.F
                Line $g ($f[0] + 54) ($f[1] + 2) ($f[0] + 52) ($f[1] + 30) $light 2
                Line $g ($f[0] + 74) ($f[1] + 2) ($f[0] + 76) ($f[1] + 30) $light 2
                Line $g ($TORSO.U[0] + 20) ($TORSO.U[1] + 40) ($TORSO.U[0] + 108) ($TORSO.U[1] + 40) $dark 4
            }
            "GymTee" {
                # a plain tee: the whole torso, short sleeves over most of the upper arm, a collar
                Torso $g $base 0.8
                Sleeves $g $base 0.38
                Trim $g $RARM $all 0.38 0.04 $dark
                Trim $g $LARM $all 0.38 0.04 $dark
                Trim $g $TORSO $all 0.8 0.03 $dark
                $f = $TORSO.F
                $pen = New-Object System.Drawing.Pen $dark, 3
                $g.DrawArc($pen, $f[0] + 44, $f[1] - 14, 40, 26, 0, 180)
                $pen.Dispose()
                Print $g $TORSO.F "GYM ARC" $light 12 0.5 0.32
            }
            "SleevelessHoodie" {
                # the whole torso with wide armholes (bare arms and delts), drawstrings, a pouch line
                Torso $g $base 0.8
                Band $g $TORSO.R 0 0.32 ([System.Drawing.Color]::Transparent)
                Band $g $TORSO.L 0 0.32 ([System.Drawing.Color]::Transparent)
                $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $clear = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Transparent)
                $g.FillRectangle($clear, $TORSO.R[0], $TORSO.R[1], 64, 40)
                $g.FillRectangle($clear, $TORSO.L[0], $TORSO.L[1], 64, 40)
                $clear.Dispose()
                $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
                Trim $g $TORSO $all 0.8 0.05 $dark
                $f = $TORSO.F
                Line $g ($f[0] + 54) ($f[1] + 2) ($f[0] + 52) ($f[1] + 30) $light 2
                Line $g ($f[0] + 74) ($f[1] + 2) ($f[0] + 76) ($f[1] + 30) $light 2
                Line $g ($f[0] + 30) ($f[1] + 78) ($f[0] + 98) ($f[1] + 78) $dark 2
                Line $g ($TORSO.U[0] + 20) ($TORSO.U[1] + 40) ($TORSO.U[0] + 108) ($TORSO.U[1] + 40) $dark 4
            }
        }
        $g.Dispose()
        $file = Join-Path $out ("{0}_{1}.png" -f $top, $cname)
        $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }
}
Get-ChildItem $out -Filter *.png | Measure-Object | ForEach-Object { "templates: $($_.Count)" }
