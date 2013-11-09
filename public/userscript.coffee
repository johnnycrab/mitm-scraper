

class HTMLScraper
	constructor: ->

		# get the raw HTML
		@html = document.documentElement.innerHTML
	run: (cb) ->
		cb @html
		#@convertImages =>
			#cb @html

	convertImages: (cb) ->
		waitForCount = 0

		checkAndCb = ->
			if waitForCount is 0 then cb()

		# get all images, iterate over them and replace it in our raw html
		imgs = document.getElementsByTagName 'img'
		for img in imgs
			if img.complete
				@convertImageAndReplace img
			else
				waitForCount++
				img.onload = =>
					do (img) =>
						@convertImageAndReplace img
						waitForCount--
						checkAndCb()
		checkAndCb()

	convertImageAndReplace: (img) ->
		base64Data = @imgToBase64 img
		if base64Data
			@html = @html.replace img.attributes.src.value, base64Data


	imgToBase64: (img) ->
		retVal = null
		canvas = document.createElement 'canvas'
		canvas.width = img.width
		canvas.height = img.height
		context = canvas.getContext '2d'
		context.drawImage img, 0, 0
		try
			retVal = canvas.toDataURL 'image/png'
		catch
			console.log 'CORS error'
	
		retVal



do ->
	
	serverLoc = 'http://192.168.178.113:3000'

	# build up a socket connection
	socket = io.connect serverLoc

	# ping to server to check everything's okay
	socket.emit 'ping'
	socket.on 'ready', ->
		setTimeout ->
			###
			cssText = ''
			for stylesheet in document.styleSheets
				if stylesheet.href
					for cssRule in stylesheet.cssRules
						cssText += cssRule.cssText

			console.log cssText
			###

			scraper = new HTMLScraper()
			scraper.run (result) ->
				socket.emit 'scrape', JSON.stringify
					page: result
					host: window.location.host
					fullUrl: window.location.href
					title: window.document.title
					uagent: navigator.userAgent
					encoding: document.characterSet
		, 3000
	
	@