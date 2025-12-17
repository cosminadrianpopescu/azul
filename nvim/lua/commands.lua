local funcs = require('functions')
local ERRORS = require('error_handling')

local get_file_if_missing = function(opts, callback)
    local core = require('core')
    local file = opts.fargs[1]
    if file == nil then
        core.get_file(function(where)
            callback(vim.fn.fnamemodify(where, ':p'))
        end)
    else
        callback(vim.fn.fnamemodify(file, ':p'))
    end
end

return {
    setup = function()
        local core = require('core')
        local session = require('session')
        local F = require('floats')
        local FILES = require('files')

        vim.api.nvim_create_user_command('VesperHideFloats', function()
            F.hide_floats()
        end, {desc = "Hides the floats"});

        vim.api.nvim_create_user_command('VesperOpen', function()
            core.open()
        end, {desc = "Opens a new terminal"})

        vim.api.nvim_create_user_command('VesperEnterMode', function(opts)
            core.enter_mode(opts.fargs[1])
        end, {nargs = 1, desc = 'Enters a vesper mode'})

        vim.api.nvim_create_user_command('VesperShowFloats', function()
            F.show_floats(funcs.current_float_group())
        end, {desc = 'Show floats'})

        vim.api.nvim_create_user_command('VesperOpenFloat', function()
            F.open_float({group = funcs.current_float_group()})
        end, {desc = 'Creates a new float'})

        vim.api.nvim_create_user_command('VesperToggleFloats', function()
            F.toggle_floats(funcs.current_float_group())
        end, {desc = 'Toggles the floats visibility'})

        vim.api.nvim_create_user_command('VesperMoveCurrentFloat', function(opts)
            local dir = opts.fargs[1]
            local inc = opts.fargs[2] or 5
            F.move_current_float(dir, inc)
        end, {nargs = "+", desc = 'Moves the currently selected float'})

        vim.api.nvim_create_user_command('VesperSelectPane', function(opts)
            core.select_next_pane(opts.fargs[1], funcs.current_float_group())
        end, {nargs = 1, desc = "Selects the next pane in the given direction"})

        vim.api.nvim_create_user_command('VesperSendToCurrentPane', function(opts)
            core.send_to_current(opts.fargs[1], opts.bang)
        end, {bang = true, nargs = 1, desc = "Sends the text to the currently selected terminal"})

        vim.api.nvim_create_user_command('VesperTogglePassthrough', function(opts)
            local delim = (#opts.fargs and opts.fargs[1]) or nil
            if core.get_current_workflow() ~= '' then
                core.enter_mode('t')
            end
            ERRORS.defer(1, function()
                core.toggle_passthrough(delim)
            end)
        end, {desc = "Toggle the nesting of the current session", nargs = '?'})

        vim.api.nvim_create_user_command('VesperPositionCurrentFloat', function(opts)
            F.position_current_float(opts.fargs[1])
        end, {desc = "Positions the currently selected float", nargs = 1})

        vim.api.nvim_create_user_command('VesperRedraw', core.redraw, {desc = "Redraws the screen"})
        vim.api.nvim_create_user_command('VesperSuspend', core.suspend, {desc = "Suspends all vesper events"})
        vim.api.nvim_create_user_command('VesperResume', core.resume, {desc = "Resumes all vesper events"})
        vim.api.nvim_create_user_command('VesperDisconnect', core.disconnect, {desc = "Disconnects the current session"})
        vim.api.nvim_create_user_command('VesperSaveLayout', function(opts)
            get_file_if_missing(opts, function(where)
                session.save_layout(vim.fn.fnamemodify(where, ':p'))
            end)
        end, {desc = "Saves the layout", nargs = "?", complete = "file"})
        vim.api.nvim_create_user_command('VesperRestoreLayout', function(opts)
            get_file_if_missing(opts, function(where)
                session.restore_layout(vim.fn.fnamemodify(where, ':p'))
            end)
        end, {desc = "Restores a layout", nargs = "?", complete = "file"})
        vim.api.nvim_create_user_command('VesperSetWinId', function(opts)
            core.set_win_id(opts.fargs[1])
        end, {desc = "Sets a win id for the currently selected terminal", nargs = 1})

        vim.api.nvim_create_user_command('VesperSetCmd', function(opts)
            core.set_cmd(opts.fargs[1])
        end, {desc = "Sets a command to be run in the current terminal uppon a restore", nargs = 1})
        vim.api.nvim_create_user_command('VesperStartLogging', function(opts)
            get_file_if_missing(opts, function(where)
                core.start_logging(where)
            end)
        end, {desc = "Starts logging the current terminal scrollback buffer", complete = "file", nargs = "?"})
        vim.api.nvim_create_user_command('VesperStopLogging', function()
            core.stop_logging()
        end, {desc = "Stops the logging of the current terminal scrollback buffer"})
        vim.api.nvim_create_user_command('VesperRenameCurrentTab', function()
            core.rename_current_tab()
        end, {desc = "Renames the current tab"})
        vim.api.nvim_create_user_command('VesperRenameCurrentFloat', function()
            F.rename_current_pane()
        end, {desc = "Renames the current floating pane"})
        vim.api.nvim_create_user_command('VesperEdit', function(opts)
            get_file_if_missing(opts, function(file)
                core.edit(core.get_current_terminal(), file)
            end)
        end, {desc = "Edits a file", complete = "file", nargs = "?"})
        vim.api.nvim_create_user_command('VesperEditScrollback', function()
            core.edit_current_scrollback()
        end, {desc = "Edits the current scrollback"})
        vim.api.nvim_create_user_command('VesperEditScrollbackLog', function()
            core.edit_current_scrollback_log()
        end, {desc = "Edits the current scrollback log"})
        vim.api.nvim_create_user_command('VesperSelectTab', function(opts)
            core.select_tab(opts.fargs[1])
        end, {desc = "Selects a tab", nargs = 1})
        vim.api.nvim_create_user_command('VesperReloadConfig', function()
            require('config').reload_config()
        end, {desc = "Reloads the current config"})
        vim.api.nvim_create_user_command('VesperEditConfig', function()
            require('config').edit_config()
        end, {desc = "Edits the current config in the current selected pane"})
        vim.api.nvim_create_user_command('VesperQuit', function()
            vim.api.nvim_command('quitall!')
        end, {desc = 'Exits vesper'})
        vim.api.nvim_create_user_command('VesperUndo', function()
            require('vesper').undo()
        end, {desc = 'Restores the last closed tab, float or split'})
        vim.api.nvim_create_user_command('VesperToggleFullscreen', function()
            F.toggle_fullscreen(core.get_current_terminal())
        end, {desc = 'Toggles the current float full screen'})
        vim.api.nvim_create_user_command('VesperCd', function(opts)
            core.cd(opts.fargs[1])
        end, {desc = 'Changes the current directory of the current pane', complete = "dir", nargs = '?'})
        vim.api.nvim_create_user_command('VesperDumpScrollback', function(opts)
            FILES.write_file(opts.fargs[1], core.fetch_scrollback())
        end, {desc = 'Dumps the content of the scrollback buffer of the current terminal in the indicated file', complete = "file", nargs = 1})
    end
}
