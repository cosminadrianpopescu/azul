local M = {}
local split = require('split')

M.init = function()
    M.config_dir = vim.env.AZUL_CONFIG_HOME or ((vim.env.XDG_CONFIG_HOME or (os.getenv('HOME') .. '/.config')) .. '/azul')
    vim.o.runtimepath = vim.o.runtimepath .. ',' .. M.config_dir .. '/pack/start/*,' .. M.config_dir .. '/pack/opt/*,' .. M.config_dir
end

M.exists = function(which)
    local file = io.open(which)
    if file ~= nil then
        io.close(file)
        return true
    end
    return false
end

M.try_load_config = function(which)
    if M.exists(which) == false then
        return false
    end
    vim.api.nvim_command('source ' .. which)
    return true
end

M.read_file = function(which)
    if not M.exists(which) then
        return nil
    end

    local file = io.open(which)
    local result = file:read('*all')
    io.close(file)
    return result
end

M.write_file = function(which, content)
    local f = io.open(which, "w")
    if f == nil then
        return
    end
    f:write(content)
    f:close()
end

M.read_ini = function(which)
    local txt = M.read_file(which)
    local result = {}
    if txt == nil then
        return result
    end

    local lines = vim.tbl_map(function (s)
        return vim.fn.substitute(s, '\\v^[ \\t]*([^\\=\\t ]+)[ \\t]*\\=[ \\t]*(.*)$', '\\1=\\2', 'g')
    end, split.split(txt, "\n"))
    local current_section = nil
    for idx, line in ipairs(lines) do
        if vim.fn.match(line, '\\v^[ ]*#') ~= -1 or vim.fn.match(line, '\\v^[ \\s\\t]*$') ~= -1 then
            goto continue
        end
        local p = '\\v^\\[([^\\]]+)\\]$'
        if vim.fn.match(line, p) ~= -1 then
            current_section = string.lower(vim.fn.substitute(line, p, '\\1', 'g'))
            goto continue
        end
        local parts = split.split(line, "=")
        if current_section == nil then
            error('There is an error loading the config file ' .. which .. '. The setting at line ' .. idx .. ' is outside any section')
        end
        if #parts ~= 2 then
            error("There is an error loading the config file " .. which .. " at line " .. idx)
        end
        if result[current_section] == nil then
            result[current_section] = {}
        end
        local base = result[current_section]
        local tokens = split.split(parts[1], '%.')
        for idx, token in ipairs(tokens) do
            if idx == #tokens then
                if base[token] == nil then
                    base[token] = parts[2]
                else
                    base[token] = base[token] .. '$$$' .. parts[2]
                end
                break
            end
            if base[token] == nil then
                base[token] = {}
            end
            base = base[token]
        end
        ::continue::
    end

    -- for k, _ in pairs(result) do
    --     print(vim.inspect(k))
    -- end
    return result
end

return M
