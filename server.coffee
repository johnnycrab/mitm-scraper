express = require 'express'
fs = require 'fs'

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
		page = data.page
		page = removeScripts page
		savePage page




# ! Helpers


savePage = (html) ->
	html = '<!DOCTYPE html><html>' + html + '</html>'
	timestamp = new Date().getTime()
	fs.writeFile 'pages/' + timestamp + '.html', html

removeScripts = (html) ->
	search = true
	while search
		start = html.indexOf '<script'
		end = html.indexOf '</script>'
		if start > -1 and end > -1
			html = html.substring(0, start) + html.substring(end + 9)
		else
			search = false
	html