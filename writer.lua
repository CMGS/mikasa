module("writer", package.seeall)

local store = require "store"
local config = require "config"
local redtool = require "redtool"
local websocket = require "websocket"

function write_msg(ws, redis_store, channels, oid, uname, uid)
    ngx.log(ngx.INFO, "start writer")
    while true do
        local data, typ, err = ws:recv_frame()
        if typ == "close" or data == nil then
            break
        elseif data then
            local o_data = data
            data = string.split(data, ":", 2)
            local control, cname, d = data[1], data[2], data[3]

            if control == "_g_last" and channels[cname] and d then
                local messages = store.get_last_messages(redis_store, oid, channels[cname], tonumber(d))
                table.foreach(messages, function(seq, message)
                    websocket.send_message(ws, string.format("%s>>>%s", cname, message))
                end)
            elseif control == "_s_msg" and channels[cname] and d then
                store.pubish_message(redis_store, oid, channels[cname], d, uname, uid)
            elseif control == "_s_private" and d then
                store.broadcast_without_store(
                    redis_store, { string.format(config.IRC_PRIVATE_CHANNEL_FORMAT, cname) },
                    function(key) return d end
                )
            else
                ngx.log(ngx.ERR, "incorrect data: ", o_data)
            end
        elseif string.find(err, "timeout") then
            clients:set(ngx.var.cookie_TID, true, 660000)
        else break end
    end
    ngx.log(ngx.INFO, "stop writer")
end

