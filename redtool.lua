module("redtool", package.seeall)

local redis = require "resty.redis"
local config = require "config"

function open(host, port, password, timeout)
    local red = redis:new()
    red:set_timeout(timeout)
    local ok, err = red:connect(host, port)
    if not ok then
        ngx.say("failed to connect: ", err)
        return ngx.exit(502)
    end
    if password then
        local ok, err = red.auth(password)
        if not ok then
            ngx.say("failed to connect: ", err)
            return ngx.exit(502)
        end
    end
    return red
end

function close(red, pool_size)
    local ok, err = red:set_keepalive(
        config.CONNECTION_TIMEOUT,
        pool_size or config.REDIS_POOL_SIZE)
    if not ok then
        ngx.log(ngx.ERR, err)
    end
end

