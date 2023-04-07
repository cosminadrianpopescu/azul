local azul = require('azul')

vim.o.cmdheight = 0
vim.o.encoding = "utf-8"
vim.o.number = false
vim.o.relativenumber = false
vim.o.belloff = "all"
vim.o.laststatus = 3
vim.o.bufhidden = "hide"
vim.o.hidden = true
vim.o.termguicolors = true

vim.api.nvim_command('highlight CurrentFloatSel guifg=#db4b4b')
vim.api.nvim_set_hl(0, 'NormalFloat', {})

azul.set_modifier()

vim.env.XDG_CONFIG_HOME = vim.env.NVIM_XDG_CONFIG_HOME
vim.env.XDG_DATA_HOME = vim.env.NVIM_XDG_DATA_HOME

local config_dir = (vim.env.XDG_CONFIG_HOME or (os.getenv('HOME') .. '/.config')) .. '/azul'
local config_file = config_dir .. '/init.lua'

vim.o.runtimepath = vim.o.runtimepath .. ',' .. config_dir .. '/pack/start/*,' .. config_dir .. '/pack/opt/*,' .. config_dir

local file = io.open(config_file)
if file ~= nil then
    io.close(file)
    vim.api.nvim_command('source ' .. config_file)
end

azul.open()
