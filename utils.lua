module("utils", package.seeall)

string.split = function(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
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
