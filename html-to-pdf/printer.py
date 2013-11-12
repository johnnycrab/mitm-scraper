import os
from threading import Thread, Event
import time
import shutil

class PrintCycle(Thread):
	timeoutInSeconds 	= 10

	path_to_pdfs 		= '/usr/jj/mitm-scraper/html-to-pdf/pdfs/'
	move_to_folder		= '_used/'
	printer_name 		= 'Brother_HL-6180DW_series'


	print_max_files 	= 2
	min_file_lifetime 	= 20


	main_file_types 	= ['.pdf', '_email_body.pdf', '_email_credentials.pdf', '_webpage_credentials.pdf']
	covers_needed 		= { '.pdf': '_webpage_cover.pdf', '_email_body.pdf': '_email_cover.pdf' }

	def __init__(self, event):
		Thread.__init__(self)
		self.stopEvent = event
		movePath = self.path_to_pdfs + self.move_to_folder
		if not os.path.exists(movePath):
			os.makedirs(movePath)

	def run(self):
		while not self.stopEvent.wait(self.timeoutInSeconds):
			fileTimestampsSorted = self.getLatestFileTimestampsSorted()
			l = len(fileTimestampsSorted)
			numFiles = self.print_max_files if self.print_max_files < l else l
			for i in range(0, numFiles):
				rawTimestamp = fileTimestampsSorted[i]

				for main_file_type in self.main_file_types:
					mainFileName = rawTimestamp + main_file_type
					if mainFileName in self.allFiles:
						if self.fileIsReady(mainFileName):
							if main_file_type in self.covers_needed:
								coverFilename = rawTimestamp + self.covers_needed[main_file_type]
								if coverFilename in self.allFiles:
									self.printPdf(coverFilename)

							self.printPdf(mainFileName)


	def fileIsReady(self, filename):
		retVal = False
		fullPath = self.path_to_pdfs + filename
		try:
			timeDiff = time.time() - os.path.getmtime(fullPath)
			if timeDiff > self.min_file_lifetime:
				retVal = True
		except:
			pass

		return retVal

	def printPdf(self, filename):
		print "Printing %s ..." % filename
		full_path = self.path_to_pdfs + filename

		try:
			os.system('lpr -P  %s %s' % (self.printer_name, full_path))
			#shutil.move(full_path, self.path_to_pdfs + self.move_to_folder + filename)
		except:
			print 'File %s could not be printed' % (filename)
			pass


	def haltCycle(self):
		self.stopEvent.set()

	def getLatestFileTimestampsSorted(self):
		self.allFiles = [ f for f in os.listdir(self.path_to_pdfs) if os.path.isfile(self.path_to_pdfs + f)]
		duplicateFree = []
		for f in self.allFiles:
			if '.pdf' in f:
				f = f.replace('.pdf', '')
				ts = f.split('_')[0]
				if not ts in duplicateFree:
					duplicateFree.append(ts)

		duplicateFree.sort()
		return duplicateFree

def startCycle():
	pc = PrintCycle(Event())
	pc.start()

startCycle()