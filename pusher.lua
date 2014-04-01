local utils = require "utils"
local check = require "check"
local store = require "store"
local config = require "config"
local redtool = require "redtool"
local session = require "session"
local websocket = require "websocket"
local server = require "resty.websocket.server"

local sess = redtool.open(
    config.SESSION_HOST,
    config.SESSION_PORT,
    config.SESSION_PASSWORD,
    config.SESSION_TIMEOUT
)
local redis_store = redtool.open(
    config.REDIS_HOST,
    config.REDIS_PORT,
    config.REDIS_PASSWORD,
    config.REDIS_TIMEOUT
)

local oid = ngx.var.oid
local uid, uname = session.get_user(sess, ngx.var.cookie_TID)

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

local ws, err = server:new {
  timeout = 5000,
  max_payload_len = 65535
}

if not ws then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

local chan = {}
local keys = {}
local channels = store.get_channels(redis_store, oid, uid)

for cname, cid in pairs(channels) do
    local key = string.format(config.IRC_CHANNEL_PUBSUB, oid, cid)
    store.set_online(redis_store, oid, cid, uid, uname)
    websocket.send_message(ws, string.format("%s join %s", uname, cname))
    chan[cid] = key
    keys[key] = cname
end

store.subscribe(redis_store, utils.get_keys(keys))

local lock = true
local function clean_up()
    ngx.log(ngx.INFO, "reader clean up")
    if lock then
        local bytes, err = ws:send_close()
        if not bytes then
            ngx.log(ngx.ERR, err)
        end
    end
    store.unsubscribe(redis_store, utils.get_keys(keys))
    for cid, ckey in pairs(chan) do
        store.set_offline(redis_store, oid, cid, uid)
    end
    redtool.close(sess, config.SESSION_POOL_SIZE)
    redtool.close(redis_store, config.REDIS_POOL_SIZE)
    ngx.exit(444)
end

utils.reg_on_abort(function ()
    lock = false
end)

ngx.log(ngx.INFO, "start reader")
while ngx.shared.clients:get(ngx.var.cookie_TID) do
    local typ, key, data = store.read_message(redis_store)
    if data and typ == "message" then
        ngx.log(ngx.INFO, "channel key: ", key, " data: ", data)
        websocket.send_message(ws, string.format("%s>>>%s", keys[key], data))
    end
    if not lock then break end
end

clean_up()

