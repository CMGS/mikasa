module("store", package.seeall)

local config = require "config"

function get_channels(red, oid, uid)
    local channels, err = red:hgetall(string.format(config.IRC_USER_CHANNELS_FORMAT, oid, uid))
    if not channels then
        ngx.log(ngx.ERR, err)
        return ngx.exit(502)
    end
    local chan = {}
    local tmp = nil
    table.foreach(channels, function(k, v)
        if k % 2 ~= 0 then
            tmp = v
        else
            chan[tmp] = v
        end
    end)
    return chan
end

function get_online(red, oid, cid)
    local online_users, err = red:hgetall(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid, uname)
    if not online_users then
        ngx.log(ngx.ERR, err)
        return
    end
    local users = {}
end

function set_online(red, oid, cid, uid, uname)
    local res, err = red:hmset(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid, uname)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function set_offline(red, oid, cid, uid)
    local res, err = red:hdel(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function subscribe(red, keys)
    local res, err = red:subscribe(unpack(keys))
    if not res then
        ngx.say("failed to subscribe: ", err)
        return ngx.exit(502)
    end
end

function unsubscribe(red, key)
    local res, err = red:unsubscribe(key)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function publish_joined(red, keys, uname)
    for k, v in pairs(keys) do
        local res, err = red:publish(v, string.format("%s joined", uname))
        if not res then
            ngx.log(ngx.ERR, res)
        end
    end
end

function pubish_message(red, oid, cid, message, uname, uid)
    local msg_key = string.format(config.IRC_CHANNEL_MESSAGES, oid, cid)
    local pub_key = string.format(config.IRC_CHANNEL_PUBSUB, oid, cid)
    local timestamp = tostring(os.time())
    local msg = table.concat({timestamp, uid, uname, message}, ':')
    red:init_pipeline()
    red:zadd(msg_key, timestamp, msg)
    red:publish(pub_key, msg)
    local results, err = red:commit_pipeline()
    if not results then
        ngx.log(ngx.ERR, "failed to commit the pipelined requests: ", err)
        return
    end
end

function get_last_messages(red, oid, cid, timestamp)
    local key = string.format(config.IRC_CHANNEL_MESSAGES, oid, cid)
    local messages = red:zrangebyscore(key, tostring(timestamp), tostring(os.time()))
    -- limit messges
    return messages
end

function read_message(red)
    local res, err = red:read_reply()
    if not res and not string.find(err, "timeout") then
        ngx.log(ngx.ERR, err)
        return
    elseif res then
        return res[1], res[2], res[3]
    end
end

