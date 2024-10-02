local M = {}

M.set_wk = function(wf, modifier)
    local wk = require('which-key')
    if wf ~= 'azul' then
        wk.setup({
            triggers = {},
        })

        return
    end
    wk.setup({
        -- triggers = {'<c-s>'}
        triggers_no_wait = {
            modifier,
        },
        win = {
            height = { min = 8, max = 25 },
            no_overlap = false,
        }
    })

    -- wk.register({
    --     [modifier] = {
    --         ['<cr>'] = {'', 'Cancel'},
    --         i = {'', 'Cancel'},
    --     }
    -- }, {
    --         mode = "t",
    --     })
end

M.reload = function(buf, delimiter)
    require('which-key/triggers').add({buf = buf, keys = delimiter, mode = "t"})
end

return M
