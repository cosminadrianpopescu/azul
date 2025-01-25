local azul = require('azul')
local cfg = require('config')
local funcs = require('functions')

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
    -- for _, m in ipairs(collection) do
    --     vim.api.nvim_set_keymap(m.real_mode, m.ls, m.rs, m.options)
    -- end
    for _, m in ipairs(collection) do
        vim.api.nvim_set_keymap(m.real_mode, m.ls, '', {
            callback = function()
                -- unmap_all(mode, modifier)
                azul.run_map(m)
            end,
            desc = m.desc,
        })
    end
end

azul.on('ModifierTrigger', function(args)
    local mode = args[1]
    local modifier = args[2]
    if cfg.default_config.options.blocking_cheatsheet and cfg.default_config.options.use_cheatsheet then
        return
    end
    save_current_mappings(mode, modifier)
    remap_all(mode)
    set_cancel_shortcut('<esc>', mode)
    set_cancel_shortcut('<C-c>', mode)
end)

azul.on('ModifierFinished', function(args)
    local mode = args[1]
    local modifier = args[2]
    if cfg.default_config.options.blocking_cheatsheet and cfg.default_config.options.use_cheatsheet then
        return
    end
    unmap_all(mode)
    restore_previous_mappings(mode, modifier)
end)

azul.on('ModeChanged', function(args)
    local old_mode = args[1]
    local new_mode = args[2]

    if not azul.is_modifier_mode(old_mode) then
        unmap_all(old_mode)
    end

    if not azul.is_modifier_mode(new_mode) then
        remap_all(new_mode)
    end
end)
