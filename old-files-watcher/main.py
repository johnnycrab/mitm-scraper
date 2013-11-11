import os, time
import shutil

basePath = './'
folderNames = ['images', 'css']
usedFolderName = 'used'
interval = 600 # 10 min
diff = 300 # 5 min

def getPath(folderName): 
	return basePath + '%s/' % (folderName)

def getMoveToPath(folderName):
	return getPath(folderName) + '%s/' % (usedFolderName)

def setupFolders():
	for folderName in folderNames:
		moveToPath = getMoveToPath(folderName)
		
		if not os.path.exists(moveToPath):
			os.makedirs(moveToPath)


def moveOldFiles():
	for folderName in folderNames:
		path = getPath(folderName) #basePath + '%s/' % (folderName)
		moveToPath = getMoveToPath(folderName)

		for fileName in os.listdir(path):
			filePath = path + fileName
			if os.path.isfile(filePath) and diff < (time.time() - os.path.getmtime(filePath)):
				print fileName
				shutil.move(filePath, moveToPath + fileName)

	# rewind !
	time.sleep(interval)
	moveOldFiles()

setupFolders()
moveOldFiles()