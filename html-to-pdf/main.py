import redis, subprocess

r = redis.StrictRedis(host="localhost", port=6379, db=0)
ps = r.pubsub()
ps.psubscribe(["new:printable:*"])

for item in ps.listen():

	filename = item['channel'].replace('new:printable:', '')
	if filename != "*":
		data = item['data']
		args = ["phantomjs", "phantom.js", filename, data]
		p = subprocess.Popen(args)