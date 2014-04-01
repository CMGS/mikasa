local utils = require "utils"
local check = require "check"
local store = require "store"
local config = require "config"
local session = require "session"
local websocket = require "websocket"
local server = require "resty.websocket.server"

session.init()
store.init()

local oid = ngx.var.oid
local uid, uname = session.get_user(ngx.var.cookie_TID)

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

local channels = store.get_channels(oid, uid)

for cid, cname in ipairs(channels) do
    local key = string.format(config.IRC_CHANNEL_PUBSUB, oid, cid)
    store.sub_channel(key)
    store.set_online(oid, cid, uid, uname)
    channels[cid] = key
end

local ws, err = server:new {
  timeout = 5000,
  max_payload_len = 65535
}

if not ws then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

local lock = true
local function clean_up()
    ngx.log(ngx.INFO, "reader clean up")
    if lock then
        local bytes, err = ws:send_close()
        if not bytes then
            ngx.log(ngx.ERR, err)
        end
    end
    for cid, ckey in ipairs(channels) do
        store.unsub_channel(ckey)
        store.set_offline(oid, cid, uid)
    end
    store.close()
    session.close()
    ngx.exit(444)
end

utils.reg_on_abort(function ()
    lock = false
end)

ngx.log(ngx.INFO, "start reader")
while ngx.shared.clients:get(ngx.var.cookie_TID) do
    local message = store.read_message()
    if message then
        ngx.log(ngx.INFO, message[3])
        websocket.send_message(ws, message[3])
    end
    if not lock then break end
end

clean_up()

