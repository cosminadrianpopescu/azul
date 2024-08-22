# Azul

A nvim based terminal multiplexer. 

### Demo (tldr)

* [Azul workflow](https://cloud.taid.be/s/rkLsbJpG8kNHPXq)
* [Tmux workflow](https://cloud.taid.be/s/6nsSz6bzmcaxnoz)
* [Zellij workflow](https://cloud.taid.be/s/rCTyPcFWnn3aNCS)
* [Nested session](https://cloud.taid.be/s/76i6pKnQzperH9r)

## Table of contents

* [Installation](#installation)
  - [Requirements](#requirements)
  - [Linux](#linux)
  - [Windows](#windows)
* [Launching](#launching)
* [Configuration](#configuration)
  - [Options](#options)
  - [Shortcuts](#shortcuts)
  - [Workflows](#workflows)
  - [Copy/Pasting](#copy/pasting)
* [Nested session](#nested-session)
* [Session restore](#session-restore)
* [Lua Api](#lua-api)
* [Why](#why)

## Installation

### Requirements

* `Neovim` >= 0.9

You can install `azul` in several ways.

### Linux

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
./install.sh
```

This will install azul inside the `~/.local` folder. Then, to run it, you
need to run `azul` if `~/.local/bin`, is in your path. Otherwise, you can run
directly `~/.local/bin/azul -a <session-name>`

To install it in a custom folder: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_PREFIX=~/programs/azul ./install.sh
```

This will install `azul` in the `~/programs/azul` folder. Then, to run it,
just run `~/programs/azul/bin/azul -a <session-name>`.

To install it in /usr/bin: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_PREFIX=/usr sudo ./install.sh
```

*NOTE*: In case your `nvim` executable is not `nvim`, you need to specify this
when installing by using the variable `AZUL_NVIM_EXE`. For example: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_NVIM_EXE=/opt/nvim.appimage ./install.sh
```

### Windows

To install azul in Windows:

```powershell
powershell.exe ./install.ps1 -prefix=c:/Users/johndoe/azul -nvimexe=c:/Users/johndoe/nvim-win64/bin/nvim-qt.exe
```

This will install azul inside `c:/Users/johndoe/azul` assuming that neovim is
installed in `c:/User/johndoe/nvim-win64`.

Then, to run it:
`c:/Users/johndoe/azul/azul.cmd`

## Launching

By running `~/.local/bin/azul` you will get a list of the current running azul
sessions. In order to start a new session, you need to run `~/.local/bin/azul
-a <session-name>`. This will attach to the session with the name
`<session-name>`, if it exists, or if not it will create a new session and
attach to it.

You can run `~/.local/bin/azul -a <session-name> -s '<keys>'`. This will send
the indicated keys to the current selected panel in the session `<session-name>`.

You can run `~/.local/bin/azul -h` to see the options of the `azul`. Once,
inside, you will notice a status bar and a new terminal will be started. 

## Configuration

Azul can be configured in several ways. For
[neovim](https://github.com/neovim/neovim) users, you can configure azul
directly via an init file places in `~/.config/azul/init.lua`. This will
expose the full power and all the configurations of azul. You can check the
api [here](./api.md)
