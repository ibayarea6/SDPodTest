//
//  FileManagerUtility.swift
//  CatalogDownloader
//

import Foundation

class FileManagerUtility: NSObject {
    // Global methods
    class func getSharedLocationPath() -> URL {
        let fileManager = FileManager.default
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: Configuration.ApplicationGroupName)!
    }
    
    class func isBackupAvailable() -> Bool {
        let defaults = UserDefaults(suiteName: Configuration.ApplicationGroupName)
        return (defaults!.bool(forKey: Configuration.BackupKeyName))
    }
    
    class func updateBackup(_ yesOrNo: Bool) {
        let defaults = UserDefaults(suiteName: Configuration.ApplicationGroupName)
        defaults!.setValue(yesOrNo, forKey: Configuration.BackupKeyName)
        defaults!.synchronize()
    }
    
    class func updateApplicationVersionNumber(_ versionNumber: String){
        let defaults = UserDefaults(suiteName: Configuration.ApplicationGroupName)
        defaults?.setValue(versionNumber, forKey: Configuration.BackupVersionKeyName)
        defaults?.synchronize()
    }
    
    class func updateSyncCompletionDate(date: Date) {
        let defaults = UserDefaults(suiteName: Configuration.ApplicationGroupName)
        defaults?.setValue(date, forKey: Configuration.SyncCompletionDateKey)
        defaults?.synchronize()
    }
    
    class func syncCompletionDate() -> Date {
        let defaults = UserDefaults(suiteName: Configuration.ApplicationGroupName)
        
        if let date = defaults?.object(forKey: Configuration.SyncCompletionDateKey) as? Date {
            return date
        } else {
            // Return a date in the past if this NSUserDefault key has never been set
            return Date(timeIntervalSince1970: 0)
        }
    }
    
    // Final location methods
    class func getDatabasePath() -> URL {
        let dataBasePath = getSharedLocationPath().appendingPathComponent("catalog.sqlite")
        return dataBasePath
    }
    
    class func getImagesFolderPath() -> URL {
        let dataBasePath = getSharedLocationPath().appendingPathComponent("Images")
        return dataBasePath
    }
    
    class func createImagesFolder(){
        let dataBasePath = getSharedLocationPath().appendingPathComponent("Images")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: dataBasePath.path) {
            do {
                try fileManager.createDirectory(atPath: dataBasePath.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("Images path not created")
            }
        }
    }
    
    // Temp folder methods
    class func getTempPath() -> URL {
        let path = getSharedLocationPath().appendingPathComponent("temp")
        return path
    }
    
    class func getTempPath(version: String) -> URL {
        let path = getSharedLocationPath().appendingPathComponent("temp").appendingPathComponent(version)
        return path
    }
    
    class func getTempImagesPath(version: String) -> URL {
        let path = getSharedLocationPath().appendingPathComponent("temp").appendingPathComponent(version).appendingPathComponent("images")
        return path
    }
    
    class func getTempDatabasePath(version: String) -> URL {
        let path = getSharedLocationPath().appendingPathComponent("temp").appendingPathComponent(version).appendingPathComponent(Configuration.SqliteFileName)
        return path
    }
    
    class func getTempZipDatabasePath(version: String) -> URL {
        let path = getSharedLocationPath().appendingPathComponent("temp").appendingPathComponent(version).appendingPathComponent(Configuration.SqliteFileName)
        return path
    }
    
    class func tempImageExists(version: String, fileName: String) -> Bool {
        return FileManager.default.fileExists(atPath: FileManagerUtility.getTempImagesPath(version: version).appendingPathComponent(fileName).path)
    }
    
    class func tempDatabaseExists(version: String) -> Bool {
        return FileManager.default.fileExists(atPath: getTempZipDatabasePath(version: version).path)
    }
    
    // I/O manipulation methods
    class func removeTempFolder() {
        let fileManager = FileManager.default
        let path = getSharedLocationPath().appendingPathComponent("temp").path
        
        if fileManager.fileExists(atPath: path) {
            do {
                try fileManager.removeItem(atPath: path)
            } catch let error as NSError {
                print ("Error: \(error.domain)")
            }
        }
    }
    
    class func moveImageFolderToTempFolder() {
        let fromUrl = FileManagerUtility.getImagesFolderPath()
        let toUrl = FileManagerUtility.getTempPath().appendingPathComponent(UUID().uuidString)
        
        moveFileWithURL(fromUrl, toURL: toUrl)
    }
    
    @discardableResult
    class func moveFileWithURL(_ fromURL: URL, toURL: URL) -> Bool {
        var returnVal = true
        
        if FileManager.default.fileExists(atPath: toURL.path) {
            do {
                try FileManager.default.removeItem(atPath: toURL.path)
            } catch let error as NSError {
                NSLog("Unable to remove file at path: \(toURL.path), error: \(error.debugDescription)")
                return false
            }
        }
        
        do {
            try FileManager.default.moveItem(at: fromURL, to: toURL)
        } catch let error as NSError {
            NSLog("Unable to move file at path: \(toURL.path), error: \(error.debugDescription)")
            returnVal = false
        }
        
        return returnVal
    }
    
    @discardableResult
    class func removeItem(url: URL) -> Bool {
        var returnVal = false
        do {
            try FileManager.default.removeItem(atPath: url.path)
            returnVal = true
        }
        catch {
            // Do nothing
        }
        
        return returnVal
    }
    
    @discardableResult
    class func createTempFolders(version: String ) -> Bool {
        var returnVal = true
        var path = getSharedLocationPath().appendingPathComponent("temp").appendingPathComponent(version)
        let fileManager = FileManager.default
        
        // First create version folder: /temp/04.17.2017
        if !fileManager.fileExists(atPath: path.path){
            do {
                try fileManager.createDirectory(atPath: path.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("unable to create directory: \(path)")
                returnVal = false
            }
        }
        
        // Now create images folder: /temp/04.17.2017/images
        if returnVal {
            path = getSharedLocationPath().appendingPathComponent("temp").appendingPathComponent(version).appendingPathComponent("images")
            
            do {
                try fileManager.createDirectory(atPath: path.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("unable to create directory: \(path)")
                returnVal = false
            }
        }
        
        return returnVal
    }
    
    class func deleteDownloadedZipFiles() {
        let imagePath = FileManagerUtility.getImagesFolderPath()
        
        do {
            let imageDirectoryContents = try FileManager.default.contentsOfDirectory(atPath: imagePath.path)
            
            for fileName in imageDirectoryContents {
                if fileName.pathExtension().uppercased() == Configuration.ZipKeyName {
                    let zipFile = imagePath.appendingPathComponent(fileName)
                    try FileManager.default.removeItem(at: zipFile)
                }
            }
        } catch let error as NSError {
            NSLog("Error in deleteDownloadedZipFiles: \(error.debugDescription)")
        }
    }
    
    class func moveTempFilesToFinalDirectory(version: String, fullSync: Bool) -> Bool {
        var returnVal = true
        let tempImagePath = FileManagerUtility.getTempImagesPath(version: version)
        let imagePath = FileManagerUtility.getImagesFolderPath()
        
        // Create images folder (if it does not exist)
        FileManagerUtility.createImagesFolder()
        
        // Copy new database to final location
        FileManagerUtility.moveFileWithURL(FileManagerUtility.getTempDatabasePath(version: version), toURL: FileManagerUtility.getDatabasePath())
        
        if fullSync {
            // For a full sync we can remove the image directory (actually move to temp directory) and move the newly downloaded directory
            FileManagerUtility.moveImageFolderToTempFolder()
            FileManagerUtility.moveFileWithURL(tempImagePath, toURL: imagePath)
        } else {
            // For a delta sync copy the contents of the temp images directory
            do {
                let tempImageDirectoryContents = try FileManager.default.contentsOfDirectory(atPath: tempImagePath.path)
                
                for fileName in tempImageDirectoryContents {
                    // Copy image from temp to final directory
                    let tempLocation = tempImagePath.appendingPathComponent(fileName)
                    let finalLocation = imagePath.appendingPathComponent(fileName)
                    
                    FileManagerUtility.moveFileWithURL(tempLocation, toURL: finalLocation)
                }
            } catch let error as NSError {
                NSLog("Error in moveTempFilesToFinalDirectory: \(error.debugDescription)")
                returnVal = false
            }
        }
        
        // Delete temp folder and zip files if moving operations were successful
        if returnVal {
            DispatchQueue.global().async {
                FileManagerUtility.removeTempFolder()
                FileManagerUtility.deleteDownloadedZipFiles()
            }
        }
        
        return returnVal
    }
    
    class func processSQLiteZipFile(downloadItem: DownloadItem) -> Bool {
        var returnVal = false
        let location = getTempPath(version: downloadItem.version).appendingPathComponent(Configuration.SqliteFileName)
        
        FileManagerUtility.removeItem(url:location)
            
        // First unzip to /temp/version/
        let unzipped = SSZipArchive.unzipFile(atPath: downloadItem.location.path, toDestination: getTempPath(version: downloadItem.version).path)
    
        if unzipped {
            // Rename file to "catalog.sqlite"
            returnVal = moveFileWithURL(getTempPath(version: downloadItem.version).appendingPathComponent(Configuration.DownloadSqlitefileName), toURL:location)
            
            // Delete original catalog file
            if returnVal {
                FileManagerUtility.removeItem(url: downloadItem.location)
            }
        }
        
        // Update value in downloadItem to newly unzipped and renamed file
        if returnVal {
            downloadItem.fileName = location.lastPathComponent
            downloadItem.location = location
        }
        
        return returnVal
    }
    
    class func processZipFile(downloadItem: DownloadItem, completionHandler:  @escaping (Bool) -> Void) {
        let queue = DispatchQueue(label: "sephora.CatalogDownloaderFW.unzipQueue", qos: .utility)
        queue.async {
            let unzipped = SSZipArchive.unzipFile(atPath:downloadItem.location.path, toDestination: getTempImagesPath(version: downloadItem.version).path, delegate: nil)
            completionHandler(unzipped)
        }
    }
}

extension String {
    func pathExtension() -> String{
        return (self as NSString).pathExtension
    }
}
