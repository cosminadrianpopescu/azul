local uuid = require('uuid').uuid;
local base_path = '/tmp/vesper-' .. uuid
local t = require('test-env')
local vesper = require('vesper')
local funcs = require('functions')
local options = require('options')
local ERRORS = require('error_handling')
local EV = require('events')

local test_bug1 = function()
    local file = base_path .. '/splits.log'
    vesper.start_logging(file)
    vesper.send_to_current('for run in {1..' .. (vim.fn.winheight(0) * 2) .. '}; do echo $run; done<cr>', true)
    ERRORS.defer(200, function()
        local lines = require('split').split(require('files').read_file(file), "\n")
        assert(#vim.tbl_filter(function(l) return l == "1" end, lines) > 0, 'Could not find logged line')
        t.done()
    end)
end

local main_t

EV.persistent_on('TerminalAdded', function()
    if main_t ~= nil then
        return
    end
    main_t = vesper.get_current_terminal()
end)

local x = t.action_shortcut('split_down', 's') .. ' '
local s = t.action_shortcut('enter_mode', nil, 's') .. ' ' .. t.action_shortcut('split_right', 's') .. ' ' .. x .. x .. x .. '<cr>'
t.wait_events({TabTitleChanged = 1}, function()
    t.simulate_keys(s, {PaneChanged = 4}, function()
        local n = #vesper.get_terminals()
        assert(n == 5, "There should be 5 terminals, not " .. vim.inspect(n))
        s  = t.action_shortcut('enter_mode', nil, 'p') .. ' ' .. t.action_shortcut('select_left', 'p') .. ' <cr>'
        t.simulate_keys(s, {PaneChanged = 1, ModeChanged = 2}, function()
            local new_term = vesper.get_current_terminal()
            assert(new_term == main_t, "The current selected terminal should be " .. main_t.buf .. ", not " .. new_term.buf)
            s = t.action_shortcut('create_float')
            t.simulate_keys(s, {PaneChanged = 1}, function()
                t.on_warning(function(msg)
                    n = #vesper.get_terminals()
                    assert(n == 6, "There should be 6 terminals, not " .. vim.inspect(n))
                    test_bug1()
                end)
                -- This should generate an error, since we cannot split while in floating mode
                s = t.action_shortcut('enter_mode', nil, 's') .. ' ' .. t.action_shortcut('split_right', 's')
                t.simulate_keys(s)
            end)
        end)
    end)
end)
