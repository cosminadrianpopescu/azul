local azul = require('azul')
local cfg = require('config')
local funcs = require('functions')

local unmap_all = function(mode)
    local collection = vim.tbl_filter(function(x) return x.m == mode end, azul.get_mode_mappings())
    for _, m in ipairs(collection) do
        local cmd = m.real_mode .. 'unmap ' .. m.ls
        local result = pcall(function() vim.api.nvim_command(cmd) end)
        if not result then
            print(cmd .. " failed")
        end
    end
end

local remap_all = function(mode)
    local collection = vim.tbl_filter(function(x) return x.m == mode end, azul.get_mode_mappings())
    for _, m in ipairs(collection) do
        vim.api.nvim_set_keymap(m.real_mode, m.ls, m.rs, m.options)
    end
end

azul.on('ModeChanged', function(args)
    local wf = azul.get_current_workflow()
    local old_mode = args[1]
    local new_mode = args[2]
    if cfg.default_config.options.blocking_cheatsheet and ((wf == 'azul' and new_mode == 't') or (wf == 'tmux' and new_mode == 'n')) then
        return
    end
    unmap_all(old_mode)
    remap_all(new_mode)
end)
