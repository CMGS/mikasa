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

local pubsub = redtool.open(
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

local chans = {}
local channels = store.get_channels(redis_store, oid, uid)

for cname, cid in pairs(channels) do
    local key = string.format(config.IRC_CHANNEL_PUBSUB_FORMAT, oid, cid)
    store.set_online(redis_store, oid, cid, uid, uname)
    chans[key] = {id = cid, name = cname}
end

local pub_keys = utils.get_keys(chans)
store.subscribe(pubsub, pub_keys)
store.broadcast_without_store(
    redis_store, pub_keys,
    function(key) return string.format("%s joined", uname) end
)
store.publish_online_users(redis_store, oid, chans)

local lock = true
local function clean_up()
    ngx.log(ngx.INFO, "reader clean up")
    if lock then
        local bytes, err = ws:send_close()
        if not bytes then
            ngx.log(ngx.ERR, err)
        end
    end
    for key, chan in pairs(chans) do
        store.unsubscribe(pubsub, key)
        store.set_offline(redis_store, oid, chan.id, uid)
    end

    store.broadcast_without_store(
        redis_store, pub_keys,
        function(key) return string.format("%s quit", uname) end
    )
    store.publish_online_users(redis_store, oid, chans)

    redtool.close(sess, config.SESSION_POOL_SIZE)
    redtool.close(pubsub, config.REDIS_POOL_SIZE)
    redtool.close(redis_store, config.REDIS_POOL_SIZE)
    ngx.exit(444)
end

utils.reg_on_abort(function ()
    lock = false
end)

ngx.log(ngx.INFO, "start reader")
while ngx.shared.clients:get(ngx.var.cookie_TID) do
    local typ, key, data = store.read_message(pubsub)
    if data and typ == "message" then
        ngx.log(ngx.INFO, "type: ", typ, " channel key: ", key, " data: ", data)
        websocket.send_message(ws, string.format("%s>>>%s", chans[key].name, data))
    elseif typ and key and data then
        ngx.log(ngx.INFO, "type: ", typ, " channel key: ", key, " data: ", data)
    end
    if not lock then break end
end

clean_up()

