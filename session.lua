module("session", package.seeall)

local config = require "config"

function get_user(red, sid)
    if not sid then
        return nil, nil
    end
    local res, err = red:hmget(string.format(config.SESSION_FORMAT, sid), "user_id", "user_name")
    local uid, uname = res[1], res[2]
    return uid, uname
end

