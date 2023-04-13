# Azul

An nvim based terminal multiplexer. 

## Install

You can install azul in several ways:

### Default 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
./install.sh
```

This will install azul inside the `~/.local` folder. Then, to run it, you
need to run `azul` (if `~/.local/bin`) is in your path. Otherwise, you can run
directly `~/.local/bin/azul`

### Custom folder

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_PREFIX=~/programs/azul ./install.sh
```

This will install `azul` in the `~/programs/azul` folder. Then, to run it,
just run `~/programs/azul/bin/azul`.

### Install in /usr/bin

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_PREFIX=/usr sudo ./install.sh
```

This will install `azul` in the `/usr` folder. Then you can run it by simply
running `azul`.

*NOTE*: In case your `nvim` executable is not `nvim`, you need to specify this
when installing by using the variable `AZUL_NVIM_EXE`. For example: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_NVIM_EXE=/opt/nvim.appimage ./install.sh
```

## Features

### Flexibile workflow. 

You can choose to use a normal `tmux` workflow (with a main modifier followed
by the command for `azul`), a normal `zellij` workflow (with shortcuts
directly for selecting various modes), or a hybrid approach, like I do. I like
the modes given by `zellij`, but I prefer to use a modifier to interact with
`azul` all the other keys go normally to my terminal. Or you can even choose
an emacs like workflow (where you stay only in terminal mode and you do
everything via modifiers, so on modes at all). 

You have examples of these configs (`tmux.lua`, `zellij.lua` and `emacs.lua`)

### Floating panes

You can call `:lua require('azul').open_float()` to open a new float terminal
that you can then manipulate easily via special modes.

### Custom modes

`Azul` introduces some new modes if you need to interact with the floating
panes or with splits. You have the `Pane select` mode (`'p'`), `Float move`
mode (`'m'`), `Pane resize` mode (`'r'`) and `Split` (`'s'`) mode. 

This custom modes are built on top of the `neovim` normal mode, by default.
You can look at them as submodes of `normal` mode. This means that any
shortcut valid in normal that is not defined in these modes will work also in
these modes. But any shortcut defined in these modes will have priority over
the normal ones.

I use these modes because I like (as seen in the demo movie) to open a float
and then quickly position it on the screen using `hjkl` movement. Or to resize
it using `hjkl` movement. Of course, you can use some shortcuts with modifiers
for there operations (like `<C-h>` to move a float to the left and so on) and
then you don't need to use these modes. These modes are completely optional.
In order to use them, you need to use the `require('azul').set_key_map`
function instead of `vim.api.nvim_set_keymap` to set a keymap. The parameters
are identical (see the example config provided).

Sometimes (see the `zellij.lua` workflow config), you might want to build this
modes as submode of another vim mode (like terminal). This might happen
because you want to switch to panel mode (for example) from terminal mode,
rather than passing through normal mode. In this case, you have to set the
`base_mode` parameter in the options table when calling
`require('azul').set_key_map`. See the `zellij.lua` file for an example.

### Nested mode

This solves the issue of running an `azul` session inside another `azul`
session. Calling the `require('azul').toggle_nested_mode` function will toggle
the control between the 2 sessions. So, if for example you are in your main
host session, you call `toggle_nested_mode` then all the controls are passed
through the first session down to the second session. When you call the
function again, it will pass the control back to the host main session.

In order to escape back to the host main session, by default you have to click
inside the second session `<C-\><C-s>`. This is the default modifier. This
will call again `toggle_nested_mode` and it will send the control back to the
host main session.

If you want to change the escape sequence, you can pass a new escape sequence
to the initial call of the `toggle_nested_mode` function. So, for example, by
calling `require('azul').toggle_nested_mode('<C-x>')` will pass the control to
the second session (the guest `azul` session) and then, in order to pass the
control back to the host main section, you need to press `<C-x>`. This allows
you in theory to have as many nested sessions as you want.

For example, you can do in your host main session
`require('azul').toggle_nested_mode('<C-\><C-1>')` and then, in your second
session to do another ssh and to start another `azul` session. There (in your
second session), you can do
`require('azul').toggle_nested_mode('<C-\><C-2>')`. This would pass the
control to the third session (second guest session). In this second guest
session, you can do your job. When you finish, you press `<C-\><C-2>` and the
control is passed back to your first guest session (second session). Here, you
can press again `<C-\><C-1>` and the control will be passed back to the host
main session.

### Infinite customizability

Remember, you are running inside a `neovim`. So, you can install any plugin,
any color scheme and you can manipulate your multiplexer in anyway allowed by
`neovim`. So, you can add any window manager that you like for handling your
floats, you can add any plugin to handle your status and you can basically do
anything that you might think of, as long as `neovim` allows it (and neovim
allows a lot...). You can even have macros, if you want, in your terminals...
How about that?

