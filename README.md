Mikasa
=========

控制Api
---------

每个请求附带用户的Cookie

/org_name/channel/create
/org_name/channel/join
/org_name/channel/quit
/org_name/channel/delete
/org_name/channel/config

每一种操作均需要验证用户权限, 每一个组织默认自带public频道
类似于 #public@douban

Websocket
---------

附带用户Cookie

1. connect /org_name, 验证用户是否合法（必须登录，属于这个组织）
2. 从Cookie拿到sid对应用户加入的channels
3. 并发redis，list key org_name:channel_id:online 中增加user_id
4. redis，pubsub key org_name:channel_id:pubsub 建立监听通道
5. redis, sortedset key org_name:channel_id:messages 频道消息队列
6. redis, key org_name:channel_id:user_id:last 最后一条消息时间戳
7. if org_name:channel:user_id:last:
        将org_name:channel:message在这个时间戳之后的消息直接返回，反馈更新org_name:channel:user_id:last
   else:
        返回org_name:channel:message内容，由客户端反馈更新org_name:channel:user_id:last
8. 消息结构： channel:timestamp:message_body, 服务端处理加入user_id
9. 写
    消息写入 org_name:channel:message
    遍历 org_name:channel:online , 并发写入各自的 org_name:user_id 接口
    客户端接收到消息之后返回时间戳到服务端，更新 org_name:channel:user_id:last
10. 读
    监听 subscribe org_name:user_id 接口，拿到数据 response timestamp 更新 org_name:channel:user_id:last
11. failover
    reset connections

持久化
------

1. 主要持久化的目标是 org_name:channel:message
2. 文本增量持久，rika？
3. demo 阶段不需要考虑

