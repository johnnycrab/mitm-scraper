Blacklist = {}

Blacklist.lists =
	'title': [
		'Facebook Connect Helper'
		'301 Moved Permanently'
		'302 Found'
		'500 Internal Server Error'
		'Document moved'
		'Facebook Cross-Domain Messaging helper'

	]
	'host': [
		'googleads'
		'adserv'
		'player.vimeo.com'
		'widgets/tweet_button'
		'rover.ebay.com'
		'clients2.google'
		'facebook.com/plugins/like'
		'addthis.com'
		'adform.net'
		'amazon-adsystem.com'
		'.doubleclick.net'
		'adframe.php'
		'johnnycrab.com'
	]

Blacklist.methods = []

Blacklist.do = (pageTransformer) ->
	blacklisted = false
	$ = pageTransformer.$
	# title
	title = $('title').text()
	for t in Blacklist.lists.title
		if title.indexOf(t) >= 0
			blacklisted = true
			break

	for h in Blacklist.lists.host
		if pageTransformer.fullUrl.indexOf(h) >= 0
			blacklisted = true
			break

	blacklisted


module.exports = Blacklist