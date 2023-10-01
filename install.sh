#!/bin/bash

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
cat ./azul >> $AZUL_PREFIX/bin/azul
chmod 0755 $AZUL_PREFIX/bin/azul
cp ./nvim/lua/azul.lua $AZUL_PREFIX/share/azul/nvim/lua
cp ./nvim/lua/sessions.lua $AZUL_PREFIX/share/azul/nvim/lua
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

    cp ./examples/lua/* $AZUL_CONFIG/lua/
    cp ./examples/azul.lua $AZUL_CONFIG/init.lua
fi

if [ ! -d $AZUL_CONFIG/pack/start/tokyonight.nvim ]
then
    git clone https://github.com/folke/tokyonight.nvim $AZUL_CONFIG/pack/start/tokyonight.nvim
fi

if [ ! -d $AZUL_CONFIG/pack/start/lualine.nvim ]
then
    git clone https://github.com/nvim-lualine/lualine.nvim $AZUL_CONFIG/pack/start/lualine.nvim
fi


if [ ! -d $AZUL_CONFIG/pack/start/which-key.nvim ]
then
    git clone https://github.com/folke/which-key.nvim $AZUL_CONFIG/pack/start/which-key.nvim
fi

if [ ! -d $AZUL_CONFIG/pack/start/plenary.nvim ]
then
    git clone https://github.com/nvim-lua/plenary.nvim $AZUL_CONFIG/pack/start/plenary.nvim
fi

if [ ! -d $AZUL_CONFIG/pack/start/telescope.nvim ]
then
    git clone https://github.com/nvim-telescope/telescope.nvim $AZUL_CONFIG/pack/start/telecope.nvim
fi

echo "Installation done in $AZUL_PREFIX. Run azul"
