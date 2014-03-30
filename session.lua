module("session", package.seeall)

local redis = require "redis"
local config = require "config"
-- safe?
local uid = nil

function get_uid(sid)
    if not sid then
        return nil
    end
    if not uid then
        local s = redis.open(config.SESSION_HOST, config.SESSION_PORT)
        uid = s:hmget("session:"..sid, "user_id")[1]
        redis.close(10000, config.SESSION_POOL_SIZE)
    end
    return uid
end

