local uuid = require('uuid').uuid;
local base_path = '/tmp/azul-' .. uuid
local t = require('test-env')
local azul = require('azul')

local test_bug1 = function()
    local file = base_path .. '/splits.log'
    azul.start_logging(file)
    azul.send_to_current('for run in {1..' .. (vim.fn.winheight(0) * 2) .. '}; do echo $run; done<cr>', true)
    vim.fn.timer_start(200, function()
        local lines = require('split').split(require('files').read_file(file), "\n")
        t.assert(#vim.tbl_filter(function(l) return l == "1" end, lines) > 0, 'Could not find logged line')
        t.done()
    end)
end

local main_t = azul.get_current_terminal()
t.simulate_keys('<C-s>sljjj<cr>', {PaneChanged = 4, ModeChanged = 3}, function()
    local n = #azul.get_terminals()
    t.assert(n == 5, "There should be 5 terminals, not " .. vim.inspect(n))
    t.simulate_keys('<C-s>ph<cr>', {PaneChanged = 1, ModeChanged = 2}, function()
        local new_term = azul.get_current_terminal()
        t.assert(new_term == main_t, "The current selected terminal should be " .. main_t.buf .. ", not " .. new_term.buf)
        t.simulate_keys('<C-s>f', {PaneChanged = 1}, function()
            -- This should generate an error, since we cannot split while in floating mode
            t.simulate_keys('<C-s>sl', {ModeChanged = 1, Error = 1}, function()
                -- There is an error message that should be acknowledged
                t.simulate_keys('<cr>')
                n = #azul.get_terminals()
                t.assert(n == 6, "There should be 6 terminals, not " .. vim.inspect(n))
                test_bug1()
            end)
        end)
    end)
end)
