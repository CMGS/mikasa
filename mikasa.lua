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

channels = store.get_channels(uid)

for cid, cname in ipairs(channels) do
    store.set_online(oid, cid, uid, uname)
    local key = string.format(config.IRC_CHANNEL_PUBSUB, oid, cid)
    store.sub_channel(key)
end

local ws, err = server:new {
  timeout = 6000000,
  max_payload_len = 65535
}

if not ws then
  ngx.log(ngx.ERR, "failed to new websocket: ", err)
  return ngx.exit(444)
end

ngx.thread.spawn(function ()
    local bytes, err
    while true do
        local msg = store.read_messages()
        if msg then
            bytes, err = ws:send_text(msg[3])
            if not bytes then
                ngx.log(ngx.ERR, "failed to send a text frame: ", err)
            end
        end
    end
end)

while true do
    local data, typ, err = ws:recv_frame()
    if not data then
        ngx.log(ngx.ERR, "failed to receive a frame: ", err)
        return ngx.exit(444)
    end

    if typ == "close" then
        local bytes, err = ws:send_close()
        if not bytes then
            ngx.log(ngx.ERR, "failed to send the close frame: ", err)
            return
        end
        ngx.log(ngx.INFO, "closing")
        return
    elseif typ == "ping" then
        local bytes, err = ws:send_pong(data)
        if not bytes then
            ngx.log(ngx.ERR, "failed to send frame: ", err)
            return
        end
    elseif typ == "pong" then
    elseif data then
        ngx.log(ngx.INFO, "received a frame of type ", typ, " and payload ", data)
    else break end
end

session.close()
store.close()
ngx.exit(ngx.OK)

