fs = require('fs');

var system = require('system'),
	page = require('webpage').create(),
	filename = system.args[1],
	curdir = fs.workingDirectory,
	htmlDir = curdir + '/html/',
	pdfDir = curdir + '/pdfs/',
	htmlFilepath = htmlDir + filename + '.html',
	pdfFilepath = pdfDir + filename + '.pdf';

if (fs.isFile(htmlFilepath)) {
	page.viewportSize = { width: 1400, height: 900 };
	page.paperSize = { format: "A4", orientation: "portrait", margin: "1cm" };

	page.open(htmlFilepath);

	page.onLoadFinished = function () {
		setTimeout(function () {
			page.render(pdfFilepath);
			console.log('Saved pdf ' + filename);
			//fs.remove(htmlFilepath);
			phantom.exit();
		}, 5000);
	};
}