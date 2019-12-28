# mtBGInfo
# Create BGInfo-like Wallpaper Overlay with OS, Hardware & Network Stats


## Config ##

# Text Config
$font="Segoe UI Light"
$size=10.0
$textPaddingLeft = 20
$textPaddingTop = 20
$textItemSpace = 2
# Overlay color (values: 0 = black / 255 = white)
$overlaycolor = 255
# Opacity (values : 0-255)
$overlayOpacity = 50
# Text Color (https://condor.depaul.edu/sjost/it236/documents/colorNames.htm)
$textColor = "White" 


# Logo Config
$logoFile = "$PSScriptRoot\logo.png"
$logoWidth = 250
$logoHeight = 250
$logoPaddingRight = 50
$logoPaddingTop = 50

# Wallpaper Config
$wallpaperImagesSource = "$Env:USERPROFILE\Pictures\Wallpaper"
$wallpaperImageOutput = "$Env:USERPROFILE"

##############################################################################

## Lower task priority ##
[System.Threading.Thread]::CurrentThread.Priority = 'BelowNormal'


## Load Modules ##
Import-Module $PSScriptRoot\brshSysInfo\brshSysInfo.psd1 

#### Define Genral Functions ####

function Parse-Date {
param(
    $Date,
    $Format
) 
    $Template = "MM.dd.yyyy HH:mm"
    Get-Date([DateTime]::ParseExact($Date, $Template, $null)) -Format $Format
}


## Prepare System Information ##

$OsInfo = Get-siOSInfo

$Proc = [object[]]$(get-WMIObject Win32_Processor)
$Core = $Proc.count
$LogicalCPU = $($Proc | measure-object -Property NumberOfLogicalProcessors -sum).Sum
$PhysicalCPU = $($Proc | measure-object -Property NumberOfCores -sum).Sum
$Hash = @{
    LogicalCPU  = $LogicalCPU
    PhysicalCPU = $PhysicalCPU
    CoreNr      = $Core
    HyperThreading = $($LogicalCPU -gt $PhysicalCPU)

}
$CpuInfo = New-Object -TypeName PSObject -Property $Hash

If($CpuInfo.HyperThreading -eq $true) {
    $CpuInfoHT = "$($OsInfo.CPUName) ($($CpuInfo.PhysicalCPU) Kerne mit HyperThreading)"
} Else {
    $CpuInfoHT = "$($OsInfo.CPUName) ($($CpuInfo.PhysicalCPU) Kerne)"
}


$NetworkInfo =  (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Wi-Fi Direct*" -and $_.InterfaceDescription -notlike "*Bluetooth*" -and $_.InterfaceDescription -notlike "*Hyper-V*" -and $_.InterfaceDescription -notlike "*vEthernet*" -and $_.InterfaceDescription -notlike "*Docker*" } | ForEach-Object {
                    $NetAdapter = $_.InterfaceDescription
                    $Alias = $_.Name
                    $IPv4 = (Get-NetIPAddress -InterfaceAlias $_.InterfaceAlias | Where-Object { $_.AddressFamily -eq "IPv4" }).IPAddress
                    "$($NetAdapter): $($IPv4)"
                }) | Out-String



$o = ([ordered]@{
    "Computer & Domäne" = "$($OsInfo.HostName) @ $($OsInfo.HostDomain) ($($OsInfo.LogonServer))".ToUpper()
    Benutzer = "$($OsInfo.UserName.ToUpper())"
    Betriebssystem = "$($OsInfo.Caption) $($OsInfo.OSBitness), Build $([System.Environment]::OSVersion.Version.Build)"
    "Letzter Neustart" = "$(Parse-Date -Date $OsInfo.BootDate -Format "dd.MM.yyyy HH:mm")"
    System = $( If($OsInfo.Manufacturer -like "VMware*") { "VMware Virtual Machine" } Elseif($OsInfo.Manufacturer -like "Microsoft*") { "Hyper-V Virtual Machine" } Else { $($OsInfo.Manufacturer + ' ' + $OsInfo.Model + ' (SN: ' + $OsInfo.SerialNumber + ')') })
    "Prozessor & Speicher" = "$($CpuInfoHT), $($OsInfo.MemoryMB/1024) GB RAM"
    Netzwerk = "$($NetworkInfo)"
    Aktualisiert = "$(Get-Date -Format "dd.MM.yyyy HH:mm")`n"
})

