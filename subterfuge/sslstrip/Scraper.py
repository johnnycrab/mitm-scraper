#
# Scraper is the base class for listening to any files that go through the pipe
# and saving them appropriately (so they can be accessed later locally)
#
# This is part of the 100% Security project
#


import os

class Scraper:

	_saveFolderPath = os.path.dirname(__file__)
	_pathFromFileLocation = '/../scraper/scraper/'

	def __init__(self, host, client, data):
		self.host = host
		self.data = data
		self.client = client
		self.createTitle()

		self.savePath = self._saveFolderPath + self.getPathFromFileLoc() + self.getTitle()

	def save(self):
		try:
			with open(self.savePath, "w") as scraped_file:
				scraped_file.write(self.data)
		except:
			pass

	def createTitle(self):
		full_uri = self.host + self.client.uri
		self.title = full_uri.replace("/", "_")

	def getPathFromFileLoc(self):
		return Scraper._pathFromFileLocation

	def getTitle(self):
		return self.title