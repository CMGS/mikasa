module("store", package.seeall)

local config = require "config"

function get_channels(red, oid, uid)
    channels = red:lrange(string.format(config.IRC_USER_CHANNELS_FORMAT, oid, uid), 0, -1)
    return channels
end

function set_online(red, oid, cid, uid, uname)
    local res, err = red:hmset(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid, uname)
end

function set_offline(red, oid, cid, uid)
    local res, err = red:hdel(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid)
end

function subscribe(red, key)
    local res, err = red:subscribe(key)
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

function pubish_message(red, oid, cid, message, uname, uid)
    local msg_key = string.format(config.IRC_CHANNEL_MESSAGES, oid, cid)
    local pub_key = string.format(config.IRC_CHANNEL_PUBSUB, oid, cid)
    local timestamp = tostring(os.time())
    local msg = {timestamp, uid, uname, message}
    msg = table.concat(msg, ':')
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
    res, err = red:read_reply()
    if not res and not string.find(err, "timeout") then
        ngx.log(ngx.ERR, err)
        return
    end
    return res
end

