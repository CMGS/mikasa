module("session", package.seeall)

local redtool = require "redtool"
local redis = require "resty.redis"
local config = require "config"

local uid = nil
local uname = nil

function init()
    local red = redis:new()
    redtool.set_timeout(red, 1000)
    redtool.open(red, config.SESSION_HOST, config.SESSION_PORT)
    return red
end

function get_user(red, sid)
    if not sid then
        return nil
    end
    local res, err = red:hmget(string.format(config.SESSION_FORMAT, sid), "user_id", "user_name")
    local uid, uname = res[1], res[2]
    return uid, uname
end

function close(red)
    redtool.close(red, 10000, config.SESSION_POOL_SIZE)
end

