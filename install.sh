#!/bin/bash

install_from_github() {
    if [ ! -d $AZUL_CONFIG/pack/start/$2 ]
    then
        git clone https://github.com/$1/$2 $AZUL_CONFIG/pack/start/$2
        # Fix the plugins versions
        cd $AZUL_CONFIG/pack/start/$2
        git checkout $3 &> /dev/null
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

if [ "$AZUL_CONFIG" == "" ]
then
    export AZUL_CONFIG="${XDG_CONFIG_HOME:-$HOME}/.config/azul"
fi

printf "#!/bin/bash\n\nexport AZUL_PREFIX=$AZUL_PREFIX\nexport AZUL_ABDUCO_EXE=$AZUL_ABDUCO_EXE\nexport AZUL_NVIM_EXE=$AZUL_NVIM_EXE\n\n" > $AZUL_PREFIX/bin/azul
cat $AZUL_DIR/azul >> $AZUL_PREFIX/bin/azul

chmod 0755 $AZUL_PREFIX/bin/azul
cp $AZUL_DIR/nvim/lua/theme.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/split.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/commands.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/files.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/cheatsheet.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/disabled-theme.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/config.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/azul.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/select.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/functions.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/mappings.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/options.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/remote.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/insert.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/vim_ui.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/core.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/session.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/environment.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/history.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/events.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/undo.lua $AZUL_PREFIX/share/azul/nvim/lua
cp $AZUL_DIR/nvim/lua/tab_vars.lua $AZUL_PREFIX/share/azul/nvim/lua
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
    cp $AZUL_DIR/examples/azul.ini $AZUL_CONFIG/config.ini
fi

install_from_github "nvim-lualine" "lualine.nvim" "b431d228b7bbcdaea818bdc3e25b8cdbe861f056"
install_from_github "nvim-lua" "plenary.nvim" "2d9b06177a975543726ce5c73fca176cedbffe9d"
install_from_github "nvim-telescope" "telescope.nvim" "eae0d8fbde590b0eaa2f9481948cd6fd7dd21656"

echo "Installation done in $AZUL_PREFIX. Run azul"
