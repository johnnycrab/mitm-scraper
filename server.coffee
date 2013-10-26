subterfuge_image_loc = 'http://192.168.178.151:3000/static/imagescraper/'

express = require 'express'
fs = require 'fs'
cheerio = require 'cheerio'

app = express()
server = require('http').createServer app
io = require('socket.io').listen server

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
		@removeScripts()
		@changeImageSources()
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
				# no http, add host
				newHost = that.host + (if src.indexOf('/') is 0 then '' else '/') + src
			else
				newHost = src.replace 'http://', ''

			# replace all slashes with underscores
			re = new RegExp '/', 'g'
			newHost = subterfuge_image_loc + newHost.replace(re, '_')
			console.log newHost
			$(@).attr 'src', newHost
			


			

	save: ->
		#console.log @$.html()
		fs.writeFile 'pages/' + @timestamp + '.html', @$.html()
