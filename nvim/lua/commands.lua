local funcs = require('functions')
local ERRORS = require('error_handling')

local params_map = {
    VesperEnterMode = {
        '*the mode',
    },
    VesperMoveCurrentFloat = {
        '*direction (left, right, up or down)',
        'increment',
    },
    VesperSelectPane = {
        '*direction (left, right, up or down)',
    },
    VesperTogglePassthrough = {
        '*the escape sequence',
    },
    VesperPositionCurrentFloat = {
        '*region (top, bottom, start or end)',
    },
    VesperSaveLayout = {
        'the location',
    },
    VesperRestoreLayout = {
        'the location',
    },
    VesperSetWinId = {
        '*the id of the pane',
    },
    VesperSetCmd = {
        '*the command to be launched uppon a restore',
    },
    VesperStartLogging = {
        '*the file location'
    },
    VesperEdit = {
        'the file in to edit (optional)'
    },
    VesperSelectTab = {
        '*the tab to select'
    }
}

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
        end, {desc = "Hiddens all the floats. "});

        vim.api.nvim_create_user_command('VesperOpen', function()
            core.open()
        end, {desc = "Opens a new tab with a new shell. "})

        vim.api.nvim_create_user_command('VesperEnterMode', function(opts)
            core.enter_mode(opts.fargs[1])
        end, {nargs = 1, desc = 'Puts `vesper` in the requested mode.\n\n**Parameters**:\n\n * the mode (p or r or s or m or T or n or t or v)'})

        vim.api.nvim_create_user_command('VesperShowFloats', function()
            F.show_floats(funcs.current_float_group())
        end, {desc = 'Shows the currently opened floats. If no floats are created yet, then nothing\nwill be shown. If the option `link_floats_with_tabs` is true, then it shows\nthe currently opened floats on the current tab.'})

        vim.api.nvim_create_user_command('VesperOpenFloat', function()
            F.open_float({group = funcs.current_float_group()})
        end, {desc = 'Creates a new float on the current tab. If the option `link_floats_with_tabs`\nis set to `true`, then this float will only be visible on the currently\nselected tab.'})

        vim.api.nvim_create_user_command('VesperToggleFloats', function()
            F.toggle_floats(funcs.current_float_group())
        end, {desc = 'Toggles the opened floats visibility. If `link_floats_with_tabs` is true, then\nit toggles the visibility of opened floats for the current tab.'})

        vim.api.nvim_create_user_command('VesperMoveCurrentFloat', function(opts)
            local dir = opts.fargs[1]
            local inc = opts.fargs[2] or 5
            F.move_current_float(dir, inc)
        end, {nargs = "+", desc = 'Moves the currently selected float in the given direction with the given\nincrement.\n\n**Parameters**:\n\n* direction (left, right, up or down) - mandatory\n* increment (number) - optional. If missing, then the float will be moved by 5\npixels '})

        vim.api.nvim_create_user_command('VesperSelectPane', function(opts)
            core.select_next_pane(opts.fargs[1], funcs.current_float_group())
        end, {nargs = 1, desc = "Selects the next pane in the indicated direction\n\n**Parameters**:\n\n* direction (left, right, up or down)"})

        vim.api.nvim_create_user_command('VesperSendToCurrentPane', function(opts)
            core.send_to_current(opts.fargs[1], opts.bang)
        end, {bang = true, nargs = 1, desc = "Sends the indicated text to the currently selected pane. This commands accepts\nafter it a `!` symbol. This means that the characters will be escaped.\n\nFor example:\n\n`:VesperSendToCurrentPane ls -al<cr>` will send to the current pane the literal\ntext `ls -al<cr>`. The `<cr>` will not be replaced by an `enter`.\n\n`:VesperSendToCurrentPane! ls -al<cr>` will send to the current pane the text\n`ls -al` followed by an enter (notice the exclamation marc after the command)\n\n**Parameters**:\n\n* the text to send to the currently selected pane"})

        vim.api.nvim_create_user_command('VesperTogglePassthrough', function(opts)
            local delim = (#opts.fargs and opts.fargs[1]) or nil
            if core.get_current_workflow() ~= '' then
                core.enter_mode('t')
            end
            ERRORS.defer(1, function()
                core.toggle_passthrough(delim)
            end)
        end, {desc = "Toggles the passthrough mode.\n\n**Parameters**:\n\n* The escape sequence", nargs = '?'})

        vim.api.nvim_create_user_command('VesperPositionCurrentFloat', function(opts)
            F.position_current_float(opts.fargs[1])
        end, {desc = "Positions the currently selected floating pane in a region of the screen.\n\n**Parameters**:\n\n* the screen region where to position the float (top, bottom, start or end)", nargs = 1})

        vim.api.nvim_create_user_command('VesperRedraw', core.redraw, {desc = "Redraws the terminal"})
        vim.api.nvim_create_user_command('VesperSuspend', core.suspend, {
            desc = "Suspends all the `vesper` events. This is an usefull command for advanced users\nwho might want to open something in an underlying `nvim` buffer. Normally,\nthat something would be overriten by a new shell. In order to prevent this,\nyou can suspend the `vesper` events, finish your job and then resume the `vesper`\nevents."
        })
        vim.api.nvim_create_user_command('VesperResume', core.resume, {
            desc = "Resumes the `vesper` events. This is an usefull command for advanced users\nwho might want to open something in an underlying `nvim` buffer. Normally,\nthat something would be overriten by a new shell. In order to prevent this,\nyou can suspend the `vesper` events, finish your job and then resume the `vesper`\nevents."
        })
        vim.api.nvim_create_user_command('VesperDisconnect', core.disconnect, {
            desc = "Disconnects the current session"
        })
        vim.api.nvim_create_user_command('VesperSaveLayout', function(opts)
            get_file_if_missing(opts, function(where)
                session.save_layout(vim.fn.fnamemodify(where, ':p'))
            end)
        end, {
                desc = "Saves the current layout. Uppon invoking this command, you will be met with a\nprompt at the bottom of the screen, on top of the status bar, to indicate a\nfile name where you wish to save your layout. You can type a full path to a\nfile, using `tab` for autocompletion.\n\n`Vesper` has very powerfull features for saving and restoring saved sessions.\nSee the [Session support section](#session-support)\n\n**Parameters**:\n* The file in which to save the layout (optional) ",
                nargs = "?", complete = "file"
            })
        vim.api.nvim_create_user_command('VesperRestoreLayout', function(opts)
            get_file_if_missing(opts, function(where)
                session.restore_layout(vim.fn.fnamemodify(where, ':p'))
            end)
        end, {
                desc = "Restores a saved layout. Uppon invoking this command, you will be met with a\nprompt at the bottom of the screen, on top of the status bar, to indicate a\nfile name where you wish to save your layout. You can type a full path to a\nfile, using `tab` for autocompletion.\n\n`Vesper` has very powerfull features for saving and restoring saved sessions.\nSee the [Session support section](#session-support)\n**Parameters**:\n\n* The file from which to restore the layout (optional)",
                nargs = "?", complete = "file"
            })
        vim.api.nvim_create_user_command('VesperSetWinId', function(opts)
            core.set_win_id(opts.fargs[1])
        end, {
                desc = "Sets a vesper windows id for the currently selected pane. See the [Session\nsupport section](#session-support) for why you would set and how you would use\nthis id\n\n**Parameters**:\n\n* the id of the pane",
                nargs = 1
            })

        vim.api.nvim_create_user_command('VesperSetCmd', function(opts)
            core.set_cmd(opts.fargs[1])
        end, {
                desc = "Sets a command to be launched uppon a restore. For more info, see the [Session\nsupport section](#session-support).\n\n**Parameters**:\n\n* the command to be launched uppon a restore ",
                nargs = 1
            })
        vim.api.nvim_create_user_command('VesperStartLogging', function(opts)
            get_file_if_missing(opts, function(where)
                core.start_logging(where)
            end)
        end, {
                desc = "Starts logging the current terminal scrollback buffer.\n\n**Note**: this commands does not log what is visibile on the screen. Only what\nis in the scroll buffer.\n\n**Parameters**:\n\n* The file in which to start logging (optional)",
                complete = "file", nargs = "?"
            })
        vim.api.nvim_create_user_command('VesperStopLogging', function()
            core.stop_logging()
        end, {
                desc = "If started, stops the current terminal logging of the scroll buffer."
            })
        vim.api.nvim_create_user_command('VesperRenameCurrentTab', function()
            core.rename_current_tab()
        end, {desc = "Renames the currently selected tab."})
        vim.api.nvim_create_user_command('VesperRenameCurrentFloat', function()
            F.rename_current_pane()
        end, {desc = "Renames the current floating pane"})
        vim.api.nvim_create_user_command('VesperEdit', function(opts)
            get_file_if_missing(opts, function(file)
                core.edit(core.get_current_terminal(), file)
            end)
        end, {
                desc = "Edits a file in the current terminal by opening in the editor set by the\n`editor` options or the `$EDITOR` variable on your system.\n\n**Parameters**:\n\n* The file in to edit (optional)",
                complete = "file", nargs = "?"
            })
        vim.api.nvim_create_user_command('VesperEditScrollback', function()
            core.edit_current_scrollback()
        end, {desc = "Edits the current terminal's buffer in the editor set by the `editor` option\nor the `$EDITOR` variable on your system."})
        vim.api.nvim_create_user_command('VesperEditScrollbackLog', function()
            core.edit_current_scrollback_log()
        end, {desc = "Edits the current terminal's scrollback log in the editor set by the `editor`\noption or the `$EDITOR` variable on your system. If the logging is not started\nusing `VesperStartLogging` command, an error message is thrown."})
        vim.api.nvim_create_user_command('VesperSelectTab', function(opts)
            core.select_tab(opts.fargs[1])
        end, {
                desc = "Select the tab indicated by the number in parameter. If the tab does not\nexists (for example you are trying to select the 5th tab, but only have 4\ntabs) it will throw an error.\n\n**Parameters**:\n\n* The tab to select",
                nargs = 1
            })
        vim.api.nvim_create_user_command('VesperReloadConfig', function()
            require('config').reload_config()
        end, {desc = "Reloads the current configuration"})
        vim.api.nvim_create_user_command('VesperEditConfig', function()
            require('config').edit_config()
        end, {desc = "Edits the current configuration in the currently selected pane (embedded or\nfloating)"})
        vim.api.nvim_create_user_command('VesperQuit', function()
            vim.api.nvim_command('quitall!')
        end, {desc = 'Exists vesper closing all the current panes and saving the session if autosave\nis set. This is the recommended way to quit vesper, if you want your session\nto be preserver for the next time you open it.'})
        vim.api.nvim_create_user_command('VesperUndo', function()
            require('vesper').undo()
        end, {desc = 'Reopens the last tab, float or split closed'})
        vim.api.nvim_create_user_command('VesperToggleFullscreen', function()
            F.toggle_fullscreen(core.get_current_terminal())
        end, {desc = 'Toggles the currently selected floating pane full screen, or if the pane is\nalready full screen, it will toggle it to the original state'})
        vim.api.nvim_create_user_command('VesperCd', function(opts)
            core.cd(opts.fargs[1])
        end, {desc = 'Changes the current directory of the current pane', complete = "dir", nargs = '?'})
        vim.api.nvim_create_user_command('VesperDumpScrollback', function(opts)
            FILES.write_file(opts.fargs[1], core.fetch_scrollback())
        end, {desc = 'Dumps the content of the scrollback buffer of the current terminal in the\nindicated file', complete = "file", nargs = 1})
    end,
    param_desc = function(command, idx)
        if params_map[command] == nil or idx < 1 or idx > #params_map[command] then
            return ''
        end

        return params_map[command][idx]
    end,
    command_params_length = function(command)
        return #params_map[command]
    end,
    list = function()
        return vim.tbl_filter(function(c) return vim.fn.match(c.name, "\\v^Vesper") ~= -1 end, vim.api.nvim_get_commands({}))
    end,
}
