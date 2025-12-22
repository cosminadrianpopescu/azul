local t = require('test-env')
local ERRORS = require('error_handling')
local vesper = require('vesper')
local EV = require('events')

local uuid = require('uuid').uuid;
local base_path = '/tmp/vesper-' .. uuid

ERRORS.panic_handler = function(stacktrace, msg)
    t.done()
end
