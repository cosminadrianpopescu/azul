return {
    setup = function()
        local azul = require('azul')

        vim.api.nvim_create_user_command('AzulHideFloats', function()
            azul.hide_floats()
        end, {desc = "Hides the floats"});

        vim.api.nvim_create_user_command('AzulOpen', function()
            azul.open()
        end, {desc = "Opens a new terminal"})

        vim.api.nvim_create_user_command('AzulEnterMode', function(opts)
            azul.enter_mode(opts.fargs[1])
        end, {nargs = 1, desc = 'Enters an azul mode'})

        vim.api.nvim_create_user_command('AzulShowFloats', function()
            azul.show_floats(vim.t.float_group or nil)
        end, {desc = 'Show floats'})

        vim.api.nvim_create_user_command('AzulOpenFloat', function()
            azul.open_float(vim.t.float_group or nil)
            if azul.get_current_workflow() ~= 'azul' then
                vim.api.nvim_command('startinsert')
            end
        end, {desc = 'Creates a new float'})

        vim.api.nvim_create_user_command('AzulToggleFloats', function()
            azul.toggle_floats(vim.t.float_group or nil)
        end, {desc = 'Toggles the floats visibility'})

        vim.api.nvim_create_user_command('AzulMoveCurrentFloat', function(opts)
            local dir = opts.fargs[1]
            local inc = opts.fargs[2] or 5
            azul.move_current_float(dir, inc)
        end, {nargs = "+", desc = 'Moves the currently selected float'})

        vim.api.nvim_create_user_command('AzulSelectPane', function(opts)
            azul.select_next_pane(opts.fargs[1], vim.t.float_group or nil)
        end, {nargs = 1, desc = "Selects the next pane in the given direction"})

        vim.api.nvim_create_user_command('AzulSendToCurrentPane', function(opts)
            azul.send_to_current(opts.fargs[1], opts.bang)
        end, {bang = true, nargs = 1, desc = "Sends the text to the currently selected terminal"})

        vim.api.nvim_create_user_command('AzulToggleNestedSession', function(opts)
            local delim = (#opts.fargs and opts.fargs[1]) or nil
            if azul.get_current_workflow() ~= '' then
                azul.enter_mode('t')
            end
            vim.fn.timer_start(1, function()
                azul.toggle_nested_mode()
            end)
        end, {desc = "Toggle the nesting of the current session"})

        vim.api.nvim_create_user_command('AzulPositionCurrentFloat', function(opts)
            azul.position_current_float(opts.fargs[1])
        end, {desc = "Positions the currently selected float", nargs = 1})

        vim.api.nvim_create_user_command('AzulRedraw', azul.redraw, {desc = "Redraws the screen"})
        vim.api.nvim_create_user_command('AzulSuspend', azul.suspend, {desc = "Suspends all azul events"})
        vim.api.nvim_create_user_command('AzulResume', azul.resume, {desc = "Resumes all azul events"})
        vim.api.nvim_create_user_command('AzulDisconnect', azul.disconnect, {desc = "Disconnects the current session"})
        vim.api.nvim_create_user_command('AzulSaveLayout', function()
            local where = vim.fn.input({prompt = "Select a file: ", completion = "file"})
            if where == nil then
                return
            end
            azul.save_layout(vim.fn.fnamemodify(where, ':p'))
        end, {desc = "Saves the layout"})
        vim.api.nvim_create_user_command('AzulRestoreLayout', function()
            local where = vim.fn.input({prompt = "Select a file: ", completion = "file"})
            if where == nil then
                return
            end
            azul.restore_layout(vim.fn.fnamemodify(where, ':p'))
        end, {desc = "Restores a layout"})
        vim.api.nvim_create_user_command('AzulSetWinId', function(opts)
            azul.set_win_id(opts.fargs[1])
            vim.fn.timer_start(1, function()
                vim.api.nvim_command('startinsert')
            end)
        end, {desc = "Sets a win id for the currently selected terminal", nargs = 1})

        vim.api.nvim_create_user_command('AzulSetCmd', function(opts)
            azul.set_cmd(opts.fargs[1])
            vim.fn.timer_start(1, function()
                vim.api.nvim_command('startinsert')
            end)
        end, {desc = "Sets a command to be run in the current terminal uppon a restore", nargs = 1})
        vim.api.nvim_create_user_command('AzulStartLogging', function()
            local where = vim.fn.input({prompt = "Select a file: ", completion = "file"})
            azul.start_logging(where)
            vim.fn.timer_start(1, function()
                vim.api.nvim_command('startinsert')
            end)
        end, {desc = "Starts logging the current terminal scrollback buffer"})
        vim.api.nvim_create_user_command('AzulStopLogging', function()
            azul.stop_logging()
            vim.fn.timer_start(1, function()
                vim.api.nvim_command('startinsert')
            end)
        end, {desc = "Stops the logging of the current terminal scrollback buffer"})
    end
}
