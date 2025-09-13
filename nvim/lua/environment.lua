local _env = {}
local FILES = require('files')

local set_environment = function(env)
    local p = '\\v\\$([a-zA-Z0-9_]+)'
    for key, value in pairs(env) do
        while vim.fn.match(value, p) ~= -1 do
            local list = vim.fn.matchlist(value, p)
            value = vim.fn.substitute(value, list[1], os.getenv(list[2]), 'g')
        end
        value = vim.fn.substitute(value, '\\v\\~', os.getenv('HOME'), 'g')
        _env[key] = value
    end
end

local get_environment = function()
    return vim.tbl_deep_extend('force', {}, _env)
end

local load_from_lua = function()
    local from_lua_env = FILES.load_as_module('env')
    if from_lua_env ~= nil then
        set_environment(from_lua_env)
    end
end

return {
    get_environment = get_environment,
    set_environment = set_environment,
    load_from_lua = load_from_lua,
}
