subterfuge_image_loc = 'http://192.168.178.113:4000/static/images/'
subterfuge_css_loc = 'http://192.168.178.113:4000/static/css/'

express = require 'express'
#fs = require 'fs'
redis = require 'redis'
cheerio = require 'cheerio'
Handlebars = require 'handlebars'
Blacklist = require './blacklist'
fs = require 'fs'
http = require 'http'

app = express()
server = require('http').createServer app
io = require('socket.io').listen server

# ! Redis config

redisClient = redis.createClient(6379, "127.0.0.1")
redisClient2 = redis.createClient(6379, "127.0.0.1")
redisClient.on 'error', (err) ->
	console.log "REDIS ERROR: " + err

server.listen 3000

# express config

app.configure ->
  app.use express.static(__dirname + '/public')

# Handlebars and template setup
Templates = {}
hbTemplates = 
	'cover': 'cover.html'
	'credentials': 'credentials.html'

precompileTemplates = ->
	for name, path of hbTemplates
		do (name) ->
			fs.readFile __dirname + '/views/' + path, 'utf8', (err, data) ->
				if err then throw err
				Templates[name] = Handlebars.compile data

precompileTemplates()

# Sequence number for templates
sequenceNumber = fs.readFileSync(__dirname + '/seqnum', {encoding: 'utf-8'})
sequenceNumber = if sequenceNumber then parseInt(sequenceNumber) else 0

incSequenceNumber = ->
	sequenceNumber++
	fs.writeFile __dirname + '/seqnum', sequenceNumber
	sequenceNumber

# ! Socket shit

io.sockets.on 'connection', (socket) ->
	
	socket.on 'ping', ->
		socket.emit 'ready'

	socket.on 'scrape', (data) ->
		data = JSON.parse data
		pageTransformer = new PageTransformer data.page, data.host, data.fullUrl, data.encoding
		pageTransformer.run()


# Redis credential subscription
redisClient.subscribe 'new:credentials'
redisClient.on 'message', (channel, message) ->
	if channel is 'new:credentials'
		credentialsObj = JSON.parse message
		console.log 'Got credentials %o', credentialsObj
		if credentialsObj
			credentialsObj.sequenceNumber = incSequenceNumber()
			redisClient2.publish 'new:printable:credentials_' + credentialsObj.date, Templates.credentials(credentialsObj)



# ! Helpers

class PageTransformer
	constructor: (data, @host, @fullUrl, @encoding) ->
		@html = '<!DOCTYPE html><html>' + data + '</html>'
		@$ = cheerio.load @html
		@timestamp = new Date().getTime()

	run: ->
		unless Blacklist.do @
			@getConnectionInfos()
			@removeScripts()
			@changeImageSources()
			@changeCSSSources()
			@save()

	removeScripts: ->
		@$('script').remove()

	substituteSlashes: (selector, attrName, new_path) ->
		$ = @$
		that = @
		$(selector).each ->
			attr = $(@).attr attrName
			newHost = ''
			if attr
				if attr.indexOf('http://') isnt 0
					# no http, add host
					newHost = that.host + (if attr.indexOf('/') is 0 then '' else '/') + attr
				else
					newHost = attr.replace 'http://', ''
				# replace all slashes with underscores
				re = new RegExp '/', 'g'
				newHost = new_path + newHost.replace(re, '_')

				$(@).attr attrName, newHost


	changeImageSources: ->
		@substituteSlashes 'img', 'src', subterfuge_image_loc

	changeCSSSources: ->
		@substituteSlashes 'link[rel=stylesheet]', 'href', subterfuge_css_loc

	getFaviconSrc: (cb) ->
		possibleExtensions = ['ico', 'png', 'gif', 'jpg', 'jpeg']
		i = -1
		opts = 
			hostname: @host
			port: 80
			path: '/favicon.'
			method: 'HEAD'
		checkAndContinue = =>
			i++
			if i <= possibleExtensions.length
				opts.path += possibleExtensions[i]
				req = http.request opts, (res) =>
					if res.statusCode < 400 and res.statusCode >= 200
						cb opts.hostname + opts.path
					else
						checkAndContinue()
				req.end()
			else
				cb null
		checkAndContinue()

			
	getConnectionInfos: ->
		$ = @$
		jsonTag = $('#mitm-scraper-conn-info')
		if jsonTag.length
			connInfo = JSON.parse jsonTag.html()
			if connInfo
				connInfo.sequenceNumber = incSequenceNumber()
				# get the favicon and callback when necessary
				@getFaviconSrc (src) ->
					connInfo.faviconSrc = src
					@coverHtml = Templates.cover connInfo
					redisClient2.publish 'new:printable:' + @timestamp + '_cover', @coverHtml, redis.print
			

	save: ->
		#console.log @$.html()
		publishName = 'new:printable:' + @timestamp + (if @encoding then '#' + @encoding else '')
		redisClient2.publish publishName, @$.html(), redis.print

