subterfuge_image_loc = 'http://192.168.178.151:5000/static/imagescraper/'

express = require 'express'
#fs = require 'fs'
redis = require 'redis'
cheerio = require 'cheerio'
Handlebars = require 'handlebars'
fs = require 'fs'

app = express()
server = require('http').createServer app
io = require('socket.io').listen server

# ! Redis config

redisClient = redis.createClient(6379, "127.0.0.1")
redisClient.on 'error', (err) ->
	console.log "REDIS ERROR: " + err

server.listen 3000

# express config

app.configure ->
  app.use express.static(__dirname + '/public')


Templates = {}
# Handlebars and template setup
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


# ! Socket shit

io.sockets.on 'connection', (socket) ->
	
	socket.on 'ping', ->
		socket.emit 'ready'

	socket.on 'scrape', (data) ->
		data = JSON.parse data
		pageTransformer = new PageTransformer data.page, data.host
		pageTransformer.run()





# ! Helpers

class PageTransformer
	constructor: (data, @host) ->
		@html = '<!DOCTYPE html><html>' + data + '</html>'
		@$ = cheerio.load @html
		@timestamp = new Date().getTime()

	run: ->
		@getConnectionInfos()
		@removeScripts()
		@changeImageSources()
		#@addConnectionInfoHtml()
		@save()

	removeScripts: ->
		@$('script').remove()

	changeImageSources: ->
		$ = @$
		that = @
		$('img').each ->
			src = $(@).attr 'src'
			newHost = ''
			if src and (src.indexOf('http://') isnt 0)
				# no http, add host
				newHost = that.host + (if src.indexOf('/') is 0 then '' else '/') + src
			else
				newHost = src.replace 'http://', ''

			# replace all slashes with underscores
			re = new RegExp '/', 'g'
			newHost = subterfuge_image_loc + newHost.replace(re, '_')

			$(@).attr 'src', newHost
			
	getConnectionInfos: ->
		$ = @$
		jsonTag = $('#mitm-scraper-conn-info')
		if jsonTag.length
			connInfo = JSON.parse jsonTag.html()
			if connInfo
				@coverHtml = Templates.cover connInfo

	addConnectionInfoHtml: ->
		if @connInfo
			html = '<ul>'
			for k, v of @connInfo
				html += '<li>' + k + ': ' + v + '</li>'
			html += '</ul>'
			@$('body').prepend html
			

	save: ->
		#console.log @$.html()
		publishName = 'new:printable:' + @timestamp
		redisClient.publish publishName, @$.html(), redis.print
		if @coverHtml
			redisClient.publish publishName + '_cover', @coverHtml, redis.print
		#fs.writeFile 'pages/' + @timestamp + '.html', @$.html()
