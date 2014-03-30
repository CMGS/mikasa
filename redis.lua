module("redis", package.seeall)

local redis = require "resty.redis"

local s = redis:new()

function set_timeout(time)
    s:set_timeout(time)
end

function open(host, port, password)
    local ok, err = s:connect(host, port)
    if not ok then
        ngx.say("failed to connect: ", err)
        return ngx.exit(502)
    end
    if password then
        local ok, err = s.auth(password)
        if not ok then
            ngx.say("failed to connect: ", err)
            return ngx.exit(502)
        end
    end
    return s
end

function close(time, pool_size)
    local ok, err = s:set_keepalive(time, pool_size)
    if not ok then
        ngx.say("failed to set keepalive: ", err)
        return ngx.exit(502)
    end
end
