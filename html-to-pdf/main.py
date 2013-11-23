import redis, subprocess, ftplib, os

htmlPath = './html/'
pdfPath = './pdfs/'
ftpPath = 'Desktop/ftp-share/pdf-printer/'

r = redis.Redis(host="127.0.0.1", port=6379, db=0)
ps = r.pubsub()
ps.psubscribe(["new:printable:*"])

session = ftplib.FTP('192.168.178.29', 'monitoring', '123')

def uploadFileViaFTP(filename):
	print "uploadFileViaFTPs"
	fullPdfPath = pdfPath + filename
	file = open(fullPdfPath, 'rb')
	global session
	session.storbinary('STOR ' + ftpPath + filename, file)
	file.close()
	# remove pdf file here
	os.remove(fullPdfPath)

def resetSession():
	global session
	if session != None:
		try:
			session.quit()
		except:
			pass
	session = None
	session = ftplib.FTP('192.168.178.29', 'monitoring', '123')

try:
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
			if encoding != 'utf8':
				try:
					data = data.decode('utf8')
					data = data.encode(encoding)
				except:
					pass
			# save to html file
			savePath = htmlPath + filename + '.html'

			try:
				with open(savePath, 'w') as html_file:
					html_file.write(data)
			except:
				pass

			encoding_opt = '--output-encoding=' + encoding
			args = ["phantomjs", encoding_opt, "/usr/jj/mitm-scraper/html-to-pdf/phantom.js", filename]
			p = subprocess.call(args)
			print "exited with " + str(p)
			if p is 0:
				try:
					uploadFileViaFTP(filename + '.pdf')
				except:
					print "ftp transfer failed"
					resetSession()
					try:
						uploadFileViaFTP(filename + '.pdf')
					except:
						pass

					pass
except:
	print "Redis connection error..."
	pass
			
#def uploadFileViaFTP(filename, fullPath):


#filepath = '/root/Desktop/output.pdf'

#session = ftplib.FTP('johnnycrab.com','ftp10674345-admin','GltFYIlck25r')
#file = open(filepath,'rb')                  # file to send
#session.storbinary('STOR output.pdf', file)     # send the file
#file.close()                                    # close file and FTP
#session.quit()