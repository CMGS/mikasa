module("session", package.seeall)

local redtool = require "redtool"
local redis = require "resty.redis"
local config = require "config"

local uid = nil
local uname = nil
local red = redis:new()
redtool.set_timeout(red, 1000)

function init()
    red = redtool.open(red, config.SESSION_HOST, config.SESSION_PORT)
end

function get_user(sid)
    if not sid then
        return nil
    end
    if not uid or not uname then
        local res, err = red:hmget(string.format(config.SESSION_FORMAT, sid), "user_id", "user_name")
        uid, uname = res[1], res[2]
    end
    return uid, uname
end

function close()
    redtool.close(red, 10000, config.SESSION_POOL_SIZE)
end

