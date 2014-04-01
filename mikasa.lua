local utils = require "utils"
local check = require "check"
local config = require "config"
local session = require "session"
local server = require "resty.websocket.server"

session.init()

local oid = ngx.var.oid
local uid, uname = session.get_user(ngx.var.cookie_TID)
local clients = ngx.shared.clients

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

local ws, err = server:new {
  timeout = 600000,
  max_payload_len = 65535
}

if not ws then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

local function clean_up()
    ngx.log(ngx.INFO, "writer clean up")
    clients:delete(ngx.var.cookie_TID)
    session.close()
    local bytes, err = ws:send_close()
    if not bytes then
        ngx.log(ngx.ERR, err)
    end
    ngx.exit(444)
end

utils.reg_on_abort(clean_up)
ngx.log(ngx.INFO, "start writer")
clients:set(ngx.var.cookie_TID, true, 660000)

while true do
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
    elseif string.find(err, "timeout") then
        clients:set(ngx.var.cookie_TID, true, 660000)
    else break end
end

clean_up()

