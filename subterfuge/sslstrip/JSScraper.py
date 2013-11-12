from Scraper import Scraper

class JSScraper(Scraper):
	_pathFromFileLocation = '/../scraper/scraper/js/'

	def getPathFromFileLoc(self):
		return JSScraper._pathFromFileLocation