import redis

class RedisClient:

	instance = None

	@staticmethod
	def getInstance():
		if RedisClient.instance is None:
			print "Setting up Redis instance"
			RedisClient.instance = redis.Redis(host="127.0.0.1", port=6379, db=0)
		return RedisClient.instance