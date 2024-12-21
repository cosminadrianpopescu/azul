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
            local term = azul.get_current_terminal()
            -- print("ASSERTING " .. vim.inspect(term.win_config.row))
            t.assert(term.win_config.row == 0, 'The current terminal float should be on the first row, not ' .. term.win_config.row)
            t.done()
        end)
    end)
end)
