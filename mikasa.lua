--local redis = require "resty.redis"
--local config = require "config"
local check = require "check"
local session = require "session"
local store = require "store"

local oid = ngx.var.oid
local uid = session.get_uid(ngx.var.cookie_TID)

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

channels = store.get_channels(uid)

ngx.say(channels[1], channels[2], channels[3])

--[[]
-- global variables
red = redis.new()
red:set_timeout(1000)

local ok, err = red:connect(config.REDIS_HOST, config.REDIS_PORT)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

local ok, err = red:set_keepalive(10000, 100)
if not ok then
    ngx.say("failed to set keepalive: ", err)
    return
end

ngx.say('hello world')
]]

