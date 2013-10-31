#
# CSS Scraper implementation by Johnny
#

from Scraper import Scraper

class CSSScraper(Scraper):
	_pathFromFileLocation = '/../scraper/css/'

	def getPathFromFileLoc(self):
		return CSSScraper._pathFromFileLocation