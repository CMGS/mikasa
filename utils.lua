module("utils", package.seeall)

function string:split(sSeparator, nMax, bRegexp)
    assert(sSeparator ~= '')
    assert(nMax == nil or nMax >= 1)

    local aRecord = {}

    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField=1 nStart=1
        local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = self:sub(nStart)
    end

    return aRecord
end

string.starts = function(s1, s2)
   return string.sub(s1, 1, string.len(s2)) == s2
end

function reg_on_abort(func)
    local ok, err = ngx.on_abort(func)
    if not ok then
        ngx.log(ngx.ERR, "failed to register the on_abort callback: ", err)
        ngx.exit(500)
    end
end

function get_keys(t)
    local keyset={}
    local n=0
    table.foreach(t, function(k, v)
        n = n+1
        keyset[n] = k
    end)
    return keyset
end

function get_values(t)
    local valueset={}
    local n=0
    table.foreach(t, function(k, v)
        n = n+1
        valueset[n] = v
    end)
    return valueset
end
