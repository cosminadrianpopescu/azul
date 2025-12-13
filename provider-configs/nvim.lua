vim.cmd([[
  highlight Normal guibg=none
]])

vim.o.laststatus = 0
-- vim.o.filetype = 'fish'
vim.o.buftype = 'nowrite'
vim.o.modifiable = false
vim.o.clipboard = "unnamedplus"

vim.api.nvim_command("normal G")
vim.api.nvim_create_autocmd({'BufEnter'}, {
    pattern = "*", callback = function()
        vim.api.nvim_command('normal G')
    end
})

local set_map = function(key)
    vim.api.nvim_set_keymap('n', key, '', {
        callback = function()
            vim.api.nvim_command('qall!')
        end
    })
end

vim.api.nvim_set_keymap('n', ':', '', {})

local shortcuts = {'a', 'A', 'i', 'I', '<ins>', 'q'}
for _, s in pairs(shortcuts) do
    set_map(s)
end
