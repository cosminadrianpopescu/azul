#!/bin/bash

if [ "$AZUL_DIR" == "" ]
then
    export AZUL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

if [ "$AZUL_PREFIX" == "" ]
then
    export AZUL_PREFIX=$HOME/.local
fi

if [ "$AZUL_ABDUCO_EXE" == "" ]
then
    export AZUL_ABDUCO_EXE="abduco"
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

printf "#!/bin/bash\n\nexport AZUL_PREFIX=$AZUL_PREFIX\nexport AZUL_ABDUCO_EXE=$AZUL_ABDUCO_EXE\nexport AZUL_NVIM_EXE=$AZUL_NVIM_EXE\n\n" > $AZUL_PREFIX/bin/azul
cat $AZUL_DIR/azul >> $AZUL_PREFIX/bin/azul
chmod 0755 $AZUL_PREFIX/bin/azul
cp $AZUL_DIR/nvim/lua/azul.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/init.lua $AZUL_PREFIX/share/azul/nvim

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
    git clone https://github.com/folke/which-key.nvim $AZUL_CONFIG/pack/start/which-key.nvim
    git clone https://github.com/nvim-lua/plenary.nvim $AZUL_CONFIG/pack/start/plenary.nvim
    git clone https://github.com/nvim-telescope/telescope.nvim $AZUL_CONFIG/pack/start/telecope.nvim

    cp $AZUL_DIR/examples/lua/* $AZUL_CONFIG/lua/
    cp $AZUL_DIR/examples/azul.lua $AZUL_CONFIG/init.lua
fi


echo "Installation done in $AZUL_PREFIX. Run azul"
