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
    echo "set AZUL_PREFIX=$prefix" | Out-File -FilePath "$prefix\azul.cmd" -Encoding utf8
    echo "set AZUL_NVIM_EXE=$nvimexe" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding utf8
    echo "set HOME=%AZUL_PREFIX%" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding utf8
    echo "set XDG_CONFIG_HOME=%AZUL_PREFIX%\share\azul" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding utf8
    echo "set XDG_DATA_HOME=%AZUL_PREFIX%\share\azul" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding utf8
    echo "" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding utf8
    echo "%AZUL_NVIM_EXE%" | Out-File -FilePath "$prefix\azul.cmd" -Append -Encoding utf8

    mkdir $prefix\share
    mkdir $prefix\share\azul
    xcopy .\nvim $prefix\share\azul /e /s /h
    copy .\examples\tmux.lua $prefix\init.lua
}
