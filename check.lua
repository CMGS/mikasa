module("check", package.seeall)

local store = require "store"
local session = require "session"

function check_permission(red, uid, oid)
    if uid and uid ~= ngx.null and store.get_organization_user(red, uid, oid) then
        return true
    end
    return false
end

