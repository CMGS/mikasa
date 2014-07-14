local utils = require "utils"
local check = require "check"
local store = require "store"
local clean = require "clean"
local writer = require "writer"
local pusher = require "pusher"
local config = require "config"
local redtool = require "redtool"
local session = require "session"
local websocket = require "websocket"
local server = require "resty.websocket.server"

local redis_store = redtool.open(
    config.REDIS_HOST,
    config.REDIS_PORT,
    config.REDIS_PASSWORD,
    config.REDIS_TIMEOUT
)

local pubsub = redtool.open(
    config.REDIS_HOST,
    config.REDIS_PORT,
    config.REDIS_PASSWORD,
    config.REDIS_TIMEOUT
)

local oid = ngx.var.oid
local uid, uname = session.get_user(redis_store, ngx.var.cookie_TID)

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

ngx.log(ngx.INFO, oid, uid, uname)

local chans = {}
local channels = store.get_channels(redis_store, oid, uid)

for cname, cid in pairs(channels) do
    local key = string.format(config.IRC_CHANNEL_PUBSUB_FORMAT, oid, cid)
    store.set_online(redis_store, oid, cid, uid, uname)
    chans[key] = {id = cid, name = cname}
end

local pub_keys = utils.get_keys(chans)

local channels = store.get_channels(redis_store, oid, uid)
local welcome_str = table.concat(utils.get_keys(channels), ", ")

local ws, err = server:new {
  timeout = 600000,
  max_payload_len = 65535
}

if not ws then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

ngx.log(ngx.INFO, "start mikasa")
websocket.send_message(ws, "welcome")
websocket.send_message(ws, "you are in: "..welcome_str)
ngx.shared.clients:set(ngx.var.cookie_TID, true, 660000)
local pusher = ngx.thread.spawn(pusher.push_msg, ws, redis_store, pubsub, oid, uname, uid, pub_keys, chans)
ngx.log(ngx.INFO, "pusher thread created: ", coroutine.status(pusher))
writer.write_msg(ws, redis_store, channels, oid, uname, uid)
ngx.shared.clients:delete(ngx.var.cookie_TID)
local ok, err = ngx.thread.wait(pusher)
if not ok then
    ngx.log(ngx.ERR, "failed to wait: ", err)
end
clean.clean_up(ws, redis_store, pubsub, oid, uname, uid, pub_keys, chans)

