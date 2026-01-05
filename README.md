# Vesper 
A nvim based terminal multiplexer. 

### Demo (tldr)

* [Vesper workflow](https://cloud.taid.be/s/rkLsbJpG8kNHPXq)
* [Tmux workflow](https://cloud.taid.be/s/6nsSz6bzmcaxnoz)
* [Zellij workflow](https://cloud.taid.be/s/rCTyPcFWnn3aNCS)
* [Passthorough mode](https://cloud.taid.be/s/76i6pKnQzperH9r)

## Table of contents

* [Installation](#installation)
  - [Requirements](#requirements)
  - [Linux](#linux)
  - [Windows](#windows)
* [Launching](#launching)
* [Advantages over tmux or zellij](#advantages-over-tmux-or-zellij)
* [Disadvantages compared with tmux or zellij](#disadvantages-compared-with-tmux-or-zellij)
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
  - [Vesper workflow](#vesper-workflow)
* [Mouse support](#mouse-support)
* [Commands](#commands)
  - [Possible commands](#possible-commands)
* [Configuration](#configuration)
  - [Options](#options)
  - [Shortcuts](#shortcuts)
    + [Possible actions](#possible-actions)
  - [Environment](#environment)
    + [Via ini file](via-ini-file)
    + [Via lua file](via-lua-file)
  - [Copy/Pasting](#copypasting)
* [Remote panes](#remote-panes)
  - [Closing a remote pane](#closing-a-remote-pane)
  - [Scrolling](#scrolling)
  - [Remote providers](#remote-providers)
* [Passthrough mode](#passthrough-mode)
* [Session support](#session-support)
  - [VesperSetCmd](#vespersetcmd)
  - [VesperSetWinId](#vespersetwinid)
  - [Autosave](#autosave)
* [Undo](#undo)
* [Lua Api](#lua-api)
* [Why](#why)
* [Vesper workflow cheatsheet](#cheatsheet)

## Installation

### Requirements

* `Neovim` >= 0.11

You can install `vesper` in several ways.

### Linux

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd vesper
./install.sh
```

This will install vesper inside the `~/.local` folder. Then, to run it, you
need to run `vesper` if `~/.local/bin`, is in your path. Otherwise, you can run
directly `~/.local/bin/vesper -a <session-name>`

To install it in a custom folder: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd vesper
VESPER_PREFIX=~/programs/vesper ./install.sh
```

This will install `vesper` in the `~/programs/vesper` folder. Then, to run it,
just run `~/programs/vesper/bin/vesper -a <session-name>`.

To install it in /usr/bin: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd vesper
VESPER_PREFIX=/usr sudo ./install.sh
```

*NOTE*: In case your `nvim` executable is not `nvim`, you need to specify this
when installing by using the variable `VESPER_NVIM_EXE`. For example: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd vesper
VESPER_NVIM_EXE=/opt/nvim.appimage ./install.sh
```

By setting the `VESPER_CONFIG` variable during the install folder, you can
indicate where you want the config to be installed for the first time.
However, not that then `vesper` will not be ran with that config. It will still
search in `~/.config/vesper` folder. In order to consider the new folder, you'll
need to use the `-c` start option when running `vesper`.

```bash
VESPER_CONFIG=/home/.vesper ./install.sh
```

After this, in order to run it with the new config, you need to do:

```bash
~/.local/bin/vesper -c /home/.vesper -a my-session
```

### Windows

To install vesper in Windows:

```powershell
powershell.exe ./install.ps1 -prefix=c:/Users/johndoe/vesper -nvimexe=c:/Users/johndoe/nvim-win64/bin/nvim-qt.exe
```

This will install vesper inside `c:/Users/johndoe/vesper` assuming that neovim is
installed in `c:/User/johndoe/nvim-win64`.

Then, to run it:
`c:/Users/johndoe/vesper/vesper.cmd`

## Launching

By running `~/.local/bin/vesper` you will get a list of the current running vesper
sessions. In order to start a new session, you need to run `~/.local/bin/vesper
-a <session-name>`. This will attach to the session with the name
`<session-name>`, if it exists, or if not it will create a new session and
attach to it.

You can run `~/.local/bin/vesper -a <session-name> -s '<keys>'`. This will send
the indicated keys to the current selected pane in the session `<session-name>`.

You can run `~/.local/bin/vesper -h` to see the options of `vesper`. Once,
inside, you will notice a status bar and a new terminal will be started. 

## Advantages over tmux or zellij

### Status bar or tabline

You are inside neovim. So, you can use any plugin you want to handle the
status bar or the tabline, you can have both, you can have none, the sky (or
should I say neovim) is the limit. My status bar that you saw in the demo
video is using [lualine](https://github.com/nvim-lualine/lualine.nvim) with a
minimal configuration that you can find in the `examples` folder. But you can
choose whatever you like.

### Very flexibile shortcuts

Again, you are in neovim. You can have whatever shortcuts neovim supports. You
can have these shortcuts inside command mode, inside terminal mode (so inside
the real terminal), in normal mode, in visual mode, you name it...

### Remote panes

You can have panes (embedded or floating) that are connected remotely to a
server via ssh. For example, first tab represents a shell on your local
machine, second tab the same, while the third tab can open a shell on a remote
machine via ssh. and the fourth tab can be another remote shell on yet another
machine. See the [Remote panes section](#remote-panes) for how this works.

### Passthrough mode

As you seen in the video, you can connect to a ssh session, press a shortcut
(in my case `<C-s>N`) and then all the keys are passed to the nested session.
To pass the control back, you press the escape shortcut `<C-\><C-s>` (this is
the default, but you can set your own) and you control again the main session.
Very neat...

### Native on windows

Check out the `install.ps1` script. You can install neovim on windows, and
then run the `install.ps1` script like this:

```powershell
install.ps1 -prefix c:/Users/johndoe/vesper -nvimexe c:/Users/johndoe/nvim-qt/nvim-qt.exe
```

Make sure the folder from the `prefix` parameter exists. Then you can run
`c:/Users/johndoe/vesper/vesper.cmd`.

I think that this is the only native windows terminal multiplexer (not
considering tmux or screen or others running under cygwin).

## Disadvantages compared with tmux or zellij

### Text reflow

At the moment, `neovim` supports limited text reflow of the terminals. See
[here](https://github.com/neovim/neovim/issues/2514). You can reflow the
current terminal, but only the current view (not the scrollback buffer). We'll
have to wait for this issue to be closed and then `vesper` will also have proper
text reflow.

## Terminology

`Vesper` uses the following terminology: tabs, panes and floats

### Tabs

A tab is a currently opened environment. You will see the tabs in the bottom
left of the status bar when starting the app with the default configuration.

A newly created tab will contain a pane that will occupy all the available
space. A pane occupying all the space in a tab cannot be resized or moved. The
pane is actually your shell program waiting for commands or executting a
command at any given time.

A tab can contain one or several embeded panes or floating panes.

### Panes

The pane is the backbone of `vesper`. Each pane contains a running shell (for
example `/bin/bash` for a `linux` environment). 

You can add another pane in a tab by changing to `SPLIT` mode (for example, for
`vesper` workflow, pressing `<C-s>s`, see [Workflows](#workflows)) and splitting
to left, right, top or bottom (for `vesper` workflow, in `SPLIT` mode, clicking
on the cursors).

Other than the embeded panes, you can also have floating panes.

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

`Vesper` can be used in 4 ways, depending on your preferences: `tmux` way,
`zellij` way, `emacs` way or `vesper` way. Each of this way of using `vesper` has
it's own shortcuts, modes and delimiter. The shortcuts, together with the
delimiter and the modes are called an workflow.

### Modes

The `tmux`, `zellij` and `vesper` workflows, have multiple modes.

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
  * `MODIFIER` (used for mappings for the first action after the modifier is
    pressed for `tmux` and `vesper` workflows)
    * `VESPER`.

The `VESPER` mode is a special mode in which you interact automatically with
`vesper`, rather than the currently selected shell.

In `VESPER` mode, clicking on cursors or on `<pgup>`, `<pgdown>` will navigate
in the scroll buffer (all the output that your current shell generated).

From `VESPER` mode you can switch to `VISUAL` mode (by clicking `v`), that will
start a selection, that can be extended by using the cursors, or `<pgup>` and
`<pgdown>`.

In `VESPER` mode you can also communicate with `vesper` directly by sending it
commands. You can click on `:` and a prompt will appear on top of the status
bar. If you type `Vesper` (notice the capital `A`) and then you click `tab`, you
will see a list of all the possible commands you can send to `vesper`. For more
info and for a description of each command, see the [Commands
section](#commands).

To return from `VESPER` mode to `TERMINAL` mode, you can click on `i` or
`<ins>`.

The `TERMINAL` mode is the mode in which you start `vesper` by default. In
`TERMINAL` mode, all your keys are sent to your current shell. 

The current mode is indicated in the left bottom side of your status bar.

The `MODIFIER` mode is a special mode also, in which `vesper` waits for the next
keys combination in order to select an action to execute. For `vesper` and
`tmux` workflows, when you press the modifier (`<C-s>` by default), vesper will
then wait in this mode for the next key combination or for cancel.

### Modifiers

For `tmux` and `vesper` workflows, there is also a modifier. A modifier is a key
combination that can be set via the `delimiter` option (default `<C-s>`) that
when pressed in `TERMINAL` mode has a special meaning, depending on the
workflow. This combination will not be sent automatically to your shell, even
when in `TERMINAL` mode.

With a `tmux` workflow, the modifier will automatically put `vesper` in `VESPER`
mode and it will show you (if `use_cheatseet` option is set to true) a list of
possible shortcuts. The next key will be sent to vesper, instead of your
terminal. You can click `<esc>` or `<C-c>` if you change your mind and you
want to get back to `TERMINAL` mode, or you can press for example `p` to
switch to `PANE SELECT` mode.

When clicking the modifier, `vesper` will show you the next possible keys (if
`use_cheatsheet` options is set to true) on the bottom of the page, but will
stay in `TERMINAL` mode. If the next key is an `vesper` shortcut, then an `vesper`
command will be executed. If no, then both keys (the modifier and the
following key) will be sent to the current shell.

### Emacs workflow

In this workflow, there are no modes and no modifiers. You are always inside
the `TERMINAL` mode. If you want to access `vesper` special functions (like
opening a float), you have to click certain shortcuts prefixed by a standard
modifier (`ctrl` or `alt`). For example, to open a new float, you need to
click on `<a-f>`. For a full list of shortcuts for this workflow, check the
`examples/emacs-config.ini` file.

### Zellij workflow

In this workflow, there are modes, but there is no modifier. You will mostly
be in `TERMINAL`, `VESPER` or the custom `vesper` modes (`PANE SELECT`, `PANE
RESIZE`, `MOVE`, `SPLIT` or `TABS`). To switch in a another mode, you have
standard shortcuts prefixed by a standard delimiter (`ctrl` or `alt`). For
example, to change to `TABS` mode, you can click `<C-S-t>`. For a full list of
shortcuts for this workflow, chek the `examples/zellij-config.ini` file.

### Tmux workflow

In this workflow, you have modes and you also have a modifier. This means,
that by default you are in `TERMINAL` mode and all your keys are sent to your
`bash` interpreter (or `cmd` for windows). Whenever you want to interact with
`vesper`, you need to press your modifier (by default `<C-s>`). This will put
`vesper` from `TERMINAL` mode in `VESPER` mode. Now, your key presses will be
sent to `vesper`, instead of your `bash` interpreter, just like with `tmux`.

### Vesper workflow

This is the default workflow. After installation, if you don't modify your
configuration, when you will start `vesper`, you will find yourself in the
`vesper` workflow. This workflow is a combination of all the previous workflows.
You are all the time in the `TERMINAL` mode, you have a modifier (default
`<C-s>`) and you have modes. 

Unlike `tmux` workflow, when you click the modifier `vesper` will remain in
`TERMINAL` mode, but will wait for the next key and is going to interpret it
like an `vesper` command if it's a known shortcut, or if not, will send `<C-s>`
followed by the key you pressed to your interpreter.

## Mouse support

In `vesper`, you can also use the mouse. By default, you can select with the
mouse and you can also move the cursor, which will modify the selection. To
disable the mouse, set the mouse option to nothing. Either in your `config.ini`
file in the options section (`mouse = `) or in your `init.lua` file
(`vim.o.mouse = ""`). The default value is `a`. If you want to see the meaning
and possible values, you can check
[here](https://neovim.io/doc/user/options.html#'mouse').

## Commands

You can communicate directly with vesper from `VESPER` mode, by clicking `:`
(while in `VESPER` mode). This will open a prompt on top of the status bar.
There, you can type one of the possible commands and then click `enter`.
`Vesper` will execute the command and then return in `TERMINAL` mode or stay in
`VESPER` mode, depending on the command requested. 

Some of the commands can take parameters. For example, `VesperSelectPane` will
take as a parameter the direction in which to select the next pane (left,
right, up or down). The parameters are separated by spaces. For example, to
select the next pane to the left, in `VESPER` mode, you need to click the
following: `:VesperSelectPane left<cr>` (the `<cr>` represents `enter`).

### Possible commands

#### VesperHideFloats

Hiddens all the floats. 

#### VesperOpen

Opens a new tab with a new shell. 

#### VesperEnterMode

Puts `vesper` in the requested mode. 

**Parameters**:

* the mode (p or r or s or m or T or n or t or v)

#### VesperShowFloats

Shows the currently opened floats. If no floats are created yet, then nothing
will be shown. If the option `link_floats_with_tabs` is true, then it shows
the currently opened floats on the current tab.

#### VesperOpenFloat

Creates a new float on the current tab. If the option `link_floats_with_tabs`
is set to `true`, then this float will only be visible on the currently
selected tab.

#### VesperToggleFloats

Toggles the opened floats visibility. If `link_floats_with_tabs` is true, then
it toggles the visibility of opened floats for the current tab.

#### VesperMoveCurrentFloat

Moves the currently selected float in the given direction with the given
increment.

**Parameters**:

* direction (left, right, up or down) - mandatory
* increment (number) - optional. If missing, then the float will be moved by 5
  pixels

#### VesperSelectPane

Selects the next pane in the indicated direction

**Parameters**: 

* direction (left, right, up or down)

#### VesperSendToCurrentPane

Sends the indicated text to the currently selected pane. This commands accepts
after it a `!` symbol. This means that the characters will be escaped. 

For example: 

`:VesperSendToCurrentPane ls -al<cr>` will send to the current pane the literal
text `ls -al<cr>`. The `<cr>` will not be replaced by an `enter`.

`:VesperSendToCurrentPane! ls -al<cr>` will send to the current pane the text
`ls -al` followed by an enter (notice the exclamation marc after the command)

**Parameters**:

* the text to send to the currently selected pane

#### VesperPositionCurrentFloat

Positions the currently selected floating pane in a region of the screen. 

**Parameters**:

* the screen region where to position the float (top, bottom, start or end)

#### VesperRedraw

Redraws the terminal

#### VesperSuspend

Suspends all the `vesper` events. This is an usefull command for advanced users
who might want to open something in an underlying `nvim` buffer. Normally,
that something would be overriten by a new shell. In order to prevent this,
you can suspend the `vesper` events, finish your job and then resume the `vesper`
events.

#### VesperResume

Resumes the `vesper` events. This is an usefull command for advanced users
who might want to open something in an underlying `nvim` buffer. Normally,
that something would be overriten by a new shell. In order to prevent this,
you can suspend the `vesper` events, finish your job and then resume the `vesper`
events.

#### VesperDisconnect

Disconnects the current session

#### VesperSaveLayout

Saves the current layout. Uppon invoking this command, you will be met with a
prompt at the bottom of the screen, on top of the status bar, to indicate a
file name where you wish to save your layout. You can type a full path to a
file, using `tab` for autocompletion.

`Vesper` has very powerfull features for saving and restoring saved sessions.
See the [Session support section](#session-support)

**Parameters**:

* The file in which to save the layout (optional)

#### VesperRestoreLayout

Restores a saved layout. Uppon invoking this command, you will be met with a
prompt at the bottom of the screen, on top of the status bar, to indicate a
file name where you wish to save your layout. You can type a full path to a
file, using `tab` for autocompletion.

`Vesper` has very powerfull features for saving and restoring saved sessions.
See the [Session support section](#session-support)

**Parameters**:

* The file from which to restore the layout (optional)

#### VesperSetCmd

Sets a command to be launched uppon a restore. For more info, see the [Session
support section](#session-support).

**Parameters**:

* the command to be launched uppon a restore

#### VesperStartLogging

Starts logging the current terminal scrollback buffer. 

**Note**: this commands does not log what is visibile on the screen. Only what
is in the scroll buffer.

**Parameters**:

* The file in which to start logging (optional)

#### VesperStopLogging

If started, stops the current terminal logging of the scroll buffer.

#### VesperSetWinId

Sets a vesper windows id for the currently selected pane. See the [Session
support section](#session-support) for why you would set and how you would use
this id

**Parameters**:

* the id of the pane

#### VesperTogglePassthrough

Toggles the passthrough mode.

**Parameters**:

* The escape sequence

#### VesperRenameCurrentTab

Renames the currently selected tab.

#### VesperEdit

Edits a file in the current terminal by opening in the editor set by the
`editor` options or the `$EDITOR` variable on your system.

**Parameters**:

* The file in to edit (optional)

#### VesperEditScrollback

Edits the current terminal's buffer in the editor set by the `editor` option
or the `$EDITOR` variable on your system.

#### VesperEditScrollbackLog

Edits the current terminal's scrollback log in the editor set by the `editor`
option or the `$EDITOR` variable on your system. If the logging is not started
using `VesperStartLogging` command, an error message is thrown.

#### VesperRenameCurrentFloat

Renames the currently selected pane float. If the currently selected pane is
an embedded pane, it will throw an error.

#### VesperSelectTab

Select the tab indicated by the number in parameter. If the tab does not
exists (for example you are trying to select the 5th tab, but only have 4
tabs) it will throw an error.

**Parameters**:

* The tab to select

#### VesperReloadConfig

Reloads the current configuration

#### VesperEditConfig

Edits the current configuration in the currently selected pane (embedded or
floating)

#### VesperQuit

Exists vesper closing all the current panes and saving the session if autosave
is set. This is the recommended way to quit vesper, if you want your session
to be preserver for the next time you open it.

#### VesperUndo

Reopens the last tab, float or split closed

#### VesperToggleFullscreen

Toggles the currently selected floating pane full screen, or if the pane is
already full screen, it will toggle it to the original state

#### VesperCd

Changed the directory of the current pane to the indicated new directory

**Parameters**:

* the new directory

#### VesperDumpScrollback

Dumps the content of the scrollback buffer of the current terminal in the
indicated file

## Configuration

Vesper can be configured in several ways. For
[neovim](https://github.com/neovim/neovim) users, you can configure azul
directly via an init file placed in `~/.config/vesper/init.lua`. This will
expose the full power and all the configurations of vesper. You can check the
`vesper` api [here](./api.md).

You have examples of configuration for each workflow inside the `examples/`
folder (for example, `examples/vesper.lua`). You can get any of the example
files, corresponding to each of the possible workflows, rename it to
`init.lua` and copy it to `~/.config/vesper` folder.

If you don't need to access the full power of `neovim` or you are not familiar
with `lua` or `neovim`, you can configure vesper via a simple `ini` file format.
The file should be placed in `~/.config/vesper/config.ini`.

The ini file format is a classical `ini` format. Each option or shortcut
should be on one line separated by an equal. The left side will be the option
and the right side the value. 

In case of shortcuts, the left side should contain the mode, followed by a dot
and then followed by the action (for an workflow other than `emacs` workflow)
or the action directly, for the `emacs` workflow. For more info see the
[Shortcuts section](#shortcuts)

### Options

* **workflow** - The current workflow (default `vesper`)
* **modifier** - The default modifier (default `<C-s>`)
* **link_floats_with_tabs** - If true, then the floats opened in a tab, are
  displayed only in that tab. Otherwise, the floats will be displayed over all
  the tabs (default `false`)
* **shell** - The default shell (default is given by your operating system)
* **mouse** - The mouse support settings (default `a`)
* **theme** - The status line theme (default `dracula`). You can see a list of
  all the possible themes
  [here](https://github.com/nvim-lualine/lualine.nvim/blob/master/THEMES.md)
  *Note*: to change this option, `vesper` requires a restart
* **termguicolors** - If true, then the 24-bit RGB colors are activated
  (default `true`). For more info, see
  [here](https://neovim.io/doc/user/options.html#'termguicolors')
* **scrollback** - The number of lines saved in the scroll history. The more
  lines, the bigger the memory consumption of `vesper` (default 2000)
* **clipboard** - The clipboard settings (default `unnamedplus`). For more
  info, see [Copy/pasting section](#copypasting)
* **encoding** - The default encoding of the terminal (default `utf-8`)
* **passthrough_escape** - The default escape sequence from the passthrough
  mode (default `<C-\><C-s>`)
* **hide_in_passthrough** If true, then when in passthrough mode, hide the
  status line of the passed through session (default false)
* **use_cheatsheet** If this is set to true, for `vesper` and `tmux` workflows, a
  cheatsheet will be displayed after you click the modifier key (default
  true)
* **modifer_timeout** The milliseconds to wait for a key sequence after the
  modifier has been clicked (for `vesper` or `tmux` worklows and only if
  `use_cheatsheet` option is set to ``). In `vesper` or `tmux` workflows, after
  you click the modifier, if the `use_cheatsheet` option is true, then the list of
  the possible keys will be displayed. If you have combination of multiple
  keys, this timeout is the time that `vesper` will wait for the combination to
  be finished (default 500)
* **opacity** The opacity of the floating windows, from 0 - non transparent to
  100 - fully transparent (default 0)
* **tab_title** The default tab title. See the [placeholders](#placeholders)
  section (default `Tab :tab_n:`)
* **float_pane_title** The default float pane title. See the
  [placeholders](#placeholders) section (default `:term_title:`)
* **use_lualine** If true, then use the current lunaline theme for the
  statusbar. In case you want to use your own statusbar `nvim` plugin, or a
  tabline plugin, just set this option to false and load your statusline or
  tabline plugin via `init.lua`. You can check the `theme.lua` file as an
  inspiration on how to create your own statusbar. *Note*: to change this
  option, `vesper` requires a restart
* **auto_start_logging** If true, then start logging automatically when
  opening a new pane. This option allows you to have as many lines in your
  current scrollback, that you can see at anytime by invoking
  `edit_scrollback_log` action `<C-s>pe`
* **modes_cheatsheet_position** The position where to show the cheatsheet
  (`bottom`, `top` or `auto`). Auto means that depending on where the cursor
  is situated when showing the cheatsheet, the window will be displayed top or
  bottom as to not hide the cursor (default: `bottom`)
* **term** The setting of the `TERM` variable to be applied in linux like
  linux like environments (default st-256color)
* **editor** The editor to use when editing a pane or the config. This will
  override the `$EDITOR` variable in that case (default not set)
* **autosave** If `always` or `often`, the session will be tracked; see [the
  autosave](#autosave) section
* **autosave_location** The location where to track the sections; see [the
  autosave](#autosave) section
* **undo_restore_cmd** The command to be executed uppon restoring a closed
  tab, split or float (default `cat`). See [undo section](#undo)

**Note**:

If you want to have infinite scrolling on your scrollback buffer, set
`auto_start_logging` to `true`. Whenever you need to access the scrollback
buffer of any terminal, just do `<C-s>pge`. Or you can set a faster shortcut,
like this (assuming `vesper` workflow):

```lua
local vesper = require('vesper')
vesper.set_key_map('t', '[', '', {
    callback = function()
        vesper.edit_scrollback_log()
    end
})
```

Then, just like in `tmux`, doing `<C-s>[` will open your scrollback buffer log
in your current editor set by the the `editor` option or the `$EDITOR` variable.

#### Placeholders

The `pane_title` and `tab_title` options, can have placeholders in their
content. This means that certan values will be replaced either with standard
options, either with user input. For example, setting the `tab_title` like
this in the `config.ini`:

```ini
tab_title = :app: - :tab_n:
```

will make vesper asking for a value for the `app` parameter, everytime a new
tab is created. The newly created tab will have the `:app:` value replaced
with the input from the user. 

There are some standard placeholders which `vesper` will replace automatically,
without asking for user input: 

* **:tab_n:** will be replaced with the current tab number (not applied to
  floating pane titles)
* **:term_title:** will be replaced with the current terminal title as
  suggested by the running terminal in the pane.
* **:is_current:** will be replaced with the `*` character, if the current tab
  is selected, giving you the possibility to mark the currently selected tab
  as in `tmux` (not applied to floating pane titles).
* **:vesper_win_id:** will be replaced by the custom win id given using
  `:VesperSetWinId` command of the currently selected embedded pane in the tab
* **:vesper_cmd:** will be replaced by the custom command given using
  `:VesperSetCmd` command of the currently selected embedded pane in the tab
* **:vesper_cmd_or_win_id:** will be replaced with the custom command given by
  `:VesperSetCmd` if it exists, if not with the window id set by `:VesperSetWinId`
  or with the automatic default `vesper_win_id` set by vesper.
* **:cwd:** will be replaced with the working directory of the current pane.

### Shortcuts

`Vesper` can use any shortcuts that `nvim` can use. As a notation, to set up a
`ctrl`, `alt` of `shift` shortcut, you need to enclose the shortcut between
`<` and `>`. So, for example, to set a `ctrl` + `s` shortcut, you would
define it as `<C-s>`. You can see the example files inside the `examples`
folder.

In the `ini` file, each shortcut will be defined on a row. For `vesper`, `tmux`
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

An action, could have more than one shortcut, even for the same mode. In this
case, just put each shortcut on an ini line. For example: 

```ini
terminal.create_tab = c
terminal.create_tab = C
```

For example, for `tab_select` action, which expects the number of tab that you
want to select, you need to add the following in your init file. 

For an workflow other than `emacs`: `terminal.tab_select.1 = 1`.

For an `emacs` workflow: `tab_select.1 = <C-1>`.

If you want to override an action shortcut set via the `config.ini` file via
the `init.lua`, you need to call the `config.ovewrite_default_action`
function:

```lua
require('config').overwrite_default_action('toggle_floats', 'vesper', 'terminal', 'r')   
```

#### Possible actions

* **select_terminal**: Selects visually one of the existing pane in the current
session
  - defaults: 
    + `vesper`: `terminal.select_terminal = St`
    + `tmux`: `vesper.select_terminal = St`
    + `zellij`: `pane.select_terminal = T`
    + `emacs`: `select_terminal = <C-S-t>`

* **select_session**: Selects one existing vesper session
  - defaults: 
    + `vesper`: `terminal.select_session = Ss`
    + `tmux`: `vesper.select_session = Ss`
    + `zellij`: `pane.select_session = S`
    + `emacs`: `select_session = <C-S-s>`

* **create_tab**: Creates a new tab with a local shell, or with a shell from a
  remote machine, if `VESPER_REMOTE_CONNECTION` variable is set
  - defaults: 
    + `vesper`: `terminal.create_tab = c`
    + `vesper`: `tabs.create_tab = c`
    + `tmux`: `vesper.create_tab = c`
    + `tmux`: `tabs.create_tab = c`
    + `zellij`: `tabs.create_tab = c`
    + `emacs`: `create_tab = <A-c>`

* **tab_select**: Selects an existing tab. 
  - arguments: The number of the tab to select
  - defaults: 
    + `vesper`: `terminal.tab_select.n = n` (where n represents the number of
      the tab to select)
    + `tmux`: `vesper.tab_select.n = n` (where n represents the number of the
      tab to select)
    + `emacs`: `tab_select.n = <A-n>` (where n represents the number of the
      tab to select)

* **toggle_floats**: Toggle the floats visibility
  - defaults: 
    + `vesper`: `terminal.toggle_floats = w`
    + `tmux`: `vesper.toggle_floats = w`
    + `zellij`: `pane.toggle_floats = w`
    + `emacs`: `toggle_floats = <A-w>`

* **enter_mode**: Enter an `vesper` mode
  - arguments: The mode to enter (p or r or s or m or T or n or t or v or P)
  - defaults: 
    + `vesper`: `terminal.enter_mode.X = X` (where X is one of the p, r, m, s,
      T, n, v)
    + `vesper`: `resize.enter_mode.t = <cr>`
    + `vesper`: `resize.enter_mode.t = <esc>`
    + `vesper`: `resize.enter_mode.t = i`
    + `vesper`: `pane.enter_mode.t = <cr>`
    + `vesper`: `pane.enter_mode.t = <esc>`
    + `vesper`: `pane.enter_mode.t = i`
    + `vesper`: `move.enter_mode.t = <cr>`
    + `vesper`: `move.enter_mode.t = <esc>`
    + `vesper`: `move.enter_mode.t = i`
    + `vesper`: `split.enter_mode.t = <cr>`
    + `vesper`: `split.enter_mode.t = <esc>`
    + `vesper`: `split.enter_mode.t = i`
    + `vesper`: `tabs.enter_mode.t = <cr>`
    + `vesper`: `tabs.enter_mode.t = <esc>`
    + `vesper`: `tabs.enter_mode.t = i`
    + `tmux`: `terminal.enter_mode.X = X` (where X is one of the p, r, m, s,
      T, v)
    + `tmux`: `resize.enter_mode.t = <cr>`
    + `tmux`: `resize.enter_mode.t = <esc>`
    + `tmux`: `resize.enter_mode.t = i`
    + `tmux`: `pane.enter_mode.t = <cr>`
    + `tmux`: `pane.enter_mode.t = <esc>`
    + `tmux`: `pane.enter_mode.t = i`
    + `tmux`: `move.enter_mode.t = <cr>`
    + `tmux`: `move.enter_mode.t = <esc>`
    + `tmux`: `move.enter_mode.t = i`
    + `tmux`: `split.enter_mode.t = <cr>`
    + `tmux`: `split.enter_mode.t = <esc>`
    + `tmux`: `split.enter_mode.t = i`
    + `tmux`: `tabs.enter_mode.t = <cr>`
    + `tmux`: `tabs.enter_mode.t = <esc>`
    + `tmux`: `tabs.enter_mode.t = i`
    + `zellij`: `terminal.enter_mode.p = <C-p>`
    + `zellij`: `terminal.enter_mode.r = <C-r>`
    + `zellij`: `terminal.enter_mode.v = <C-S-v>`
    + `zellij`: `terminal.enter_mode.s = <C-s>`
    + `zellij`: `terminal.enter_mode.T = <C-S-t>`
    + `zellij`: `terminal.enter_mode.n = <C-a>`
    + `zellij`: `terminal.enter_mode.m = <C-S-m>`
    + `zellij`: `pane.enter_mode.t = <cr>`
    + `zellij`: `pane.enter_mode.t = <esc>`
    + `zellij`: `pane.enter_mode.t = i`
    + `zellij`: `move.enter_mode.t = <cr>`
    + `zellij`: `move.enter_mode.t = <esc>`
    + `zellij`: `move.enter_mode.t = i`
    + `zellij`: `split.enter_mode.t = <cr>`
    + `zellij`: `split.enter_mode.t = <esc>`
    + `zellij`: `split.enter_mode.t = i`
    + `zellij`: `tabs.enter_mode.t = <cr>`
    + `zellij`: `tabs.enter_mode.t = <esc>`
    + `zellij`: `tabs.enter_mode.t = i`

* **create_float**: Creates a new float with a local shell, or with a shell
  from a remote machine, if the `VESPER_REMOTE_CONNECTION` variable is set
  - defaults: 
    + `vesper`: `terminal.create_float = f`
    + `tmux`: `vesper.create_float = f`
    + `zellij`: `pane.create_float = f`
    + `emacs`: `create_float = <A-f>`

* **disconnect**: Disconnects the current session
  - defaults: 
    + `vesper`: `terminal.disconnect = d`
    + `tmux`: `vesper.disconnect = d`
    + `zellij`: `terminal.disconnect = <C-d>`
    + `emacs`: `disconnect = <A-d>`

* **resize_left**: Resizes the currently selected pane towards left direction
  - defaults: 
    + `vesper`: `resize.resize_left = h`
    + `vesper`: `resize.resize_left = <left>`
    + `tmux`: `resize.resize_left = h`
    + `tmux`: `resize.resize_left = <left>`
    + `zellij`: `resize.resize_left = h`
    + `zellij`: `resize.resize_left = <left>`
    + `emacs`: `resize_left = <C-S-left>`

* **resize_right**: Resizes the currently selected pane towards right direction
  - defaults: 
    + `vesper`: `resize.resize_right = l`
    + `vesper`: `resize.resize_right = <right>`
    + `tmux`: `resize.resize_right = l`
    + `tmux`: `resize.resize_right = <right>`
    + `zellij`: `resize.resize_right = l`
    + `zellij`: `resize.resize_right = <right>`
    + `emacs`: `resize_up = <C-S-right>`

* **resize_up**: Resizes the currently selected pane towards up
  - defaults: 
    + `vesper`: `resize.resize_up = k`
    + `vesper`: `resize.resize_up = <up>`
    + `tmux`: `resize.resize_up = k`
    + `tmux`: `resize.resize_up = <up>`
    + `zellij`: `resize.resize_up = k`
    + `zellij`: `resize.resize_up = <up>`
    + `emacs`: `resize_up = <C-S-up>`

* **resize_down**: Resizes the currently selected pane towards down
  - defaults: 
    + `vesper`: `resize.resize_down = j`
    + `vesper`: `resize.resize_down = <down>`
    + `tmux`: `resize.resize_down = j`
    + `tmux`: `resize.resize_down = <down>`
    + `zellij`: `resize.resize_down = j`
    + `zellij`: `resize.resize_down = <down>`
    + `emacs`: `resize_up = <C-S-down>`

* **select_left**: Selects the next panel to the left
  - defaults:
    + `vesper`: `pane.select_left = h`
    + `vesper`: `pane.select_left = <left>`
    + `tmux`: `pane.select_left = h`
    + `tmux`: `pane.select_left = <left>`
    + `zellij`: `pane.select_left = h`
    + `zellij`: `pane.select_left = <left>`
    + `emacs`: `select_left = <A-left>`

* **select_right**: Selects the next panel to the right
  - defaults:
    + `vesper`: `pane.select_right = l`
    + `vesper`: `pane.select_right = <right>`
    + `tmux`: `pane.select_right = l`
    + `tmux`: `pane.select_right = <right>`
    + `zellij`: `pane.select_right = l`
    + `zellij`: `pane.select_right = <right>`
    + `emacs`: `select_right = <A-right>`

* **select_up**: Selects the next above panel
  - defaults:
    + `vesper`: `pane.select_up = k`
    + `vesper`: `pane.select_up = <up>`
    + `tmux`: `pane.select_up = k`
    + `tmux`: `pane.select_up = <up>`
    + `zellij`: `pane.select_up = k`
    + `zellij`: `pane.select_up = <up>`
    + `emacs`: `select_up = <A-up>`

* **select_down**: Selects the next below panel
  - defaults:
    + `vesper`: `pane.select_down = j`
    + `vesper`: `pane.select_down = <down>`
    + `tmux`: `pane.select_down = j`
    + `tmux`: `pane.select_down = <down>`
    + `zellij`: `pane.select_down = j`
    + `zellij`: `pane.select_down = <down>`
    + `emacs`: `select_down = <A-down>`

* **move_left**: Moves the currently selected panel to the left
  - arguments: The number of columns to move
  - defaults:
    + `vesper`: `move.move_left.5 = h`
    + `vesper`: `move.move_left.5 = <left>`
    + `vesper`: `move.move_left.1 = <C-h>`
    + `vesper`: `move.move_left.1 = <C-left>`
    + `tmux`: `move.move_left.5 = h`
    + `tmux`: `move.move_left.5 = <left>`
    + `tmux`: `move.move_left.1 = <C-h>`
    + `tmux`: `move.move_left.1 = <C-left>`
    + `zellij`: `move.move_left.5 = h`
    + `zellij`: `move.move_left.5 = <left>`
    + `zellij`: `move.move_left.1 = <C-h>`
    + `zellij`: `move.move_left.1 = <C-left>`
    + `emacs`: `move_left.5 = <C-A-left>`

* **move_right**: Moves the currently selected panel to the right
  - arguments: The number of columns to move
  - defaults:
    + `vesper`: `move.move_right.5 = l`
    + `vesper`: `move.move_right.5 = <right>`
    + `vesper`: `move.move_right.1 = <C-l>`
    + `vesper`: `move.move_right.1 = <C-right>`
    + `tmux`: `move.move_right.5 = l`
    + `tmux`: `move.move_right.5 = <right>`
    + `tmux`: `move.move_right.1 = <C-l>`
    + `tmux`: `move.move_right.1 = <C-right>`
    + `zellij`: `move.move_right.5 = l`
    + `zellij`: `move.move_right.5 = <right>`
    + `zellij`: `move.move_right.1 = <C-l>`
    + `zellij`: `move.move_right.1 = <C-right>`
    + `emacs`: `move_right.5 = <C-A-right>`

* **move_up**: Moves the currently selected panel towards up
  - arguments: The number of columns to move
  - defaults:
    + `vesper`: `move.move_up.5 = k`
    + `vesper`: `move.move_up.5 = <up>`
    + `vesper`: `move.move_up.1 = <C-k>`
    + `vesper`: `move.move_up.1 = <C-up>`
    + `tmux`: `move.move_up.5 = k`
    + `tmux`: `move.move_up.5 = <up>`
    + `tmux`: `move.move_up.1 = <C-k>`
    + `tmux`: `move.move_up.1 = <C-up>`
    + `zellij`: `move.move_up.5 = k`
    + `zellij`: `move.move_up.5 = <up>`
    + `zellij`: `move.move_up.1 = <C-k>`
    + `zellij`: `move.move_up.1 = <C-up>`
    + `emacs`: `move_up.5 = <C-A-up>`

* **move_down**: Moves the currently selected panel towards down
  - arguments: The number of columns to move
  - defaults:
    + `vesper`: `move.move_down.5 = j`
    + `vesper`: `move.move_down.5 = <down>`
    + `vesper`: `move.move_down.1 = <C-j>`
    + `vesper`: `move.move_down.1 = <C-down>`
    + `tmux`: `move.move_down.5 = j`
    + `tmux`: `move.move_down.5 = <down>`
    + `tmux`: `move.move_down.1 = <C-j>`
    + `tmux`: `move.move_down.1 = <C-down>`
    + `zellij`: `move.move_down.5 = j`
    + `zellij`: `move.move_down.5 = <down>`
    + `zellij`: `move.move_down.1 = <C-j>`
    + `zellij`: `move.move_down.1 = <C-down>`
    + `emacs`: `move_down.5 = <C-A-down>`

* **split_left**: Splits the currently selected tab to the left opening a
  local shell, or a shell from a remote machine, if the
  `VESPER_REMOTE_CONNECTION` variable is set
  - defaults:
    + `vesper`: `pane.split_left = H`
    + `vesper`: `pane.split_left = <S-left>`
    + `vesper`: `split.split_left = h`
    + `vesper`: `split.split_left = <left>`
    + `tmux`: `pane.split_left = H`
    + `tmux`: `pane.split_left = <S-left>`
    + `tmux`: `split.split_left = h`
    + `tmux`: `split.split_left = <left>`
    + `zellij`: `split.split_left = h`
    + `zellij`: `split.split_left = <left>`
    + `emacs`: `split_left = <C-left>`

* **split_right**: Splits the currently selected tab to the right opening a
  local shell, or a shell from a remote machine, if the
  `VESPER_REMOTE_CONNECTION` variable is set
  - defaults:
    + `vesper`: `pane.split_right = L`
    + `vesper`: `pane.split_right = <S-right>`
    + `vesper`: `split.split_right = l`
    + `vesper`: `split.split_right = <right>`
    + `tmux`: `pane.split_right = H`
    + `tmux`: `pane.split_right = <S-right>`
    + `tmux`: `split.split_right = h`
    + `tmux`: `split.split_right = <right>`
    + `zellij`: `split.split_right = h`
    + `zellij`: `split.split_right = <right>`
    + `emacs`: `split_right = <C-right>`

* **split_up**: Splits the currently selected tab upwards opening a local
  shell, or a shell from a remote machine, if the `VESPER_REMOTE_CONNECTION`
  variable is set
  - defaults:
    + `vesper`: `pane.split_up = K`
    + `vesper`: `pane.split_up = <S-up>`
    + `vesper`: `split.split_up = k`
    + `vesper`: `split.split_up = <up>`
    + `tmux`: `pane.split_up = K`
    + `tmux`: `pane.split_up = <S-up>`
    + `tmux`: `split.split_up = k`
    + `tmux`: `split.split_up = <up>`
    + `zellij`: `split.split_up = k`
    + `zellij`: `split.split_up = <up>`
    + `emacs`: `split_up = <C-up>`

* **split_down**: Splits the currently selected tab downwards a local shell,
  or a shell from a remote machine, if the `VESPER_REMOTE_CONNECTION` variable
  is set
  - defaults:
    + `vesper`: `pane.split_down = J`
    + `vesper`: `pane.split_down = <S-down>`
    + `vesper`: `split.split_down = j`
    + `vesper`: `split.split_down = <down>`
    + `tmux`: `pane.split_down = J`
    + `tmux`: `pane.split_down = <S-down>`
    + `tmux`: `split.split_down = j`
    + `tmux`: `split.split_down = <down>`
    + `zellij`: `split.split_down = j`
    + `zellij`: `split.split_down = <down>`
    + `emacs`: `split_down = <C-down>`

* **move_top**: Moves the currently selected float to the top of the screen
  - defaults:
    + `vesper`: `move.move_top = K`
    + `vesper`: `move.move_top = <S-up>`
    + `tmux`: `move.move_top = K`
    + `tmux`: `move.move_top = <S-up>`
    + `zellij`: `move.move_top = K`
    + `zellij`: `move.move_top = <S-up>`
    + `emacs`: `move_top = <C-A-n>`

* **move_bottom**: Moves the currently selected float to the bottom of the screen
  - defaults:
    + `vesper`: `move.move_bottom = J`
    + `vesper`: `move.move_bottom = <S-down>`
    + `tmux`: `move.move_bottom = J`
    + `tmux`: `move.move_bottom = <S-down>`
    + `zellij`: `move.move_bottom = J`
    + `zellij`: `move.move_bottom = <S-down>`
    + `emacs`: `move_bottom = <C-A-s>`

* **move_start**: Moves the currently selected float to the left of the screen
  - defaults:
    + `vesper`: `move.move_start = H`
    + `vesper`: `move.move_start = <S-left>`
    + `tmux`: `move.move_start = H`
    + `tmux`: `move.move_start = <S-left>`
    + `zellij`: `move.move_start = H`
    + `zellij`: `move.move_start = <S-left>`
    + `emacs`: `move_start = <C-A-w>`

* **move_end**: Moves the currently selected float to the right of the screen
  - defaults:
    + `vesper`: `move.move_end = L`
    + `vesper`: `move.move_end = <S-right>`
    + `tmux`: `move.move_end = L`
    + `tmux`: `move.move_end = <S-right>`
    + `zellij`: `move.move_end = L`
    + `zellij`: `move.move_end = <S-right>`
    + `emacs`: `move_end = <C-A-e>`

* **tab_select_first**: Selects the first tab
  - defaults:
    + `vesper`: `tabs.tab_select_first = H`
    + `vesper`: `tabs.tab_select_first = <S-left>`
    + `tmux`: `tabs.tab_select_first = H`
    + `tmux`: `tabs.tab_select_first = <S-left>`
    + `zellij`: `tabs.tab_select_first = H`
    + `zellij`: `tabs.tab_select_first = <S-left>`
    + `emacs`: `tab_select_first = <C-x><S-left>`

* **tab_select_last**: Selects the last tab
  - defaults:
    + `vesper`: `tabs.tab_select_last = L`
    + `vesper`: `tabs.tab_select_last = <S-right>`
    + `tmux`: `tabs.tab_select_last = L`
    + `tmux`: `tabs.tab_select_last = <S-right>`
    + `zellij`: `tabs.tab_select_last = L`
    + `zellij`: `tabs.tab_select_last = <S-right>`
    + `emacs`: `tab_select_last = <C-x><S-right>`

* **tab_select_previous**: Selects the previous tab
  - defaults:
    + `vesper`: `tabs.tab_select_previous = h`
    + `vesper`: `tabs.tab_select_previous = <left>`
    + `tmux`: `tabs.tab_select_previous = h`
    + `tmux`: `tabs.tab_select_previous = <left>`
    + `zellij`: `tabs.tab_select_previous = h`
    + `zellij`: `tabs.tab_select_previous = <left>`
    + `emacs`: `tab_select_previous = <C-x><left>`

* **tab_select_next**: Selects the next tab
  - defaults:
    + `vesper`: `tabs.tab_select_next = l`
    + `vesper`: `tabs.tab_select_next = <right>`
    + `tmux`: `tabs.tab_select_next = l`
    + `tmux`: `tabs.tab_select_next = <right>`
    + `zellij`: `tabs.tab_select_next = l`
    + `zellij`: `tabs.tab_select_next = <right>`
    + `emacs`: `tab_select_next = <C-x><right>`

* **copy**: Copies the currently selected text into the clipboard.
  - defaults:
    + `vesper`: `visual.copy = y`
    + `vesper`: `visual.copy = <C-c>`
    + `tmux`: `visual.copy = y`
    + `tmux`: `visual.copy = <C-c>`
    + `zellij`: `visual.copy = y`
    + `zellij`: `visual.copy = <C-c>`
    + `emacs`: `copy = <C-c>`

* **paste**: Pastes the content of the clipboard into the currently selected
  pane
  - defaults:
    + `vesper`: `terminal.paste = pp`
    + `vesper`: `terminal.paste = <C-v>`
    + `tmux`: `terminal.paste = <C-v>`
    + `zellij`: `terminal.paste = <C-v>`
    + `emacs`: `paste = <C-v>`

* **passthrough**: Toggles the passthrough mode.
  - defaults:
    + `vesper`: `terminal.passthrough = N`
    + `tmux`: `terminal.passthrough = N`
    + `emacs`: `passthrough = <A-n>`

* **rotate_panel**: Rotates the current panel (by doing `wincmd x`)
  - defaults:
    + `vesper`: `pane.rotate_panel = x`
    + `tmux`: `pane.rotate_panel = x`
    + `zellij`: `pane.rotate_panel = x`
    + `emacs`: `rotate_panel = <C-x>x`

* **rename_tab**: Renames the currently selected tab.
  - defaults:
    + `vesper`: `tabs.rename_tab = r`
    + `tmux`: `tabs.rename_tab = r`
    + `zellij`: `tabs.rename_tab = r`
    + `emacs`: `rename_tab = <C-x><C-r>`

* **edit_scrollback**: Edits the scrollback of the currently selected terminal
  - defaults:
    + `vesper`: `pane.edit_scrollback = e`
    + `tmux`: `pane.edit_scrollback = e`
    + `zellij`: `pane.edit_scrollback = e`
    + `emacs`: `edit_scrollback = <C-x><C-e>`

* **edit_scrollback**: Edits the scrollback log of the currently selected
  terminal (if started with `VesperStartLogging`)
  - defaults:
    + `vesper`: `pane.edit_scrollback = ge`
    + `tmux`: `pane.edit_scrollback = ge`
    + `zellij`: `pane.edit_scrollback = ge`
    + `emacs`: `edit_scrollback = <C-x>ge`

* **show_mode_cheatsheet**: Toggles the cheatsheet of the vesper shortcuts for
  the current mode (not valid for `emacs` workflow)
  - defaults:
    + `vesper`: `resize.show_mode_cheatsheet = <C-o>`
    + `vesper`: `pane.show_mode_cheatsheet = <C-o>`
    + `vesper`: `move.show_mode_cheatsheet = <C-o>`
    + `vesper`: `split.show_mode_cheatsheet = <C-o>`
    + `vesper`: `tabs.show_mode_cheatsheet = <C-o>`
    + `tmux`: `resize.show_mode_cheatsheet = <C-o>`
    + `tmux`: `pane.show_mode_cheatsheet = <C-o>`
    + `tmux`: `move.show_mode_cheatsheet = <C-o>`
    + `tmux`: `split.show_mode_cheatsheet = <C-o>`
    + `tmux`: `tabs.show_mode_cheatsheet = <C-o>`
    + `zellij`: `resize.show_mode_cheatsheet = <C-o>`
    + `zellij`: `pane.show_mode_cheatsheet = <C-o>`
    + `zellij`: `move.show_mode_cheatsheet = <C-o>`
    + `zellij`: `split.show_mode_cheatsheet = <C-o>`
    + `zellij`: `tabs.show_mode_cheatsheet = <C-o>`

* **rename_float**: Renames the currently selected floating pane
  - defaults:
    + `vesper`: `pane.rename_float = r`
    + `tmux`: `pane.rename_float = r`
    + `zellij`: `pane.rename_float = r`
    + `emacs`: `rename_float = <C-x><C-f>`

* **remote_scroll**: Puts a remote pane in scrolling mode. 
  - defaults: 
    + `vesper`: `terminal.remote_scroll = [`
    + `tmux`: `terminal.remote_scroll = [`
    + `zellij`: `terminal.remote_scroll = [`
    + `emacs`: `remote_scroll = <C-x>[`

* **undo**: Restores the last closed tab, split or float.
  - defaults: 
    + `vesper`: `terminal.undo = u`
    + `tmux`: `terminal.undo = u`
    + `zellij`: `tabs.undo = u`
    + `emacs`: `undo = <C-z>`

* **toggle_fullscreen**: Toggles the floating pane full screen state.
  - defaults:
    + `vesper`: `terminal.toggle_fullscreen = F`
    + `tmux`: `terminal.toggle_fullscreen = F`
    + `zellij`: `pane.toggle_fullscreen = F`
    + `emacs`: `toggle_fullscreen = <F11>`

## Environment

You can set up the environment variables of every opened pane in `vesper` either
by the `config.ini` file or by the `~/.config/vesper/env.lua` file.

### Via ini file

In the config file, you can set an `Environment` section. The section should
be a series of key/values. Every opened terminal will have the variables set.
For example: 

```ini
[Options]
...

[Shortcuts]
...

[Environment]
DISPLAY = xterm-256color
PATH = $PATH:~/bin
```

Every opened pane with the above config file, will have the environment
variables `$DISPLAY` and `$PATH` set with the values from the `ini` file.

You can also script the environment via

### Via the `env.lua` file

In the config folder (`~/.config/nvim` by default), you can add the `env.lua`
file. This file should return a lua table with key/value pairs. Each key
represents the name of an environment variable and each value represents the
value of the respective environment variable.

For example: 

```lua
local term = (os.getenv('VESPER_SESSION') == 'for-tty' and 'screen') or 'xterm-256color'

return {
    TERM = term,
    PATH = os.getenv('PATH') .. ':' .. os.getenv('HOME') .. '/bin',
}
```

If you place this file, then, depending on the session name, each opened pane
will have the `$TERM` variable set either as `screen` or as `xterm-256color`
and the '~/bin' folder added to the `$PATH` variable.

## Copy/pasting

In `vesper`, you can copy paste by using the expected `<C-c>` and `<C-v>`
shortcuts. The interaction between your terminal and the system clipboard is
done via the `clipboard` setting. You can see the meaning of it and also
possible options for possible operating systems
[here](https://neovim.io/doc/user/options.html#'clipboard').

For `nvim` users, you also have `<C-s>pp` for example to paste in `TERMINAL`
mode in `vesper` workflow or `y` in `VISUAL` mode for multiple workflows. 

Whenever you select a text with the mouse, you can then click `<C-c>` and
`<C-v>`. This will paste the currently selected text into the currently
selected pane. 

Other than the mouse, a selection can be created using the keyboard. You can
switch to `VISUAL` mode, via the default shortcuts (see the [shortcuts
section](#shortcuts)) and then using `vim` movements (`h`, `j`, `k`, `l`) or
the cursors and `<pgup>` or `<pgdown>`.

## Remote panes

By default, whenever you open a new pane, it will open a new shell on your
local machine. However, you can call one of the following API functions, to
open a new shell on a remote machine: `create_tab_remote`, `open_remote`,
`open_float_remote` or `split_remote`.

Whenever you call one of these functions, if the variable
`VESPER_REMOTE_CONNECTION` is set, then a remote pane is opened using that
connection. If the `VESPER_REMOTE_CONNECTION` variable is not set, or if the
parameter `force` is set to `true`, then `vesper` will ask the user for the
connection to which he or she wants to connect.

The remote connection has to respect the following format: 

```
<provider>://<path-to-executable>[@user@host]
```

* `provider` represents one of the possible providers (see
  [bellow](#remote-providers))
* `<path-to-executable>` is the path to the provider's executable (at the
  moment the path to `vesper` on the remote machine)
* `user@host` represents the user and the host used for launching the `ssh`
  process.

Let's assume we want to open a remote tab at `my-server.com` where we identify
with the user `john.doe`. On the server `my-server.com` `vesper` is installed
in the folder `~/.local/bin`. In this case, the remote connection will be
`vesper://~/.local/bin/vesper@john.doe@my-server.com`.

**Note**: There is no action to open a pane remote. If you want to have
shortcuts for opening remote panes you will need to use an `init.lua` in the
config folder path to set your own shortcuts (see the
[configuration](#configuration)) section.

However, by setting the variable `VESPER_REMOTE_CONNECTION`, the `create_tab`,
`create_float`, `split_left`, `split_right`, `split_up` and `split_down`
actions will open a remote pane, instead of a local one, by using the
connection indicated in the `VESPER_REMOTE_CONNECTION` variable.

#### Closing a remote pane

A remote pane has to be closed in 2 steps. Since the remote connection can be
dropped due to external factors, the pane will not be discarded, as not to
break the current layout. If the remote connection is lost, then the pane will
display a message letting you know that the connection for that pane is gone
and that you can try to press `r` in this pane in order to try to reconnect,
or `q` to close also the pane.

As a consequence, even if you close the remote pane on purpose by typing
`exit` in the remote pane, the pane will still not be closed. It will be
replaced by the dialog mentioned above. You will have then to also press `q`
if you want to really close the pane as to remove the pane from the layout
also.

#### Scrolling

Since a remote pane is embedded in another instance provided by another app
(usually an `vesper` on a remote machine), the scrolling has to be handled by
that app. So, by putting the local `vesper` in normal mode, will not scroll to
the buffer content. You need to put the remote pane in scrolling mode. This
means that you need to signal the remote `vesper` that you want to scroll. You
can do this by calling the action `remote_scroll` (default shortcut `<C-s>[`
in `vesper` workflow) or by calling directly the function
`remote_enter_scroll_mode` (`require('vesper').remote_enter_scroll_mode()`).

#### Remote providers

Since the remote connection has to only provide means of scrolling in the back
buffer and to keep the session in case the connection is lost to the server,
`vesper` can communicate with several software on the remote machine. Of course,
the best way to open remote panes is by having your local `vesper` communicate
with another `vesper` instance on the remote server. However, if you cannot
install `vesper` on the remote server, but you have there for example `abduco`
or `dtach`, you can have `vesper` communicating with these, rather than `vesper`. 

**Note**: the scrolling provided by `dtach` is lost after you disconnect and
reconnect, while `abduco` does not offer any scrolling. In the future, `vesper`
will be able to communicate with `tmux` and `gnu screen` for a proper
scrolling with other providers than `vesper`. You can use any of these providers
by specifing them in the remote connection.

*dtach*:

```
dtach:///usr/bin/dtach@john.doe@my-server.com
```

*abduco*:

```
abduco:///usr/bin/abduco@john.doe@my-server.com
```

## Passthrough mode

Passthrough mode is a special mode. When you enter passthrough mode, no
shortcut is valid anymore. In order to leave this mode, you need to press the
`passthrough_escape` (default `<C-\><C-s>`)

This solves the issue of running an `vesper` session inside another `vesper`
session. Clicking `<C-s>P` will put you in passthrough mode. So, if for
example you are in your main host session, you click `<C-s>P` then all the
controls are passed through the first session down to the second session.

In order to escape back to the host main session, by default you have to press
inside the second session `<C-\><C-s>`. This is the default modifier. This
will send the control back to the host main session.

## Session support

`Vesper` has very powerfull options to save and restore a session. By invoking
the vesper command `VesperSaveLayout`, your layout will be saved in the selected
file. This means all the floats and the splits and the tabs. 

By calling `VesperRestoreLayout`, the current layout will be overriten by the
layout saved in the file. This means all your current tabs, splits and floats
will be closed and the tabs, splits and floats inside the layout file will be
re-created.

If you also want to save the commands running in a pane, you have two options. 

#### VesperSetCmd

You can call the command `VesperSetCmd`. This variable will be saved together
with the layout. When `VesperRestoreLayout` is called, then the command saved in
the `VesperSetCmd` will be sent to the same pane (float or not, in a split or
not). 

**Note**: The command will not be executed if the restored pane is a remote
pane.

#### VesperSetWinId

If you are used to the way `neovim` works and with `lua`, then you can use
instead `VesperSetWinId`. This will set a variable identifier on the currently
selected pane that will be saved together with the layout. 

To restore the layout, instead of calling the `VesperRestoreLayout` command, you
can call in a lua file the `vesper.restore_layout` function, which takes as a
first argument the file where the layout is saved and as a second argument a
callback with 2 parameters: the vesper terminal structure and this id. This
gives you a much more flexibility to set up your pane upon a layout restore.

For example: `:VesperSaveLayout<cr>`, and then
`~/vesper-sessions/my-saved-session.layout<cr>`. This will save the current
layout in the `~/vesper-sessions/my-saved-session.layout` file.

Then, to restore it, create the following script and save it in
`~/vesper-sessions/my-saved-session.lua` file:

```lua
require('vesper').restore_layout('~/vesper-sessions/my-saved-session.layout', function(t, id)
    if id == "vifm" then
        vesper.send_to_buf(t.buf, 'vifm<cr>', true)
        vim.fn.timer_start(1000, function()
            vesper.send_to_buf(t.buf, ':session my-vifm-session<cr>', true)
        end)
    end
end)
```

Then, in `vesper`, you can do: `<C-s>n` (this will put vesper in `VESPER` mode) and
then `:luafile ~/tmp/my-saved-session.lua<cr>`. This will run the above
script, which in turn, for the pane with the id `vifm` (split, tab or float)
will execute `vifm<cr>`, wait one second for `vifm` to open and then execute
`:session my-vifm-session<cr>`. So, this should restore your `vifm` pane and
inside this pane, should also restore your saved `vifm` session.

**Note**: Be carefull when using the callback with a remote buffer. In case of
a remote buffer, this callback will be called before the buffer is
reconnected. So, you'll need probably to wait until the buffer is reconnected.
You might want to send a `r` key to the pane if you are sure that the remote
is still alive.

### Autosave

If the *autosave* option is set to `always` (the default value) or `often`,
`vesper` will track the current session continously in the folder set by
`autosave_location` option or in the `~/.config/vesper/sessions` folder if the
`autosave_location` option is not set with the name `$VESPER_SESSION.vesper`. For
example, if you start `vesper` like this: `vesper -a demo`, then by default, in
the folder `~/.config/vesper/sessions` the file `demo.vesper` will be created. In
this file, the current session will be tracked.

After you close this session, if the `autosave` options is still true, when
you connect again to the same session (`vesper -a demo`), the layout will be
restored. If in the `autosave_location` folder (default
`~/.config/vesper/sessions`) you also add a file called with the name of the
layout file and followed by the `.lua` extension (for example
`demo.vesper.lua`), then this file will be parsed when restoring the layout and
it's expected that it will return a callback that will be called for every
restored pane. 

For example, if you define the following `demo.vesper.lua` file:

```lua
return function(t, id)
    if id == "vifm" then
        vesper.send_to_buf(t.buf, 'vifm<cr>', true)
        vim.fn.timer_start(1000, function()
            vesper.send_to_buf(t.buf, ':session my-vifm-session<cr>', true)
        end)
    end
end
```

and then you connect to `vesper` like this: `vesper -a demo`, in the pane with
the `vesper` id `vifm`, the `vifm` command will be launched, and after one
second (so that `vifm` has time to open), the session `my-vifm-session` will
be open inside `vifm`.

This allows you to script your session restore via `lua`.

## Undo

`Vesper` keeps a history of closed tabs, floats or splits. After closing a pane,
you can call `VesperUndo` command or click `<C-s>u` (for `vesper` workflow) and
the last closed pane will be restored.

The content of the terminal will be restored by executing the
`undo_restore_cmd` command after restore. If you don't want the content
restored, just set the `undo_restore_cmd` in the `ini` file to nothing.

## Lua API

If you are a `neovim` user and you are familiar with `lua`, you can access the
full power of `vesper` and you can have access to all `neovim` features by
configuring it via an `init.lua` file instead of a simple ini file. See
[here](./api.md) on how to do this.

## Why

I've been a [tmux](https://github.com/tmux/tmux/wiki) user for years. Then
I've discovered [zellij](https://zellij.dev/) and been using for a few months.
They are both amazing pieces of software.

I've been using `tmux` for the obvious reasons. Then, I've switched to
`zellij` because of the floating panels and the edit back buffer in the custom
editor. The floating panels I've been searching it for years and suffered
without them in `tmux`. And then when discovering them in `zellij`, I've helped
implementing the edit in back buffer feature and this made me switch without
looking back. 

However, they both have had some minor issues that were annoying me. For
both of them, for example, changing the themes is not that straight forward
(`:colorscheme tokyonight`?). 

Copy / pasting in `tmux` is painful with the tmux buffer. I mean it was the
best solution at the time, but still... Synchronizing the terminal, vim and X
clipboard was difficult. Especially when working from tty or over ssh.

In this respect, zellij was a big step forward. Open the terminal content
inside vim and I was done. But still, it was a shortcut to press to open the
content, copy whatever was to copy and then close the editor to go back to the
terminal.

And the most annoying issue was the nested session. Open a multiplexer
session, `ssh` to a server and there connect to another session. I've always
fixed this by changing the modifier in the ssh session. But this raised issues
when keeping the dotfiles under git, since I have to treat this modifier in
some way to keep it under git.

`Vesper` solves all these issues. It allows me to have the modal zellij workflow,
combined with the tmux modifier approach. And it solves the nested sessions
issue.

## Cheatsheet
for vesper workflow only.

__Modifier M__: `<C-s>`

### Session

- List all sessions from outside of vesper: `vesper`  
- Create or attach to an existing session: `vesper -a <session-name>`
- Detach from a session (from inside a vesper session): M `d`
- List all sessions and select from inside vesper: M `Ss`

### Scrolling and copying

- Vesper mode: M `n` in order to move the curser arround freely and scroll
- Visual: M `v`, then one of `h i j k` to move into a certain direction to select  
- Copy: select text and then `y`
- paste: `<C-v>`

### Pass-through mode

When for example in an SSH session also running vesper, all shortcuts are
passed through to the remote vesper.

- M `<C-N>` to activate,
- `<C-\>` M to deactivate  

### Panes

- Create new pane (split): M `p`, then one of `H J K L` to split into a certain
direction  
- select pane: M `p`, then one of `h i j k` to select a certain pane  
- resize pane: M `r`, then one of `h i j k` to resize a pane into a certain
 direction  

### Tabs

- Create new tab: M `c`
- Switch to tab: M `1`, ..., i.e. the tab number.
- Switch to first tab: M `H`
- Switch to last tab: M `L`
- Switch to previous tab: M `h`
- Switch to next tab: M `l`

### Floats

- Create new float: M `f`
- Toggle float: M `w`
- move float: M `m`, then one of `h i j k` to move into a certain direction.
`ESC` to exit.  

### Vesper mode

- M `n` to activate  
  - you interact automatically with vesper.  
  - You can click on : and a prompt will appear on top of the status bar.  
  - From Vesper mode hit `i` for Terminal mode or `v` for visual mode
  - If you type Vesper (notice the capital A) and then you click tab, you will
  see a list of all the possible commands you can send to vesper.
  [Command reference](https://github.com/cosminadrianpopescu/azul?tab=readme-ov-file#commands)  
