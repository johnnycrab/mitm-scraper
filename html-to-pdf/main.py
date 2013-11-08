import redis, subprocess

htmlPath = './html/'

r = redis.StrictRedis(host="localhost", port=6379, db=0)
ps = r.pubsub()
ps.psubscribe(["new:printable:*"])

for item in ps.listen():

	channel = item['channel'].replace('new:printable:', '')
	# split on hash to see if we have encoding
	l = channel.split('#')
	encoding = 'utf8'
	filename = l[0]
	if len(l) == 2:
		encoding = l[1]

	if filename != "*":

		data = item['data']
		# save to html file
		savePath = htmlPath + filename + '.html'

		try:
			with open(savePath, 'w') as html_file:
				html_file.write(data)
		except:
			pass

		encoding_opt = '--output-encoding=' + encoding
		args = ["phantomjs", encoding_opt, "phantom.js", filename]
		p = subprocess.Popen(args)