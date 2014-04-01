require "utils"
local check = require "check"
local config = require "config"
local session = require "session"
local server = require "resty.websocket.server"

session.init()

local oid = ngx.var.oid
local uid, uname = session.get_user(ngx.var.cookie_TID)

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

local ws, err = server:new {
  timeout = 6000000,
  max_payload_len = 65535
}
local clients = ngx.shared.clients
clients:set(ngx.var.cookie_TID, true, 6000000)

if not ws then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

while true do
    ngx.log(ngx.INFO, "writer connection")
    local data, typ, err = ws:recv_frame()
    if not data then
        ngx.log(ngx.ERR, err)
    end

    if typ == "close" then
        break
    elseif typ == "ping" then
        local bytes, err = ws:send_pong(data)
        if not bytes then
            ngx.log(ngx.ERR, err)
            break
        end
    elseif typ == "pong" then
    elseif data then
        ngx.log(ngx.INFO, "type: ", typ, "data: ", data)
    else break end
end

local bytes, err = ws:send_close()
ngx.log(ngx.INFO, "closing")
clients:delete(ngx.var.cookie_TID)
ngx.log(ngx.INFO, "delete client key")
if not bytes then
    ngx.log(ngx.ERR, err)
end

session.close()

