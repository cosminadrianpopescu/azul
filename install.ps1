param(
    [string]$prefix,
    [string]$nvimexe
)

if ($prefix -eq "" -or $nvimexe -eq "") {
    Write-Host "You have to set the prefix and the nvimexe via -nvimexe and -prefix parameters. "
    Write-Host "Example: install.ps1 -prefix c:/Users/johndoe/vesper -nvimexe c:/Users/johndoe/nvim-qt/nvim-qt.exe"
}
else {
    if (Test-Path "$prefix\vesper.cmd") {
        Remove-Item "$prefix\vesper.cmd"
    }
    echo "set VESPER_PREFIX=$prefix" | Out-File -FilePath "$prefix\vesper.cmd" -Encoding ASCII
    echo "set VESPER_NVIM_EXE=$nvimexe" | Out-File -FilePath "$prefix\vesper.cmd" -Append -Encoding ASCII
    echo "set HOME=%VESPER_PREFIX%" | Out-File -FilePath "$prefix\vesper.cmd" -Append -Encoding ASCII
    echo "set XDG_CONFIG_HOME=%VESPER_PREFIX%\share\vesper" | Out-File -FilePath "$prefix\vesper.cmd" -Append -Encoding ASCII
    echo "set XDG_DATA_HOME=%VESPER_PREFIX%\share\vesper" | Out-File -FilePath "$prefix\vesper.cmd" -Append -Encoding ASCII
    echo "" | Out-File -FilePath "$prefix\vesper.cmd" -Append -Encoding ASCII
    echo "%VESPER_NVIM_EXE%" | Out-File -FilePath "$prefix\vesper.cmd" -Append -Encoding ASCII

    if (-not (Test-Path "$prefix\share")) {
        mkdir $prefix\share
            mkdir $prefix\share\vesper
            mkdir $prefix\share\vesper\nvim
    }
    if (-not (Test-Path "$prefix\.config")) {
        mkdir $prefix\.config
        mkdir $prefix\.config\vesper
        mkdir $prefix\.config\vesper\provider-configs
        mkdir $prefix\.config\vesper\lua
        mkdir $prefix\.config\vesper\pack
        mkdir $prefix\.config\vesper\pack\start
        mkdir $prefix\.config\vesper\pack\opt
    }
    xcopy .\nvim $prefix\share\vesper\nvim /e /s /h

    if (-not (Test-Path "$prefix\.config\vesper")) {
        copy .\examples\lua\*.* $prefix\.config\vesper\lua\
        copy .\examples\vesper.init $prefix\.config\vesper\config.ini
    }

    if (-not (Test-Path "$prefix\.config\vesper\pack\start\lualine.nvim")) {
        git clone https://github.com/nvim-lualine/lualine.nvim $prefix\.config\vesper\pack\start\lualine.nvim
        cd $prefix\.config\vesper\pack\start\lualine.nvim
        git checkout b431d228b7bbcdaea818bdc3e25b8cdbe861f056
    }
    if (-not (Test-Path "$prefix\.config\vesper\pack\start\plenary.nvim")) {
        git clone https://github.com/nvim-lua/plenary.nvim $prefix\.config\vesper\pack\start\plenary.nvim
        cd $prefix\.config\vesper\pack\start\plenary.nvim
        git checkout b9fd5226c2f76c951fc8ed5923d85e4de065e509
    }
    if (-not (Test-Path "$prefix\.config\vesper\pack\start\telescope.nvim")) {
        git clone https://github.com/nvim-telescope/telescope.nvim $prefix\.config\vesper\pack\start\telescope.nvim
        cd $prefix\.config\vesper\pack\start\telescope.nvim
        git checkout 3333a52ff548ba0a68af6d8da1e54f9cd96e9179 
    }
}