## Why?

I've been a [tmux](https://github.com/tmux/tmux/wiki) user for years. Then
I've discovered [zellij](https://zellij.dev/) and been using for the past
months. They are both amazing pieces of software.

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
session, ssh to a server and there connect to another session. I've always
fixed this by changing the modifier in the ssh session. But this raised issues
when keeping the dotfiles under git, since I have to treat this modifier in
some way to keep it under git.

`Azul` solves all this issues. It allows me to have the modal zellij workflow,
combined with the tmux modifier approach. And it solves the nested sessions
issue.

### Advantages over `tmux` or `zellij`

#### Status bar or tabline

You are inside neovim. So, you can use any plugin you want to handle the
status bar or the tabline, you can have both, you can have none, the sky (or
should I say neovim) is the limit. My status bar that you saw in the demo
video is using [lualine](https://github.com/nvim-lualine/lualine.nvim) with a
minimal configuration. But you can choose whatever you like.

#### Very flexibile shortcuts

Again, you are in neovim. You can have whatever shortcuts neovim supports. You
can have these shortcuts inside command mode, inside terminal mode (so inside
the real terminal), in normal mode, in visual mode, you name it...

#### Nested mode

As you seen in the video, you can connect to a ssh session, press a shortcut
(in my case `<A-n>`) and then all the keys are passed to the nested session.
To pass the control back, you press the escape shortcut `<C-\><C-s>` (this is
the default, but you can set your own) and you control again the main session.
Very neat...

### Disadvantages compared with `tmux` or `zellij`

#### Lack of session

Of course, the biggest issue with `azul` is the lack of session support. This
is being currently handled in `neovim`
[here](https://github.com/neovim/neovim/issues/5035). When this will be
merged, then `azul` will recuperate this disadvantage.

Until then, if your session needs are complex (like for example opening
another session in the current multiplexer, somehow persist the session over a
reboot, or any other scenario that you might think of), then probably `azul`
is not for you. 

If your session needs are minimal (like mine), then you can use something like
[abduco](https://github.com/neovim/neovim/issues/5035) or
[dtach](https://dtach.sourceforge.net/) to handle the sesion outside `azul`.

My normal scenario is to open `azul` with a few tabs and then dettach from
that session and re-attach later (especially over ssh). For this `abduco` is
enough for me.

#### Cursor support

Cursor in `neovim` in terminal mode is a kind of hack. See
[here](https://github.com/neovim/neovim/issues/3681) and
[here](https://github.com/neovim/neovim/issues/3681) for more details. Until
these issues are being fixed, `azul` will have to live with the block cursor
inside its terminals. The only thing that we have in `azul` for configuring
the cursor is `:highlight TermCursor`.

If this is something that you cannot live without (having a proper cursor
inside your terminal), again, `azul` is probably not for you yet.

## Configuring

`Azul` tries to be as unopinionated as possibly. Because of this, it does not
define any shortcuts by default. If you just install it and run it, it will
show you in a bare terminal with a minimal status bar. But configuring it is
extremely flexible (it's basically neovim configuration). 

You have in the repositories 3 examples for 3 different workflows.
(`tmux.lua`, `zellij.lua` and `emacs.lua`). These files, together with the API
documentation should give you an idea of how to configure your environment. 

In order to configure it, you need to create the `$XDG_CONFIG_HOME/azul`
folder. This is usually `~/.config/azul`. Inside this file, you put all your
settings in `init.lua` or `init.vim` (of course in lua language or vimscript).

If you want to install some plugins, inside of `~/.config/azul` you need to
create the folder `pack` and inside this folder the folders `start` and `opt`
(the normal vim pack folders structure - `~/.config/azul/pack/opt` and
`~/.config/azul/pack/start`). Of course, here you can put a plugin manager
also. My config uses [lualine](https://github.com/nvim-lualine/lualine.nvim)
and [tokyonight](https://github.com/folke/tokyonight.nvim) plugins.

If you think that the documentation is too small for a serious software, this
is because the neovim documentation is azul's documentation. I just enumerated
here what you can do with azul which is somehow different than normal nvim.
The rest is the same as nvim. For example, you want to see what the terminal
can do, you can read
[here](https://neovim.io/doc/user/nvim_terminal_emulator.html). If you want to
see the shortcuts api, you can see it
[here](https://neovim.io/doc/user/map.html). If you want to see what events
you can hook into, you can see it [here](https://neovim.io/doc/user/map.html).
And so on. I think you got the idea...

## How it works



## Requirements

* `Neovim` >= 0.9, because of the floating windows title.
