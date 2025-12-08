#!/bin/bash

install_from_github() {
    if [ ! -d $VESPER_CONFIG/pack/start/$2 ]
    then
        git clone https://github.com/$1/$2 $VESPER_CONFIG/pack/start/$2
        # Fix the plugins versions
        cd $VESPER_CONFIG/pack/start/$2
        git checkout $3 &> /dev/null
    fi
}

if [ "$VESPER_DIR" == "" ]
then
    export VESPER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

if [ "$VESPER_PREFIX" == "" ]
then
    export VESPER_PREFIX=$HOME/.local
fi

if [ "$VESPER_ABDUCO_EXE" == "" ]
then
    export VESPER_ABDUCO_EXE="abduco"
fi

if [ "$VESPER_NVIM_EXE" == "" ]
then
    export VESPER_NVIM_EXE=nvim
fi

if [ ! -d $VESPER_PREFIX ]
then
    mkdir $VESPER_PREFIX
fi

if [ ! -d $VESPER_PREFIX/bin ]
then
    mkdir -p $VESPER_PREFIX/bin
fi

if [ ! -d $VESPER_PREFIX/share/vesper ]
then
    mkdir -p $VESPER_PREFIX/share/vesper
fi

if [ ! -d $VESPER_PREFIX/share/vesper/nvim/lua ]
then
    mkdir -p $VESPER_PREFIX/share/vesper/nvim/lua
fi

if [ "$VESPER_CONFIG" == "" ]
then
    export VESPER_CONFIG="${XDG_CONFIG_HOME:-$HOME}/.config/vesper"
fi

printf "#!/bin/bash\n\nexport VESPER_PREFIX=$VESPER_PREFIX\nexport VESPER_ABDUCO_EXE=$VESPER_ABDUCO_EXE\nexport VESPER_NVIM_EXE=$VESPER_NVIM_EXE\n\n" > $VESPER_PREFIX/bin/vesper
cat $VESPER_DIR/vesper >> $VESPER_PREFIX/bin/vesper

chmod 0755 $VESPER_PREFIX/bin/vesper
cp $VESPER_DIR/nvim/lua/theme.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/split.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/commands.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/files.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/cheatsheet.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/disabled-theme.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/config.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/vesper.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/select.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/functions.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/mappings.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/options.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/remote.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/insert.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/vim_ui.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/core.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/session.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/environment.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/history.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/events.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/undo.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/tab_vars.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/floats.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/welcome.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/lua/table-save.lua $VESPER_PREFIX/share/vesper/nvim/lua
cp $VESPER_DIR/nvim/init.lua $VESPER_PREFIX/share/vesper/nvim

if [ ! -d $VESPER_CONFIG ]
then
    mkdir -p $VESPER_CONFIG

    if [ ! -d $VESPER_CONFIG/lua ]
    then
        mkdir -p $VESPER_CONFIG/lua
    fi

    if [ ! -d $VESPER_CONFIG/pack/start ]
    then
        mkdir -p $VESPER_CONFIG/pack/start
    fi

    cp $VESPER_DIR/examples/lua/* $VESPER_CONFIG/lua/
    cp $VESPER_DIR/examples/vesper.ini $VESPER_CONFIG/config.ini
fi

install_from_github "nvim-lualine" "lualine.nvim" "b431d228b7bbcdaea818bdc3e25b8cdbe861f056"
install_from_github "nvim-lua" "plenary.nvim" "2d9b06177a975543726ce5c73fca176cedbffe9d"
install_from_github "nvim-telescope" "telescope.nvim" "eae0d8fbde590b0eaa2f9481948cd6fd7dd21656"

echo "Installation done in $VESPER_PREFIX. Run vesper"
