local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local M = {}

local save_current_mappings = function(mode, modifier)
    funcs.save_current_mapping('modifier', modifier:upper(), 't')
    funcs.save_current_mapping('cc', '<C-C>', mode)
    funcs.save_current_mapping('esc', '<Esc>', mode)
end

local restore_previous_mappings = function(mode, modifier)
    funcs.restore_previous_mapping('modifier', modifier:upper(), 't')
    funcs.restore_previous_mapping('esc', '<Esc>', mode)
    funcs.restore_previous_mapping('cc', '<C-c>', mode)
end

local set_cancel_shortcut = function(which, mode)
    vim.api.nvim_set_keymap(mode, which, '', {
        callback = function()
            azul.cancel_modifier()
        end
    })
end

local get_mappings = function(mode)
    local all_mappings = azul.get_mode_mappings()
    return (mode == nil and all_mappings) or vim.tbl_filter(function(x) return x.m == mode end, all_mappings)
end

M.unmap_all = function(mode)
    local collection = get_mappings(mode)
    for _, m in ipairs(collection) do
        local cmd = m.real_mode .. 'unmap ' .. m.ls
        local result = pcall(function() vim.api.nvim_command(cmd) end)
        if not result and mode ~= nil then
            print(cmd .. " failed")
        end
    end
end

M.remap_all = function(mode)
    local collection = get_mappings(mode)
    -- for _, m in ipairs(collection) do
    --     vim.api.nvim_set_keymap(m.real_mode, m.ls, m.rs, m.options)
    -- end
    for _, m in ipairs(collection) do
        vim.api.nvim_set_keymap(m.real_mode, m.ls, '', {
            callback = function()
                -- M.unmap_all(mode, modifier)
                azul.run_map(m)
            end,
            desc = m.desc,
        })
    end
end

azul.persistent_on('ModifierTrigger', function(args)
    local mode = args[1]
    local modifier = args[2]
    if options.blocking_cheatsheet and options.use_cheatsheet then
        return
    end
    save_current_mappings(mode, modifier)
    M.remap_all(mode)
    set_cancel_shortcut('<esc>', mode)
    set_cancel_shortcut('<C-c>', mode)
end)

azul.persistent_on('ModifierFinished', function(args)
    local mode = args[1]
    local modifier = args[2]
    if options.blocking_cheatsheet and options.use_cheatsheet then
        return
    end
    M.unmap_all(mode)
    restore_previous_mappings(mode, modifier)
end)

azul.persistent_on('ModeChanged', function(args)
    local old_mode = args[1]
    local new_mode = args[2]

    if not azul.is_modifier_mode(old_mode) then
        M.unmap_all(old_mode)
    end

    if not azul.is_modifier_mode(new_mode) then
        M.remap_all(new_mode)
    end
end)

return M
