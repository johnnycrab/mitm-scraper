#
# ImageScraper implementation by Johnny
#

from Scraper import Scraper

class ImageScraper(Scraper):
	_pathFromFileLocation = '/../scraper/scraper/images/'

	def getPathFromFileLoc(self):
		return ImageScraper._pathFromFileLocation