# PsBgInfo

Pure PowerShell BgInfo-like user & computer information on your desktop wallpaper

## How to use

* Add one or multiple wallpaper files to \Users\<Username>\Pictures\Wallpaper folder
* Upon script exection, one of these wallpaper files will be picked randomly
* Modify `Config` section in PsBgInfo.ps1 to adapt overlay color, font color, typeface, logo
* Use PsWrapper.vbs to run script without displaying PowerShell window:

  `` wscript.exe \path\to\PsBgInfo\PsWrapper.vbs \path\to\PsBgInfo\PsBgInfo.ps1 ``


## Credits

* https://github.com/brsh/brshSysInfo
* https://gist.github.com/dieseltravis/3066def0ddaf7a8a0b6d and 
