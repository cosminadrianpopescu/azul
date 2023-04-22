#!/bin/bash

if [ "$AZUL_PREFIX" == "" ]
then
    export AZUL_PREFIX=$HOME/.local
fi

if [ "$AZUL_NVIM_EXE" == "" ]
then
    export AZUL_NVIM_EXE=nvim
fi

if [ ! -d $AZUL_PREFIX ]
then
    mkdir $AZUL_PREFIX
fi

if [ ! -d $AZUL_PREFIX/bin ]
then
    mkdir -p $AZUL_PREFIX/bin
fi

if [ ! -d $AZUL_PREFIX/share/azul ]
then
    mkdir -p $AZUL_PREFIX/share/azul
fi

if [ ! -d $AZUL_PREFIX/share/azul/nvim/lua ]
then
    mkdir -p $AZUL_PREFIX/share/azul/nvim/lua
fi

export AZUL_CONFIG="${XDG_CONFIG_HOME:-$HOME}/.config/azul"

printf "#!/bin/bash\n\nexport AZUL_PREFIX=$AZUL_PREFIX\nexport AZUL_NVIM_EXE=$AZUL_NVIM_EXE\n\n" > $AZUL_PREFIX/bin/azul
cat ./azul >> $AZUL_PREFIX/bin/azul
chmod 0755 $AZUL_PREFIX/bin/azul
cp ./nvim/lua/azul.lua $AZUL_PREFIX/share/azul/nvim/lua
cp ./nvim/init.lua $AZUL_PREFIX/share/azul/nvim

if [ ! -d $AZUL_CONFIG ]
then
    mkdir -p $AZUL_CONFIG

    if [ ! -d $AZUL_CONFIG/lua ]
    then
        mkdir -p $AZUL_CONFIG/lua
    fi

    if [ ! -d $AZUL_CONFIG/pack/start ]
    then
        mkdir -p $AZUL_CONFIG/pack/start
    fi

    git clone https://github.com/folke/tokyonight.nvim $AZUL_CONFIG/pack/start/tokyonight.nvim
    git clone https://github.com/nvim-lualine/lualine.nvim $AZUL_CONFIG/pack/start/lualine.nvim

    cp ./examples/lua/* $AZUL_CONFIG/lua/
    cp ./examples/tmux.lua $AZUL_CONFIG/init.lua
fi


echo "Installation done in $AZUL_PREFIX. Run azul"
