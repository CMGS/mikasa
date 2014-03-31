require "utils"
local check = require "check"
local config = require "config"
local session = require "session"
local store = require "store"
local server = require "resty.websocket.server"

session.init()
store.init()

local oid = ngx.var.oid
local uid, uname = session.get_user(ngx.var.cookie_TID)

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

local channels = store.get_channels(uid)

for cid, cname in ipairs(channels) do
    store.set_online(oid, cid, uid, uname)
    local key = string.format(config.IRC_CHANNEL_PUBSUB, oid, cid)
    store.sub_channel(key)
    channels[cid] = key
end

local ws, err = server:new {
  timeout = 6000000,
  max_payload_len = 65535
}
local clients = ngx.shared.clients

if not ws then
  ngx.log(ngx.ERR, "failed to new websocket: ", err)
  return ngx.exit(444)
end

while clients:get(ngx.var.cookie_TID) or false do
    print("push thread")
    local msg = store.read_messages()
    if msg then
        bytes, err = ws:send_text(msg[3])
        if not bytes or err then
            ngx.log(ngx.ERR, err)
        end
    end
end

local bytes, err = ws:send_close()
ngx.log(ngx.INFO, "closing")
if not bytes then
    ngx.log(ngx.ERR, err)
end

for cid, key in ipairs(channels) do
    print(key)
    store.unsub_channel(key)
end

session.close()
store.close()

