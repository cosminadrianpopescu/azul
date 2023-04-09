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

printf "#!/bin/bash\n\nexport AZUL_PREFIX=$AZUL_PREFIX\nexport AZUL_NVIM_EXE=$AZUL_NVIM_EXE\n\n" > $AZUL_PREFIX/bin/azul
cat ./azul >> $AZUL_PREFIX/bin/azul
chmod 0755 $AZUL_PREFIX/bin/azul
cp ./nvim/lua/azul.lua $AZUL_PREFIX/share/azul/nvim/lua
cp ./nvim/init.lua $AZUL_PREFIX/share/azul/nvim

echo "Installation done in $AZUL_PREFIX. Run azul"