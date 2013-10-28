subterfuge_image_loc = 'http://192.168.178.111:5000/static/imagescraper/'

express = require 'express'
#fs = require 'fs'
redis = require 'redis'
cheerio = require 'cheerio'

app = express()
server = require('http').createServer app
io = require('socket.io').listen server

redisClient = redis.createClient(6379, "127.0.0.1")
redisClient.on 'error', (err) ->
	console.log "REDIS ERROR: " + err

server.listen 3000

app.configure ->
  app.use express.static(__dirname + '/public')

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
		@addConnectionInfoHtml()
		@save()

	removeScripts: ->
		@$('script').remove()

	changeImageSources: ->
		$ = @$
		that = @
		$('img').each ->
			src = $(@).attr 'src'
			newHost = ''
			if src.indexOf('http://') isnt 0
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
			@connInfo = JSON.parse jsonTag.html()

	addConnectionInfoHtml: ->
		if @connInfo
			html = '<ul>'
			for k, v of @connInfo
				html += '<li>' + k + ': ' + v + '</li>'
			html += '</ul>'
			@$('body').prepend html
			

	save: ->
		#console.log @$.html()
		redisClient.publish 'new:printable:' + @timestamp, @$.html(), redis.print
		#fs.writeFile 'pages/' + @timestamp + '.html', @$.html()
