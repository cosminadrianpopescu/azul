local t = require('test-env')
local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local get_channels = function()
    return vim.tbl_filter(function(c) return c.mode == 'terminal' end, vim.api.nvim_list_chans())
end

local find_channel_by_id = function(id)
    return funcs.find(function(c) return c.id == id end, get_channels())
end

local select_tab_shortcut = function(which)
    return t.action_shortcut('enter_mode', nil, 'T') .. ' ' .. t.action_shortcut('tab_select_' .. which, 'T', nil) .. ' ' .. '<cr>'
end

local assert_buf_state = function(connected)
    local term = azul.get_current_terminal()
    local state = azul.remote_state(term)
    t.assert((connected and state == 'connected') or state == 'disconnected', "The current terminal should be " .. ((connected and "connected") or "disconnected"))
end

-- This test case sends some bash commands. We need some time for bash to react. If this test fails and
-- it should not fail, try to increase this timer
local TIMER = 200

local close_remote_buffer = function(remaining_buffers, callback)
    azul.send_to_current('exit<cr>', true)
    vim.fn.timer_start(TIMER, function()
        assert_buf_state(false)
        t.assert(#azul.get_terminals() == remaining_buffers, "We should still have 3 terminals opened")
        t.assert(#get_channels() == remaining_buffers - 1, "We should still have 3 channels opened")
        t.simulate_keys('q', {PaneChanged = 1}, function()
            t.assert(#azul.get_terminals() == remaining_buffers - 1, "We should now have 2 terminals opened")
            t.assert(#get_channels() == remaining_buffers - 1, "We should now have 2 channels opened")
            callback()
        end)
    end)
end

local s = t.action_shortcut('create_tab')
t.simulate_keys(s, {PaneChanged = 1}, function()
    local LINES = vim.fn.winheight(0) * 2
    local term = azul.get_current_terminal()
    azul.send_to_current('for run in {1..' .. LINES .. '}; do echo $run; done<cr>', true)
    vim.fn.timer_start(TIMER, function()
        t.wait_events({RemoteDisconnected = 1}, function()
            local terms = azul.get_terminals()
            t.assert(#terms == 2, "We should have only 2 terminals")
            assert_buf_state(false)
            vim.fn.timer_start(1, function()
                t.assert(#get_channels() == 2, "We should have only 2 terminal channels opened")
                t.simulate_keys('r', {RemoteReconnected = 1}, function()
                    vim.fn.timer_start(TIMER, function()
                        t.assert(#get_channels() == 2, "After reconnecting, we should still have 2 channels opened")
                        term = azul.get_current_terminal()
                        local lines = vim.api.nvim_buf_get_lines(term.buf, 0, -1, false)
                        local found = false
                        for _, line in ipairs(lines) do
                            if line == '' .. LINES then
                                found = true
                            end
                        end
                        t.assert(found, "We should have in the current buffer a line containing " .. LINES)
                        s = t.action_shortcut('create_float')
                        t.simulate_keys(s, {PaneChanged = 1}, function()
                            term = azul.get_current_terminal()
                            s = t.action_shortcut('toggle_floats')
                            t.simulate_keys(s, {PaneChanged = 1}, function()
                                t.simulate_keys(select_tab_shortcut('first'), {PaneChanged = 1}, function()
                                    vim.fn.jobstop(term.term_id)
                                    vim.fn.timer_start(TIMER, function()
                                        t.assert(#get_channels() == 2, "We should have 2 opened channels")
                                        t.assert(#azul.get_terminals() == 3, "We should have 3 opened terminals")
                                        t.simulate_keys(select_tab_shortcut('last'), {PaneChanged = 1}, function()
                                            t.simulate_keys(t.action_shortcut('toggle_floats'), {PaneChanged = 1}, function()
                                                assert_buf_state(false)
                                                t.simulate_keys('r', {RemoteReconnected = 1}, function()
                                                    assert_buf_state(true)
                                                    close_remote_buffer(3, function()
                                                        close_remote_buffer(2, function()
                                                            t.done()
                                                        end)
                                                    end)
                                                end)
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
        vim.fn.jobstop(term.term_id)
    end)
end)

