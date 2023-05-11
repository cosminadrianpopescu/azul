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

    mkdir $prefix\share
    mkdir $prefix\share\azul
    mkdir $prefix\share\azul\nvim
    mkdir $prefix\.config
    mkdir $prefix\.config\azul
    mkdir $prefix\.config\azul\lua
    mkdir $prefix\.config\azul\pack
    mkdir $prefix\.config\azul\pack\start
    mkdir $prefix\.config\azul\pack\opt
    xcopy .\nvim $prefix\share\azul\nvim /e /s /h
    copy .\examples\lua\*.* $prefix\.config\azul\lua\
    copy .\examples\azul.lua $prefix\.config\azul\init.lua

    git clone https://github.com/folke/tokyonight.nvim $prefix\.config\azul\pack\start\tokyonight.nvim
    git clone https://github.com/nvim-lualine/lualine.nvim $prefix\.config\azul\pack\start\lualine.nvim
    git clone https://github.com/folke/which-key.nvim $prefix\.config\azul\pack\start\which-key.nvim
}
