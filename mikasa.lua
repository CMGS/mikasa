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
local clients = ngx.shared.clients

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

local channels = store.get_channels(oid, uid)
local welcome_str = table.concat(channels, ", ")


local chan = {}
table.foreach(channels, function(cid, cname) chan[cname]=cid end)

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
    store.close()
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

websocket.send_message(ws, "welcome")
websocket.send_message(ws, "you are in: "..welcome_str)
while true do
    local data, typ, err = ws:recv_frame()
    if not data then
        ngx.log(ngx.ERR, err)
    end

    if typ == "close" then
        break
    elseif data then
        data = string.split(data, ":")
        local control, cname, d = data[1], data[2], data[3]

        if control == "_g_last" and chan[cname] and d then
            local timestamp = tonumber(d)
            local messages = store.get_last_messages(oid, chan[cname], timestamp)
            table.foreach(messages, function(seq, message) ngx.log(ngx.INFO, message) end)
        elseif control == "_s_msg" and chan[cname] and d then
            store.pubish_message(oid, chan[cname], d, uname, uid)
        else
            ngx.log(ngx.ERR, "incorrect data: ", data)
        end
    elseif string.find(err, "timeout") then
        clients:set(ngx.var.cookie_TID, true, 660000)
    else break end
end

clean_up()

