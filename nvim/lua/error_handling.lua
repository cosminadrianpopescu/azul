local split = require('split')
local FILES = require('files')
local funcs = require('functions')

local M = {}

local is_panicking = false
local is_handling_error = false
local unexpected_error_interceptors = {}
local error_handlers = {}

local build_message = function(stacktrace, msg)
    return (msg or '') .. '\n' .. stacktrace
end

local handle_unexpected_errors = function(err)
    for _, h in pairs(unexpected_error_interceptors) do
        h(err)
    end
end

M.try_execute = function(try_callback, catch_callback, error_message)
    local safe, result = xpcall(try_callback, debug.traceback)
    if safe then
        return result
    end
    local msg = "*Caught unexpected error"
    if is_handling_error then
        msg = msg .. " in your error handler"
    end
    msg = msg .. "*:\n" .. build_message(result, error_message)
    funcs.log(msg)
    funcs.log("\n")
    if is_handling_error then
        return
    end
    is_handling_error = true
    if catch_callback ~= nil then
        catch_callback(result, error_message)
    else
        handle_unexpected_errors(msg)
        M.warning("There has been an unexpected error. Check your logs for more details.")
    end
    is_handling_error = false
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

M.defer = function(timeout, callback)
    return vim.fn.timer_start(timeout, function()
        M.try_execute(callback)
    end)
end

M.throw = function(msg, stack)
    local _m = msg
    if stack ~= nil then
        _m = _m .. " at " .. vim.inspect(stack)
    end
    for _, h in pairs(error_handlers) do
        M.try_execute(function()
            h(_m)
        end, function()
            funcs.log("You have an error in your error handler")
        end)
    end
    error(_m)
end

M.on_error = function(callback)
    table.insert(error_handlers, callback)
end

M.on_unhandled_error = function(callback)
    table.insert(unexpected_error_interceptors, callback)
end

M.warning = function(msg)
    vim.notify("\n" .. (msg or '') .. "\n", 'info')
end

return M
