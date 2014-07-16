module("clean", package.seeall)

local store = require "store"
local config = require "config"
local redtool = require "redtool"

function clean_up(ws, redis_store, pubsub, oid, uname, uid, pub_keys, chans, private_pubsub)
    ngx.log(ngx.INFO, "mikasa clean up")
    for key, chan in pairs(chans) do
        store.unsubscribe(pubsub, key)
        store.set_offline(redis_store, oid, chan.id, uid)
    end
    store.unsubscribe(pubsub, private_pubsub)
    store.broadcast_without_store(
        redis_store, pub_keys,
        function(key) return string.format("%s quit", uname) end
    )
    store.publish_online_users(redis_store, oid, chans)
    redtool.close(pubsub, config.REDIS_POOL_SIZE)
    redtool.close(redis_store, config.REDIS_POOL_SIZE)
    ws:send_close()
    ngx.exit(444)
end
