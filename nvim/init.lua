local azul = require('azul')
local files = require('files')

vim.env.XDG_CONFIG_HOME = vim.env.NVIM_XDG_CONFIG_HOME
vim.env.XDG_DATA_HOME = vim.env.NVIM_XDG_DATA_HOME

files.init()
local cfg = require('config')

if files.exists(files.config_dir .. '/config.ini') then
    cfg.load_config(files.config_dir .. '/config.ini')
end
azul.set_workflow(cfg.default_config.options.workflow, cfg.default_config.options.modifier)
cfg.apply_config()

vim.o.cmdheight = cfg.default_config.options.cmdheight
vim.o.scrollback = cfg.default_config.options.scrollback
vim.o.termguicolors = cfg.default_config.options.termguicolors
vim.o.mouse = cfg.default_config.options.mouse
vim.o.shell = cfg.default_config.options.shell
vim.o.encoding = "utf-8"
vim.o.number = false
vim.o.relativenumber = false
vim.o.belloff = "all"
vim.o.laststatus = 3
vim.o.bufhidden = "hide"
vim.o.hidden = true

local config_file = files.config_dir .. '/init.lua'
if not files.try_load_config(config_file) then
    files.try_load_config(files.config_dir .. '/init.vim')
end

vim.fn.timer_start(1, function()
    require('theme')
    azul.open()
end)
