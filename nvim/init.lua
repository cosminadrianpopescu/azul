local azul = require('azul')
local files = require('files')
require('mappings')

vim.env.XDG_CONFIG_HOME = vim.env.NVIM_XDG_CONFIG_HOME
vim.env.XDG_DATA_HOME = vim.env.NVIM_XDG_DATA_HOME

files.init()

if os.getenv('AZUL_IS_REMOTE') ~= '1' then
    local cfg = require('config')
    cfg.apply_config()

    require('cheatsheet')
    require('remote')
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
end

vim.o.shadafile = files.config_dir .. '/nvim/shada'

vim.fn.timer_start(1, function()
    azul.open()
end)
