module("config", package.seeall)

REDIS_HOST = "127.0.0.1"
REDIS_PORT = 6379
REDIS_PASSWORD = nil
REDIS_POOL_SIZE = 100
REDIS_TIMEOUT = 1000

SESSION_KEY = "tid"
SESSION_FORMAT = "session:%s"

IRC_PRIVATE_CHANNEL_FORMAT = "irc:user_%s:pubsub"
IRC_ORGANIZATION_USERS_FORMAT = "irc:%s:users"
IRC_USER_CHANNELS_FORMAT = "irc:%s:user_%s:channels"
IRC_CHANNEL_ONLINE_FORMAT = "irc:%s:%s:online"
IRC_CHANNEL_PUBSUB_FORMAT = "irc:%s:%s:pubsub"
IRC_CHANNEL_MESSAGES_FORMAT = "irc:%s:%s:messages"

CONNECTION_TIMEOUT = 600000
