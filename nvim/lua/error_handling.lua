local split = require('split')
local FILES = require('files')
local EV = require('events')

local M = {}

local is_panicking = false

local build_message = function(stacktrace, msg)
    return (msg or '') .. '\n\n' .. stacktrace
end

M.try_execute = function(try_callback, catch_callback, error_message)
    local safe, result = xpcall(try_callback, debug.traceback)
    if safe then
        return result
    end
    local msg = build_message(result, error_message)
    EV.trigger_event('Error', msg)
    if catch_callback ~= nil then
        catch_callback(result, error_message)
    end
end

M.panic_handler = function(stacktrace, msg)
    is_panicking = true
    local lines = split.split(stacktrace, '\n')
    if msg == nil then
        if string.match(lines[1], 'config.lua') ~= nil then
            msg = 'There is an error in your config.ini. Try starting vesper with --clean option and then check out your config.ini'
        end
    end
    pcall(function()
        FILES.write_file(os.getenv('VESPER_FAILED_FILE'), (msg or '') .. '\n\n' .. stacktrace)
    end)
    vim.api.nvim_command('quitall!')
end

M.is_panicking = function()
    return is_panicking
end

M.error_handler = function(stacktrace, msg)
end

return M
