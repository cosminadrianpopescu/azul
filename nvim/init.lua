local f = require('nvim-multiplexer').set_key_map

f('t', '<c-s>', '<C-\\><C-n>', {})
f('n', 'c', '', {
    callback = function()
        require('nvim-multiplexer').open_normal()
        vim.api.nvim_command('startinsert')
    end
})

f('n', 'p', '', {
    callback = require('nvim-multiplexer').enter_pane_mode
})

f('p', '<cr>', '', {
    callback = require('nvim-multiplexer').exit_pane_mode
})

f('p', 'l', '', {
    callback = function()
        print('did l in pane mode')
    end
})
local options = {noremap = true}
f('c', '<C-n>', '<Down>', options)
f('c', '<C-p>', '<Up>', options)

local disable_vim_cmd = function(cmd)
    vim.api.nvim_command("cabbrev " .. cmd .. " <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'echo' : 'q')<CR>")
end

vim.o.runtimepath = vim.o.runtimepath .. ','
vim.o.cmdheight = 0
vim.o.encoding = "utf-8"
vim.o.number = false
vim.o.relativenumber = false
vim.o.backupdir = "/tmp"
vim.o.backup = false
vim.o.belloff = "all"
vim.o.laststatus = 2
vim.o.autoread = true
vim.o.bufhidden = "hide"
vim.o.hidden = true
vim.o.mouse = ""
vim.o.expandtab = true
vim.o.smarttab = true
vim.o.updatetime = 500
vim.o.completeopt = "menu,menuone,noselect"
vim.o.showtabline = 2
vim.o.dir = "/tmp"
vim.o.wildmode = "longest,list"
vim.o.signcolumn = 'number'
vim.o.foldmethod = "syntax"
vim.o.termguicolors = true
vim.g.TerminusInsertCursorShape = 0
-- vim.o.guicursor = 'n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon17'
vim.api.nvim_command('colorscheme ' .. (os.getenv('VIM_COLORS') or 'tokyonight-night'))
disable_vim_cmd("q")
disable_vim_cmd("qu")
disable_vim_cmd("qui")
disable_vim_cmd("quit")
disable_vim_cmd("quita")
disable_vim_cmd("quital")
disable_vim_cmd("quitall")
disable_vim_cmd("qa")
disable_vim_cmd("qal")
disable_vim_cmd("qall")

require('nvim-multiplexer').open_normal()
