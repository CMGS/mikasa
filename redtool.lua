module("redtool", package.seeall)

function set_timeout(red, time)
    red:set_timeout(time)
end

function open(red, host, port, password)
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

function close(red, time, pool_size)
    local ok, err = red:set_keepalive(time, pool_size)
    if not ok then
        ngx.log(ngx.ERR, err)
    end
end
