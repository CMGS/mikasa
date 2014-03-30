module("store", package.seeall)

local redis = require "redis"
local config = require "config"

local channels = nil

function get_channels(uid)
    if not channels then
        local s = redis.open(config.REDIS_HOST, config.REDIS_PORT)
        channels = s:lrange("irc:"..uid..":channels", 0, -1)
        redis.close(10000, config.REDIS_POOL_SIZE)
    end
    return channels
end

