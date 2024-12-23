local t = require('test-env')
local azul = require('azul')

local floats = 0
local events = {'FloatOpened', 'FloatsVisible', 'FloatClosed'}

azul.on(events, function()
    floats = floats + 1
end)

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

function wait_floats_ev(callback, n)
    if (n == nil) then
        n = floats
    end

    if n < floats then
        if callback ~= nil then
            callback()
        end
        return
    end

    vim.fn.timer_start(50, function()
        wait_floats_ev(callback, n)
    end)
end

t.simulate_keys('<C-s>f')
wait_floats_ev(function()
    assert_current_terminal(true)
    t.simulate_keys('<C-s>w')
    wait_floats_ev(function()
        assert_current_terminal(false)
        assert_terminals_for_floating(1, true)
        assert_terminals_for_floating(1, false)
        t.simulate_keys('<C-s>f')
        wait_floats_ev(function()
            assert_current_terminal(true)
            assert_terminals_for_floating(2, true)
            assert_terminals_for_floating(1, false)
            t.simulate_keys('<C-s>mLK')
            vim.fn.timer_start(1, function()
                t.assert(azul.current_mode() == 'm', 'The current mode should be m, not ' .. azul.current_mode())
                local term = azul.get_current_terminal()
                local f1 = term.buf
                local cfg = vim.api.nvim_win_get_config(term.win_id)
                t.assert(cfg.row == 0, 'The current terminal float should be on the first row, not ' .. cfg.row)
                t.assert(vim.o.columns - cfg.col - 2 == cfg.width, 'The current terminal float should be on the first col, not ' .. cfg.col)
                t.single_shot('PaneChanged', function(args)
                    term = azul.get_current_terminal()
                    t.assert(f1 ~= term.buf, 'The current selected buffer should not be ' .. term.buf)
                    local f2 = term.buf
                    t.simulate_keys('<cr><C-s>w')
                    wait_floats_ev(function()
                        term = azul.get_current_terminal()
                        assert_current_terminal(false)
                        t.simulate_keys('<C-s>w')
                        wait_floats_ev(function()
                            assert_current_terminal(true)
                            term = azul.get_current_terminal()
                            t.assert(f2 == term.buf, 'The current floating terminal should be the last selected before hiding')
                            t.done()
                        end)
                    end)
                end)
                t.simulate_keys('<cr><C-s>pj')
            end)
        end)
    end)
end)
