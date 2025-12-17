local split = require('split')
local FILES = require('files')

require('notify').setup(
{
    background_colour = "NotifyBackground",
    fps = 30,
    icons = {
      DEBUG = "",
      ERROR = "",
      INFO = "",
      TRACE = "✎",
      WARN = ""
    },
    level = 2,
    minimum_width = 50,
    render = "default",
    stages = "static",
    time_formats = {
      notification = "%T",
      notification_history = "%FT%T"
    },
    timeout = 5000,
    top_down = true
  })

local M = {}

M.panic_handler = function(stacktrace, msg)
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

return M