# original src: https://p0w3rsh3ll.wordpress.com/2014/08/29/poc-tatoo-the-background-of-your-virtual-machines/

Function New-ImageInfo {
    # src: https://github.com/fabriceleal/Imagify/blob/master/imagify.ps1
    param(  
        [Parameter(Mandatory=$True, Position=1)]
        [object] $data,
        [Parameter(Mandatory=$True)]
        [string] $in="$wallpaperImagesSource\current.jpg",
        [string] $font="Segoe UI Light",
        [float] $size=10.0,
        [float] $textPaddingLeft = 20,
        [float] $textPaddingTop = 20,
        [float] $textItemSpace = 3,
        [string] $out="$wallpaperImageOutput\wallpaper.png" 
    )

    [system.reflection.assembly]::loadWithPartialName('system') | out-null
    [system.reflection.assembly]::loadWithPartialName('system.drawing') | out-null
    [system.reflection.assembly]::loadWithPartialName('system.drawing.imaging') | out-null
    [system.reflection.assembly]::loadWithPartialName('system.windows.forms') | out-null

    $foreBrush  = [System.Drawing.Brushes]::$textColor
    $backBrush  = new-object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($overlayOpacity, $overlayColor, $overlayColor, $overlayColor))
    
    

    # Create Bitmap
    $SR = [System.Windows.Forms.Screen]::AllScreens | Where-Object Primary | Select-Object -ExpandProperty Bounds | Select-Object Width,Height

    Write-Output $SR >> "$wallpaperImageOutput\wallpaper.log"

    $background = new-object system.drawing.bitmap($SR.Width, $SR.Height)
    $bmp = new-object system.drawing.bitmap -ArgumentList $in

    # Create Graphics
    $image = [System.Drawing.Graphics]::FromImage($background)

    # Paint image's background
    $rect = new-object system.drawing.rectanglef(0, 0, $SR.width, $SR.height)
    $image.FillRectangle($backBrush, $rect)

    # add in image
    $topLeft = new-object System.Drawing.RectangleF(0, 0, $SR.Width, $SR.Height)
    $image.DrawImage($bmp, $topLeft)

    # Draw string
    $strFrmt = new-object system.drawing.stringformat
    $strFrmt.Alignment = [system.drawing.StringAlignment]::Near
    $strFrmt.LineAlignment = [system.drawing.StringAlignment]::Near

    $taskbar = [System.Windows.Forms.Screen]::AllScreens
    $taskbarOffset = $taskbar[0].Bounds.Height - $taskbar[0].WorkingArea.Height

    # first get max key & val widths
    $maxKeyWidth = 0
    $maxValWidth = 0
    $textBgHeight = 0 + $taskbarOffset 
    $textBgWidth = 0

    # a reversed ordered collection is used since it starts from the bottom
    $reversed = [ordered]@{}

    foreach ($h in $data.GetEnumerator()) {
        $valString = "$($h.Value)"
        $valFont = New-Object System.Drawing.Font($font, $size, [System.Drawing.FontStyle]::Regular)
        $valSize = [system.windows.forms.textrenderer]::MeasureText($valString, $valFont)
        $maxValWidth = [math]::Max($maxValWidth, $valSize.Width)

        $keyString = "$($h.Name): "
        $keyFont = New-Object System.Drawing.Font($font, $size, [System.Drawing.FontStyle]::Bold)
        $keySize = [system.windows.forms.textrenderer]::MeasureText($keyString, $keyFont)
        $maxKeyWidth = [math]::Max($maxKeyWidth, $keySize.Width)

        $maxItemHeight = [math]::Max($valSize.Height, $keySize.Height)
        $textBgHeight += ($maxItemHeight + $textItemSpace)

        $reversed.Insert(0, $h.Name, $h.Value)
    }

    $textBgWidth = $maxKeyWidth + $maxValWidth + $textPaddingLeft
    $textBgHeight += $textPaddingTop
    $textBgX = $SR.Width - $textBgWidth
    $textBgY = $SR.Height - $textBgHeight
    $logoBgX = 
    $logoBgY = 

    $textBgRect = New-Object System.Drawing.RectangleF($textBgX, $textBgY, $textBgWidth, $textBgHeight)
    $image.FillRectangle($backBrush, $textBgRect)

    Write-Output $textBgRect >> "$wallpaperImageOutput\wallpaper.log"

    $i = 0
    $cumulativeHeight = $SR.Height - $taskbarOffset

    foreach ($h in $reversed.GetEnumerator()) {
        $valString = "$($h.Value)"
        $valFont = New-Object System.Drawing.Font($font, $size, [System.Drawing.FontStyle]::Regular)
        $valSize = [system.windows.forms.textrenderer]::MeasureText($valString, $valFont)

        $keyString = "$($h.Name): "
        $keyFont = New-Object System.Drawing.Font($font, $size, [System.Drawing.FontStyle]::Bold)
        $keySize = [system.windows.forms.textrenderer]::MeasureText($keyString, $keyFont)

        Write-Output $valString >> "$wallpaperImageOutput\wallpaper.log"
        Write-Output $keyString >> "$wallpaperImageOutput\wallpaper.log"

        $maxItemHeight = [math]::Max($valSize.Height, $keySize.Height) + $textItemSpace

        $valX = $SR.Width - $maxValWidth
        $valY = $cumulativeHeight - $maxItemHeight

        $keyX = $valX - $maxKeyWidth
        $keyY = $valY
        
        $valRect = New-Object System.Drawing.RectangleF($valX, $valY, $maxValWidth, $valSize.Height)
        $keyRect = New-Object System.Drawing.RectangleF($keyX, $keyY, $maxKeyWidth, $keySize.Height)

        $cumulativeHeight = $valRect.Top

        $image.DrawString($keyString, $keyFont, $foreBrush, $keyRect, $strFrmt)
        $image.DrawString($valString, $valFont, $foreBrush, $valRect, $strFrmt)

        $i++
    }

    #Add Logo    
    $logo = new-object system.drawing.bitmap -ArgumentList "$logoFile"
    $logoRect = New-Object System.Drawing.RectangleF(($SR.Width - $logoWidth - $logoPaddingRight), $logoPaddingTop, $logoWidth, $logoHeight)
    $image.DrawImage($logo, $logoRect)

    
    
    # Close Graphics
    $image.Dispose();

    # Save and close Bitmap
    $background.Save($out, [system.drawing.imaging.imageformat]::Png);
    $background.Dispose();
    $bmp.Dispose();

    # Output file
    Get-Item -Path $out
}

