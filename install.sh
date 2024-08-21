#!/bin/bash

install_from_github() {
    if [ ! -d $AZUL_CONFIG/pack/start/$2 ]
    then
        git clone https://github.com/$1/$2 $AZUL_CONFIG/pack/start/$2
    fi
}

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
cp $AZUL_DIR/nvim/lua/theme.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/split.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/files.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/config.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/azul.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/sessions.lua $AZUL_PREFIX/share/azul/nvim/lua
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

    cp $AZUL_DIR/examples/lua/* $AZUL_CONFIG/lua/
    cp $AZUL_DIR/examples/azul.lua $AZUL_CONFIG/init.lua
fi

install_from_github "nvim-lualine" "lualine.nvim"
install_from_github "folke" "which-key.nvim"
install_from_github "nvim-lua" "plenary.nvim"
install_from_github "nvim-telescope" "telescope.nvim"
install_from_github "kwkarlwang" "bufresize.nvim"

echo "Installation done in $AZUL_PREFIX. Run azul"
