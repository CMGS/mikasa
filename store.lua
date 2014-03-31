module("store", package.seeall)

local redtool = require "redtool"
local redis = require "resty.redis"
local config = require "config"

local channels = nil
local red = redis:new()
local sub = redis:new()
redtool.set_timeout(red, 1000)
redtool.set_timeout(sub, 6000000)

function init()
    red = redtool.open(red, config.REDIS_HOST, config.REDIS_PORT)
    sub = redtool.open(sub, config.REDIS_HOST, config.REDIS_PORT)
end

function get_channels(uid)
    if not channels then
        channels = red:lrange(string.format(config.IRC_USER_CHANNELS_FORMAT, uid), 0, -1)
    end
    return channels
end

function set_online(oid, cid, uid, uname)
    local res, err = red:hmset(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid, uname)
end

function sub_channel(channel)
    local res, err = sub:subscribe(channel)
    if not res then
        ngx.say("failed to subscribe: ", err)
        return ngx.exit(502)
    end
end

function unsub_channel(channel)
    local res, err = sub:unsubscribe(channel)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function read_messages()
    res, err = sub:read_reply()
    if not res then
        ngx.log(ngx.ERR, err)
        return
    end
    return res
end

function close()
    redtool.close(red, 1000, config.REDIS_POOL_SIZE)
    redtool.close(sub, 5000, config.REDIS_POOL_SIZE)
end