#TODO: there in't a better way to do this than inline C#?
Add-Type @"
using System.Runtime.InteropServices;

namespace Wallpaper
{
    public class Setter {
        public const int SetDesktopWallpaper = 20;
        public const int UpdateIniFile = 0x01;
        public const int SendWinIniChange = 0x02;

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);

        public static void UpdateWallpaper (string path)
        {
            SystemParametersInfo( SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange );
        }
    }
}
"@

Function Set-Wallpaper($Path) {
    #Set-ItemProperty -Path "HKCU:Control Panel\Desktop" -Name WallpaperStyle -Value 0
    #Set-ItemProperty -Path "HKCU:Control Panel\Desktop" -Name TileWallpaper -Value 0
    Set-ItemProperty -Path "HKCU:Control Panel\Desktop" -Name WallPaper -Value $Path
    Start-Sleep -Seconds 5 # Delay is necessary!
    [Wallpaper.Setter]::UpdateWallpaper($Path)
}




# execute tasks
Write-Output $o > "$wallpaperImageOutput\wallpaper.log"

# get random wallpaper from a folder full of images
Remove-Item -Force "$wallpaperImagesSource\current.jpg"
Get-ChildItem -Path "$wallpaperImagesSource\*" -Include *.* -Exclude current.jpg | Get-Random | Foreach-Object { Copy-Item -Path $_ -Destination "$wallpaperImagesSource\current.jpg" }

# create wallpaper image and save it in user profile
$WallPaper = New-ImageInfo -data $o -in "$wallpaperImagesSource\current.jpg" -out "$wallpaperImageOutput\wallpaper.png" -font $font -size $size -textPaddingLeft $textPaddingLeft -textPaddingTop $textPaddingTop -textItemSpace $textItemSpace
Write-Output $WallPaper.FullName >> "$wallpaperImageOutput\wallpaper.log"

# update wallpaper for logged in user
Set-Wallpaper -Path $WallPaper.FullName
