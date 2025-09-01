param(
    [string]$prefix,
    [string]$nvimexe
)

if ($prefix -eq "" -or $nvimexe -eq "") {
    Write-Host "You have to set the prefix and the nvimexe via -nvimexe and -prefix parameters. "
    Write-Host "Example: install.ps1 -prefix c:/Users/johndoe/azul -nvimexe c:/Users/johndoe/nvim-qt/nvim-qt.exe"
}
else {
    if (Test-Path "$prefix\azul.cmd") {
        Remove-Item "$prefix\azul.cmd"
    }
    echo "set AZUL_PREFIX=$prefix" | Out-File -FilePath "$prefix\azul.cmd" -Encoding ASCII
    echo "set AZUL_NVIM_EXE=$nvimexe" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding ASCII
    echo "set HOME=%AZUL_PREFIX%" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding ASCII
    echo "set XDG_CONFIG_HOME=%AZUL_PREFIX%\share\azul" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding ASCII
    echo "set XDG_DATA_HOME=%AZUL_PREFIX%\share\azul" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding ASCII
    echo "" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding ASCII
    echo "%AZUL_NVIM_EXE%" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding ASCII

    if (-not (Test-Path "$prefix\share")) {
        mkdir $prefix\share
            mkdir $prefix\share\azul
            mkdir $prefix\share\azul\nvim
    }
    if (-not (Test-Path "$prefix\.config")) {
        mkdir $prefix\.config
        mkdir $prefix\.config\azul
        mkdir $prefix\.config\azul\lua
        mkdir $prefix\.config\azul\pack
        mkdir $prefix\.config\azul\pack\start
        mkdir $prefix\.config\azul\pack\opt
    }
    xcopy .\nvim $prefix\share\azul\nvim /e /s /h

    if (-not (Test-Path "$prefix\.config\azul")) {
        copy .\examples\lua\*.* $prefix\.config\azul\lua\
        copy .\examples\azul.init $prefix\.config\azul\config.ini
    }

    if (-not (Test-Path "$prefix\.config\azul\pack\start\lualine.nvim")) {
        git clone https://github.com/nvim-lualine/lualine.nvim $prefix\.config\azul\pack\start\lualine.nvim
        cd $prefix\.config\azul\pack\start\lualine.nvim
        git checkout b431d228b7bbcdaea818bdc3e25b8cdbe861f056
    }
    if (-not (Test-Path "$prefix\.config\azul\pack\start\plenary.nvim")) {
        git clone https://github.com/nvim-lua/plenary.nvim $prefix\.config\azul\pack\start\plenary.nvim
        cd $prefix\.config\azul\pack\start\plenary.nvim
        git checkout 2d9b06177a975543726ce5c73fca176cedbffe9d
    }
    if (-not (Test-Path "$prefix\.config\azul\pack\start\telescope.nvim")) {
        git clone https://github.com/nvim-telescope/telescope.nvim $prefix\.config\azul\pack\start\telescope.nvim
        cd $prefix\.config\azul\pack\start\telescope.nvim
        git checkout eae0d8fbde590b0eaa2f9481948cd6fd7dd21656 
    }
    if (-not (Test-Path "$prefix\.config\azul\pack\start\dressing.nvim")) {
        git clone https://github.com/folke/snacks.nvim $prefix\.config\azul\pack\start\snacks.nvim
        cd $prefix\.config\azul\pack\start\snacks.nvim
        git checkout bc0630e43be5699bb94dadc302c0d21615421d93
    }
}
