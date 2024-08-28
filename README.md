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
* [Terminology](#terminology)
  - [Tabs](#tabs)
  - [Panes](#panes)
  - [Floats](#floats)
* [Workflows](#workflows)
  - [Modes](#modes)
  - [Modifiers](#modifiers)
  - [Emacs workflow](#emacs-workflow)
  - [Zellij workflow](#zellij-workflow)
  - [Tmux workflow](#tmux-workflow)
  - [Azul workflow](#azul-workflow)
* [Mouse support](#mouse-support)
* [Commands](#commands)
  - [Possible commands](#possible-commands)
* [Configuration](#configuration)
  - [Options](#options)
  - [Shortcuts](#shortcuts)
    + [Possible actions](#possible-actions)
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
the indicated keys to the current selected pane in the session `<session-name>`.

You can run `~/.local/bin/azul -h` to see the options of the `azul`. Once,
inside, you will notice a status bar and a new terminal will be started. 

## Terminology

`Azul` uses the following terminology: tabs, panes and floats

### Tabs

A tab is a currently opened environment. You will see the tabs in the bottom
left of the status bar when starting the app with the default configuration.

A newly created tab will contain a pane that will occupy all the available
space. A pane occupying all the space in a tab cannot be resized or moved. The
pane is actually your shell program waiting for commands or executting a
command at any given time.

A tab can contain one or several embeded panes or floating panes.

### Panes

The pane is the backbone of `azul`. Each pane contains a running shell (for
example `/bin/bash` for a `linux` environment). 

You can add another pane in a tab by changing to `SPLIT` mode (for example, for
`azul` workflow, pressing `<C-s>s`, see [Workflows](#workflows)) and splitting
to left, right, top or bottom (for `azul` workflow, in `SPLIT` mode, clicking
on the cursors).

Other then the embeded tabs, you can also have floating panes.

### Floats

A floating pane is a pane which is extracted from the current tab and
displayed on top of the current tab. The floating panes can be shown or
hidden.

If the option `link_floats_with_tabs` is set to `true`, then each tab will have
it's own set of floating panes. Creating a floating pane on the tab 1, for
example will not make it visible on the second tab.

If the option `link_floats_with_tabs` is set to `false` (the default), then
when a floating pane is created, it will be accessible from any of the tabs.

Floating panes are usefull and recommended for short quick jobs and can be
discarded once the job is finished.

## Workflows

`Azul` can be used in 4 ways, depending on your preferences: `tmux` way,
`zellij` way, `emacs` way or `azul` way. Each of this way of using `azul` has
it's own shortcuts, modes and delimiter. The shortcuts, together with the
delimiter and the modes are called an workflow.

### Modes

The `tmux`, `zellij` and `azul` workflows, have multiple modes.

Like in `vim`, a mode is a certain way of interacting with the app. For
example, in `PANE RESIZE` mode, pressing `h`, `j`, `k` and `l` will resize the
currently selected pane, in `FLOAT MOVE` mode, same keys will move the
currently selected pane while in `TERMINAL` mode, the keys will be sent you
your shell intepreter. The default mode when you start the app is `TERMINAL`
mode. In `TERMINAL` mode, every key you send is sent automatically to the
shell (`/bin/bash` for `linux` environments).

The possible modes are:
  * `TERMINAL` (all your keys are sent to your shell)
  * `VISUAL` (moving the cursor in the terminal buffer will modify the current
    selection)
  * `PANE SELECT` (you can change the currently selected pane)
  * `FLOAT MOVE` (you can move the currently selected float pane)
  * `PANE RESIZE` (you can resize the currently selected pane)
  * `SPLIT` (you can add new splits in the currently selected tab)
  * `TABS` (you can change the currently selected tab or add a new one)
  * `AZUL`.

The `AZUL` mode is a special mode in which you interact automatically with
`azul`, rather than the currently selected shell.

In `AZUL` mode, clicking on cursors or on `<pgup>`, `<pgdown>` will navigate
in the scroll buffer (all the output that your current shell generated).

From `AZUL` mode you can switch to `VISUAL` mode (by clicking `v`), that will
start a selection, that can be extended by using the cursors, or `<pgup>` and
`<pgdown>`.

In `AZUL` mode you can also communicate with `azul` directly by sending it
commands. You can click on `:` and a prompt will appear on top of the status
bar. If you type `Azul` (notice the capital `A`) and then you click `tab`, you
will see a list of all the possible commands you can send to `azul`. For more
info and for a description of each command, see the [Commands
section](#commands).

To return from `AZUL` mode to `TERMINAL` mode, you can click on `i` or
`<ins>`.

The `TERMINAL` mode is the mode in which you start `azul` by default. In
`TERMINAL` mode, all your keys are sent to your current shell. 

The current mode is indicated in the left bottom side of your status bar.

### Modifiers

For `tmux` and `azul` workflows, there is also a modifier. A modifier is a key
combination that can be set via the `delimiter` option (default `<C-s>`) that
when pressed in `TERMINAL` mode has a special meaning, depending on the
workflow. This combination will not be sent automatically to your shell, even
when in `TERMINAL` mode.

With a `tmux` workflow, the modifier will automatically put `azul` in `AZUL`
mode. The next key will be sent to azul, instead of your terminal. You can
click `i` or `<ins>` if you change your mind and you want to get back to
`TERMINAL` mode, or you can press for example `p` to switch to `PANE SELECT`
mode.

With an `azul` workflow, the modifier will show you the next possible keys on
the bottom of the page, but will stay in `TERMINAL` mode. If the next key is
an `azul` shortcut, then an `azul` command will be executed. If no, then both
keys (the modifier and the following key) will be sent to the current shell.

### Emacs workflow

In this workflow, there are no modes and no modifiers. You are always inside
the `TERMINAL` mode. If you want to access `azul` special functions (like
opening a float), you have to click certain shortcuts prefixed by a standard
modifier (`ctrl` or `alt`). For example, to open a new float, you need to
click on `<a-f>`. For a full list of shortcuts for this workflow, check the
`examples/emacs-config.ini` file.

### Zellij workflow

In this workflow, there are modes, but there is no modifier. You will mostly
be in `TERMINAL`, `AZUL` or the custom `azul` modes (`PANE SELECT`, `PANE
RESIZE`, `MOVE`, `SPLIT` or `TABS`). To switch in a another mode, you have
standard shortcuts prefixed by a standard delimiter (`ctrl` or `alt`). For
example, to change to `TABS` mode, you can click `<C-S-t>`. For a full list of
shortcuts for this workflow, chek the `examples/zellij-config.ini` file.

### Tmux workflow

In this workflow, you have modes and you also have a modifier. This means,
that by default you are in `TERMINAL` mode and all your keys are sent to your
`bash` interpreter (or `cmd` for windows). Whenever you want to interact with
`azul`, you need to press your modifier (by default `<C-s>`). This will put
`azul` from `TERMINAL` mode in `AZUL` mode. Now, your key presses will be
sent to `azul`, instead of your `bash` interpreter, just like with `tmux`.

### Azul workflow

This is the default workflow. After installation, if you don't modify your
configuration, when you will start `azul`, you will find yourself in the
`azul` workflow. This workflow is a combination of all the previous workflows.
You are all the time in the `TERMINAL` mode, you have a modifier (default
`<C-s>`) and you have modes. 

Unlike `tmux` workflow, when you click the modifier `azul` will remain in
`TERMINAL` mode, but will wait for the next key and is going to interpret it
like an `azul` command. If you wait for 300 ms, then you will also have a help
indicating what are the possible commands that you can send to `azul`.

## Mouse support

In `azul`, you can also use the mouse. By default, you can select with the
mouse and you can also move the cursor, which will modify the selection. To
disable the mouse, set the mouse option to noting. Either in your `config.ini`
file in the options section (`mouse = `) or in your `init.lua` file
(`vim.o.mouse = ""`). The default value is `a`. If you want to see the meaning
and possible values, you can check
[here](https://neovim.io/doc/user/options.html#'mouse').

## Commands

You can communicate directly with azul from `AZUL` mode, by clicking `:`
(while in `AZUL` mode). This will open a prompt on top of the status bar.
There, you can type one of the possible commands and then click `enter`.
`Azul` will execute the command and then return in `TERMINAL` mode or stay in
`AZUL` mode, depending on the command requested. 

Some of the commands can take parameters. For example, `AzulSelectPane` will
take as a parameter the direction in which to select the next pane (left,
right, up or down). The parameters are separated by spaces. For example, to
select the next pane to the left, in `AZUL` mode, you need to click the
following: `:AzulSelectPane left<cr>` (the `<cr>` represents `enter`).

### Possible commands

#### AzulHideFloats

Hiddens all the floats. 

**Parameters**: none

#### AzulOpen

Opens a new tab with a new shell. 

**Parameters**: none

#### AzulEnterMode

Puts `azul` in the requested mode. 

**Parameters**:

* the mode (p or r or s or m or T or n or t or v)

#### AzulShowFloats

Shows the currently opened floats. If no floats is created yet, then nothing
will be shown. If the option `link_floats_with_tabs` is true, then it shows
the currently opened floats on the current tab.

**Parameters**: none

#### AzulOpenFloat

Creates a new float on the current tab. If the option `link_floats_with_tabs`
is set to `true`, then this float will only be visible on the currently
selected tab.

**Parameters**: none

#### AzulToggleFloats

Toggles the opened floats visibility. If `link_floats_with_tabs` is true, then
it toggles the visibility of opened floats for the current tab.

**Parameters**: none

#### AzulMoveCurrentFloat

Moves the currently selected float in the given direction with the given
increment.

**Parameters**:

* direction (left, right, up or down) - mandatory
* increment (number) - optional. If missing, then the float will be moved by 5
  pixels

#### AzulSelectPane

Selects the next pane in the indicated direction

**Parameters**: 

* direction (left, right, up or down)

#### AzulSendToCurrentPane

Sends the indicated text to the currently selected pane. This commands accepts
after it a `!` symbol. This means that the characters will be escaped. 

For example: 

`:AzulSendToCurrentPane ls -al<cr>` will send to the current pane the literal
text `ls -al<cr>`. The `<cr>` will not be replaced by an `enter`.

`:AzulSendToCurrentPane! ls -al<cr>` will send to the current pane the text
`ls -al` followed by an enter (notice the exclamation marc after the command)

**Parameters**:

* the text to send to the currently selected pane

#### AzulToggleNestedSession

Toggles the state of the session. If the session is nested, then the control
is given back to the current session, while if the current session has the
control, then the controll will be passed to the guest session. For more info
see the [Nested session section](#nested-section).

**Parameters**:

* the escape control sequence (optional, default `<C-\><C-s>`)

#### AzulPositionCurrentFloat

Positions the currently selected floating pane in a region of the screen. 

**Parameters**:

* the screen region where to position the float (top, bottom, start or end)

#### AzulRedraw

Redraws the terminal

**Parameters**: none

#### AzulSuspend

Suspends all the `azul` events. This is an usefull command for advanced users
who might want to open something in an underlying `nvim` buffer. Normally,
that something would be overriten by a new shell. In order to prevent this,
you can suspend the `azul` events, finish your job and then resume the `azul`
events.

**Parameters**: none

#### AzulResume

Resumes the `azul` events. This is an usefull command for advanced users
who might want to open something in an underlying `nvim` buffer. Normally,
that something would be overriten by a new shell. In order to prevent this,
you can suspend the `azul` events, finish your job and then resume the `azul`
events.

**Parameters**: none

#### AzulDisconnect

Disconnects the current session

**Parameters**: none

#### AzulSaveLayout

Saves the current layout. Uppon invoking this command, you will be met with a
prompt at the bottom of the screen, on top of the status bar, to indicate a
file name where you wish to save your layout. You can type a full path to a
file, using `tab` for autocompletion.

`Azul` has very powerfull features for saving and restoring saved sessions.
See the [Session restore section](#session-restore)

**Parameters**: none

#### AzulRestoreLayout

Restores a saved layout. Uppon invoking this command, you will be met with a
prompt at the bottom of the screen, on top of the status bar, to indicate a
file name where you wish to save your layout. You can type a full path to a
file, using `tab` for autocompletion.

`Azul` has very powerfull features for saving and restoring saved sessions.
See the [Session restore section](#session-restore)

#### AzulSetWinId

Sets an azul windows id for the currently selected pane. See the [Session
restore section](#session-restore) for why you would set and how you would use
this id

**Parameters**:

* the id of the pane

#### AzulSetCmd

Sets a command to be launched uppon a restore. For more info, see the [Session
restore section](#session-restore).

**Parameters**:

* the command to be launched uppon a restore

## Configuration

Azul can be configured in several ways. For
[neovim](https://github.com/neovim/neovim) users, you can configure azul
directly via an init file placed in `~/.config/azul/init.lua`. This will
expose the full power and all the configurations of azul. You can check the
`azul` api [here](./api.md).

You have examples of configuration for each workflow inside the `examples/`
folder (for example, `examples/azul.lua`). You can get any of the example
files, corresponding to each of the possible workflows, rename it to
`init.lua` and copy it to `~/.config/azul` folder.

If you don't need to access the full power of `neovim` or you are not familiar
with `lua` or `neovim`, you can configure azul via a simple `ini` file format.
The file should be placed in `~/.config/azul/config.ini`.

The ini file format is a classical `ini` format. Each option or shortcut
should be on one line separated by an equal. The left side will be the option
and the right side the value. 

In case of shortcuts, the left side should contain the mode, followed by a dot
and then followed by the action (for an workflow other than `emacs` workflow)
or the action directly, for the `emacs` workflow. For more info see the
[Shortcuts section](#shortcuts)

### Options

* **workflow** - The current workflow (default `azul`)
* **modifier** - The default modified (default `<C-s>`)
* **link_floats_with_tabs** - If true, then the floats opened in a tab, are
  displayed only in that tab. Otherwise, the floats will be displayed over all
  the tabs (default `false`)
* **shell** - The default shell (default is given by your operating system)
* **mouse** - The mouse support settings (default `a`)
* **theme** - The status line theme (default `dracula`). You can see a list of
  all the possible themes
  [here](https://github.com/nvim-lualine/lualine.nvim/blob/master/THEMES.md)
* **termguicolors** - If true, then the 24-bit RGB colors are activated
  (default `true`). For more info, see
  [here](https://neovim.io/doc/user/options.html#'termguicolors')
* **scrollback** - The number of lines saved in the scroll history. The more
  lines, the bigger the memory consumption of `azul` (default 2000)
* **clipboard** - The clipboard settings (default `unnamedplus`). For more
  info, see [Copy/pasting section](#copy/pasting)
* **encoding** - The default encoding of the terminal (default `utf-8`)

### Shortcuts

`Azul` can use any shortcuts that `vim` can use. As a notation, to set up a
`ctrl`, `alt` of `shift` shortcut, you need to enclose the shortcut between
`<` and `>`. So, for example, to set a `ctrl` + `s` shortcut, you would
define it as `<C-s>`. You can see the example files inside the `examples`
folder.

In the `ini` file, each shortcut will be defined on a row. For `azul`, `tmux`
or `zellij` workflows, the shortcuts are defined starting with the mode,
followed by a dot and then followed by a possible action.

For example, to set the `create_tab` action in `TABS` mode to the letter `c`,
you need to add this to your ini file in the `Shortcuts` section:
`tabs.create_tab = c`.

If you want for example for `emacs` workflow to set up the same action to
`alt` + `w`, you need to add this in your ini file: `create_tab = <a-w>`.

Some of the actions, will expect a parameter (for example `tab_select`). For
such actions (that expect a parameter), after the action, you need to add
another dot and then the value of the parameter. 

For example, for `tab_select` action, which expects the number of tab that you
want to select, you need to add the following in your init file. 

For an workflow other than `emacs`: `terminal.tab_select.1 = 1`.

For an `emacs` workflow: `tab_select.1 = <C-1>`.

#### Possible actions
