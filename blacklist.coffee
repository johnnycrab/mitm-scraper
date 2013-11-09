Blacklist = {}

Blacklist.lists =
	'title': [
		'Facebook Connect Helper'
	]
	'host': [
		'googleads'
		'adserv'
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

	for h in Blacklist.lists.host
		if pageTransformer.host.indexOf(h) >= 0
			blacklisted = true

	blacklisted


module.exports = Blacklist