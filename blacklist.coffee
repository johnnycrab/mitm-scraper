Blacklist = {}

Blacklist.lists =
	'title': [
		'Facebook Connect Helper'
	]
	'host': [
		'foobar.foo'
	]

Blacklist.methods = []

Blacklist.do = (pageTransformer) ->
	backlisted = false
	$ = pageTransformer.$
	# title
	title = $('title').text()
	for t in Backlist.lists.title
		if title.indexOf(t) >= 0
			backlisted = true

	for h in Backlist.lists.host
		if pageTransformer.host.indexOf h >= 0
			blacklisted = true

	blacklisted


module.exports = Blacklist