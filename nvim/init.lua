local azul = require('azul')
local files = require('files')
local funcs = require('functions')
require('mappings')

vim.env.XDG_CONFIG_HOME = vim.env.NVIM_XDG_CONFIG_HOME
vim.env.XDG_DATA_HOME = vim.env.NVIM_XDG_DATA_HOME

files.init()

if not funcs.is_marionette() then
    local cfg = require('config')
    cfg.apply_config()

    require('cheatsheet')
    require('remote')
    require('insert')
    require('commands').setup()

    cfg.set_vim_options()

    require('theme')

    cfg.run_init_lua()
else
    azul.set_workflow('emacs')
    vim.o.laststatus = 0
    vim.o.cmdheight = 0
    vim.o.termguicolors = true
    vim.o.number = false
    vim.o.relativenumber = false
    vim.o.belloff = "all"
    vim.o.bufhidden = "hide"
    vim.o.hidden = true

    -- vim.o.expandtab = true
    -- vim.o.smarttab = true
    vim.o.showtabline = 0
    -- vim.o.completeopt = "menu,menuone,noselect"
    -- vim.o.wildmode = "longest,list"
    vim.o.timeout = true
    vim.o.timeoutlen = 300

    azul.persistent_on('ModeChanged', function(args)
        vim.o.laststatus = (args[2] == 'n' and 3) or 0
    end)

    local config_file = files.config_dir .. '/init.lua'
    if not files.try_load_config(config_file) then
        files.try_load_config(files.config_dir .. '/init.vim')
    end
end

vim.o.shadafile = files.config_dir .. '/nvim/shada'

vim.fn.timer_start(1, function()
    if not funcs.is_marionette() and funcs.is_handling_remote() and os.getenv('AZUL_START_REMOTE') == '1' then
        azul.open_remote()
    else
        azul.open()
    end
end)
