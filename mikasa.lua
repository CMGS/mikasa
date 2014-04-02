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
local clients = ngx.shared.clients

if not check.check_permission(uid, oid) then
    ngx.say("permission deny")
    return
end

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

local function clean_up()
    ngx.log(ngx.INFO, "writer clean up")
    clients:delete(ngx.var.cookie_TID)
    redtool.close(sess, config.SESSION_POOL_SIZE)
    redtool.close(redis_store, config.REDIS_POOL_SIZE)
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
        local o_data = data
        data = string.split(data, ":", 2)
        local control, cname, d = data[1], data[2], data[3]

        if control == "_g_last" and channels[cname] and d then
            local timestamp = tonumber(d)
            local messages = store.get_last_messages(redis_store, oid, channels[cname], timestamp)
            table.foreach(messages, function(seq, message)
                websocket.send_message(ws, string.format("%s>>>%s", cname, message))
            end)
        elseif control == "_s_msg" and channels[cname] and d then
            store.pubish_message(redis_store, oid, channels[cname], d, uname, uid)
        else
            ngx.log(ngx.ERR, "incorrect data: ", o_data)
        end
    elseif string.find(err, "timeout") then
        clients:set(ngx.var.cookie_TID, true, 660000)
    else break end
end

clean_up()

