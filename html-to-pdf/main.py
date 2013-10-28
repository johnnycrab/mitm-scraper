import redis, subprocess

htmlPath = './html/'

r = redis.StrictRedis(host="localhost", port=6379, db=0)
ps = r.pubsub()
ps.psubscribe(["new:printable:*"])

for item in ps.listen():

	filename = item['channel'].replace('new:printable:', '')
	if filename != "*":
		data = item['data']
		# save to html file
		savePath = htmlPath + filename + '.html'

		try:
			with open(savePath, 'w') as html_file:
				html_file.write(data)
		except:
			pass

		args = ["phantomjs", "phantom.js", filename]
		p = subprocess.Popen(args)