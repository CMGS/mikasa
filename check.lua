module("check", package.seeall)

local session = require "session"

local function check_user_organizations(uid, oid)
    return true
end

function check_permission(uid, oid)
    if uid and uid ~= ngx.null and check_user_organizations(uid, oid) then
        return true
    end
    return false
end

