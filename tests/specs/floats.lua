local t = require('test-env')
local azul = require('azul')
local options = require('options')

local by_state = function(state)
    return (state and 'floating') or 'embedded'
end

local assert_current_terminal = function(state)
    local term = azul.get_current_terminal()
    t.assert(azul.is_float(term) == state, 'The selected terminal should be ' .. by_state(state))
end

local assert_terminals_for_floating = function(no, state)
    local terms = vim.tbl_filter(function(term) return azul.is_float(term) == state end, azul.get_terminals())
    t.assert(#terms == no, 'There should be ' .. no .. ' ' .. by_state(state) .. ' terminals. Instead, I found ' .. #terms)
end

vim.fn.timer_start((options.workflow == 'emacs' and 500) or 100, function()
    t.simulate_keys(t.action_shortcut('create_float'), {PaneChanged = 1}, function()
        assert_current_terminal(true)
        t.simulate_keys(t.action_shortcut('toggle_floats'), {PaneChanged = 1}, function()
            assert_current_terminal(false)
            assert_terminals_for_floating(1, true)
            assert_terminals_for_floating(1, false)
            t.simulate_keys(t.action_shortcut('create_float'), {PaneChanged = 1}, function()
                assert_current_terminal(true)
                assert_terminals_for_floating(2, true)
                assert_terminals_for_floating(1, false)
                local s = t.action_shortcut('enter_mode', nil, 'm') .. ' ' .. t.action_shortcut('move_end', 'm') .. ' ' .. t.action_shortcut('move_top', 'm')
                t.simulate_keys(s, {ModeChanged = 1, WinConfigChanged = 2}, function()
                    if options.workflow ~= 'emacs' then
                        t.assert(azul.current_mode() == 'm', 'The current mode should be m, not ' .. azul.current_mode())
                    end
                    local term = azul.get_current_terminal()
                    local f1 = term.buf
                    local cfg = vim.api.nvim_win_get_config(term.win_id)
                    t.assert(cfg.row == 0, 'The current terminal float should be on the first row, not ' .. cfg.row)
                    t.assert(vim.o.columns - cfg.col - 2 == cfg.width, 'The current terminal float should be on the first col, not ' .. cfg.col)
                    s = '<cr> ' .. t.action_shortcut('enter_mode', nil, 'p') .. ' ' .. t.action_shortcut('select_down', 'p')
                    t.simulate_keys(s, {PaneChanged = 1}, function()
                        term = azul.get_current_terminal()
                        t.assert(f1 ~= term.buf, 'The current selected buffer should not be ' .. term.buf)
                        local f2 = term.buf
                        s = '<cr> ' .. t.action_shortcut('toggle_floats')
                        t.simulate_keys(s, {PaneChanged = 1}, function()
                            term = azul.get_current_terminal()
                            assert_current_terminal(false)
                            t.simulate_keys(t.action_shortcut('toggle_floats'), {FloatsVisible = 1}, function()
                                assert_current_terminal(true)
                                term = azul.get_current_terminal()
                                t.assert(f2 == term.buf, 'The current floating terminal should be the last selected before hiding')
                                t.done()
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)
