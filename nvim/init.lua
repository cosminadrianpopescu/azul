local azul = require('azul')
local files = require('files')
require('mappings')

vim.env.XDG_CONFIG_HOME = vim.env.NVIM_XDG_CONFIG_HOME
vim.env.XDG_DATA_HOME = vim.env.NVIM_XDG_DATA_HOME

files.init()
local cfg = require('config')
cfg.apply_config()

require('cheatsheet')
require('commands').setup()

cfg.set_vim_options()

require('theme')

cfg.run_init_lua()

vim.o.shadafile = files.config_dir .. '/nvim/shada'

vim.fn.timer_start(1, function()
    azul.open()
end)
