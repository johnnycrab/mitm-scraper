var system = require('system'),
	page = require('webpage').create(),
	filename = system.args[1],
	html = system.args[2];


page.viewportSize = { width: 1400, height: 900 };
page.paperSize = { format: "A4", orientation: "portrait", margin: "1cm" };

page.content = html;

window.setTimeout(function () {
	page.render('pdfs/' + filename + '.pdf');
	phantom.exit();
	console.log('Saved pdf...');
}, 1000);