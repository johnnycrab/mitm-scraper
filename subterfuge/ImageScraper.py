#
# ImageScraper implementation by Johnny
#

import os

class ImageScraper:

	_saveFolderPath = os.path.dirname(__file__) + '/../imagescraper/imagescraper/'

	def __init__(self, host, client, data):
		self.host = host
		self.data = data
		self.client = client
		#self.createExtension()
		self.createTitle()

		self.savePath = ImageScraper._saveFolderPath + self.getTitle()

	def save(self):
		try:
			with open(self.savePath, "w") as image_file:
				image_file.write(self.data)
		except:
			pass

	def createExtension(self):
		contentType = self.client.responseHeaders.getRawHeaders("Content-Type")[-1]
		i = contentType.index("/") + 1
		self.extension = contentType[i:]

	def getExtension(self):
		return self.extension

	def createTitle(self):
		full_uri = self.host + self.client.uri
		self.title = full_uri.replace("/", "_")

	def getTitle(self):
		return self.title