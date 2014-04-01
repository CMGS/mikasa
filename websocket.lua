module("websocket", package.seeall)

function send_message(ws, message)
    local bytes, err = ws:send_text(message)
    if not bytes or err then
        ngx.log(ngx.ERR, err)
    end
end
