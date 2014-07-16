module("pusher", package.seeall)

local store = require "store"
local websocket = require "websocket"

function push_msg(ws, redis_store, pubsub, oid, uname, uid, pub_keys, chans, private_pubsub)
    ngx.log(ngx.INFO, "start pusher")

    store.subscribe(pubsub, pub_keys)
    store.broadcast_without_store(
        redis_store, pub_keys,
        function(key) return string.format("%s joined", uname) end
    )
    store.publish_online_users(redis_store, oid, chans)
    while ngx.shared.clients:get(ngx.var.cookie_TID) do
        local typ, key, data = store.read_message(pubsub)
        if data and typ == "message" then
            ngx.log(ngx.INFO, "type: ", typ, " channel key: ", key, " data: ", data)
            if key ~= private_pubsub then
                websocket.send_message(ws, string.format("%s>>>%s", chans[key].name, data))
            else
                websocket.send_message(ws, string.format("private>>>%s", data))
            end
        elseif typ and key and data then
            ngx.log(ngx.INFO, "type: ", typ, " channel key: ", key, " data: ", data)
        end
    end
    ngx.log(ngx.INFO, "stop pusher")
end

