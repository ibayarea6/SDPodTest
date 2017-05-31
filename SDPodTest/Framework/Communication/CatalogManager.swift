//
//  CatalogManager.swift
//  CatalogDL
//
//  Created by Marc McCotter on 4/13/17.
//  Copyright © 2017 Sephora. All rights reserved.
//

import Foundation

open class CatalogManager: NSObject {
    // MARK: Variables
    public var backgroundSessionCompletionHandler: (() -> ())? {
        didSet {
            sessionManager.backgroundSessionCompletionHandler = backgroundSessionCompletionHandler
        }
    }
    
    public weak var delegate: CatalogProgressDelegate!
    private(set) public var downloadInProgress = false
    internal var catalogItem = CatalogItem()
    internal var downloadItems = [DownloadItem]()
    internal var deltaImageItems:[DownloadItem]? = nil
    internal var fullSync = false
    internal(set) var percentageComplete: Float = 0
    
    private lazy var sessionManager: URLSessionManager = {
        let sessionManager = URLSessionManager()
        sessionManager.delegate = self
        
        return sessionManager
    }()
    
    public var syncCompletedToday: Bool {
        get {
            return FileManagerUtility.syncCompletionDate().sameDay(date: Date())
        }
    }
    
    // MARK - Public methods
    open func version() -> String {
        return Configuration.LibVersionKeyName
    }
    
    open func start(catalogItem: CatalogItem, fullSync: Bool) {
        if downloadInProgress {
            return
        }
        
        if downloadInProgress && catalogItem.version != catalogItem.version {
            stop()
        }
        
        self.fullSync = fullSync
        self.catalogItem = catalogItem
        self.downloadInProgress = true
        
        delegate.downloadStarted()
        delegate.downloadProgress(percentageComplete: percentageComplete)
        
        downloadItems = [DownloadItem]()
        deltaImageItems = nil
        
        // Create temp directory for this catalog version (this will not delete any existing files in the folder hierarchy)
        FileManagerUtility.createTempFolders(version: catalogItem.version)
        
        // First add the sqlite file (if it doesn't already exist)
        if let url = URL(string: catalogItem.dataPathZip) {
            if !FileManagerUtility.tempDatabaseExists(version: catalogItem.version) {
                downloadItems.append(DownloadItem(version: catalogItem.version, fileType: .SQLiteZip, url: url))
            }
        }
        
        // For a full sync we can include the image urls, otherwise the images will be obtained after the sqlite file is downloaded -> in continueDeltaSync()
        if fullSync {
            for imageUrl in catalogItem.imageUrls {
                if let url = URL(string: imageUrl) {
                    //if !FileManagerUtility.tempImageExists(version: catalogItem.version, fileName: url.lastPathComponent) {
                        downloadItems.append(DownloadItem(version: catalogItem.version, fileType: .Zip, url: url))
                   // }
                }
            }
        }
        
        if downloadItems.count > 0 {
            // We're now ready to start downloading
            sessionManager.download(downloadItems: downloadItems)
        } else {
            // We already have all of the assets, let's finish up
            fullSync ? completeSync() : continueDeltaSync()
        }
    }
    
    open func stop() {
        if downloadInProgress {
            sessionManager.cancel()
            downloadItems.removeAll()
            deltaImageItems?.removeAll()
            
            percentageComplete = 0
            downloadInProgress = false
        }
    }
    
    // MARK - Utility functions
    internal func continueDeltaSync() {
        deltaImageItems = [DownloadItem]()
        
        let deltaImageUrls = ProductImagesAPI().getDeltaImageUrls(version: catalogItem.version)
        
        if deltaImageUrls.count > 0 {
            for imageUrl in deltaImageUrls {
                if let url = URL(string: imageUrl) {
                    // No need to download the image if it's already present
                    if !FileManagerUtility.tempImageExists(version: catalogItem.version, fileName: url.lastPathComponent) {
                        deltaImageItems!.append(DownloadItem(version: catalogItem.version, fileType: .Image, url: url))
                    }
                }
            }
        }
        
        if deltaImageItems!.count > 0 {
            sessionManager.download(downloadItems: deltaImageItems!)
        } else {
            // No delta images to download, complete sync
            completeSync()
        }
    }
    
    internal func completeSync() {
        if FileManagerUtility.moveTempFilesToFinalDirectory(version: catalogItem.version, fullSync: fullSync) {
            // Store the completion date so that additional delta syncs are not attempted on the same day
            FileManagerUtility.updateBackup(true)
            FileManagerUtility.updateSyncCompletionDate(date: Date())
            FileManagerUtility.updateApplicationVersionNumber(catalogItem.version)
            CatalogDBManager.sharedInstance.closeDatabase()
            stop()
            
            DispatchQueue.main.async(execute: {() -> Void in
                self.delegate.downloadProgress(percentageComplete: 1.0)
                self.delegate.downloadFinished()
            })
        } else {
            raiseError(error: CatalogError.TempToFinalLocationError)
        }
    }
    
    internal func processSQLiteZipFile(downloadItem: DownloadItem) {
        if !FileManagerUtility.processSQLiteZipFile(downloadItem: downloadItem) {
            //downloadItem.status = .Error
            //raiseError(error: CatalogError.UnzipSQLiteError)
        }
    }
    
    internal func processZipFile(downloadItem: DownloadItem) {
        FileManagerUtility.processZipFile(downloadItem: downloadItem) { (success) in
            if success {
                self.downloadItemCompleted(downloadItem: downloadItem)
            } else {
                downloadItem.status = .Error
                self.raiseError(error: CatalogError.UnzipError)
            }
        }
    }
    
    internal func raiseError(error: CatalogError) {
        NSLog("************** DownloadManager.raiseError() -> \(error.description)")
        // Consider the sync a failure if we reach an error on any step EXCEPT downloading an image, and if
        // the error was during the downloading of a delta image, consider a failure if the device is offline
        if error != .ImageSaveError {
            stop()
            
            DispatchQueue.main.async(execute: {() -> Void in
                self.delegate.downloadFailedWithError(NSError(domain: error.description, code: error.rawValue, userInfo: nil))
            })
        }
    }
    
    internal func downloadCounts() -> (remainingItems: Int, percentageComplete: Float) {
        // This is a bit funky for the delta sync because the total # of delta images is not known until the catalog is downloaded
        var remainingItems = 0
        var percentageComplete: Float = 0.0
        
        for downloadItem in downloadItems {
            if downloadItem.status == .Active { remainingItems += 1 }
            if downloadItem.status == .InProgress { remainingItems += 1 }
            if downloadItem.status == .Processing { remainingItems += 1 }
        }
        
        if fullSync {
            // This is the easy case - there are 2 files to download and they're both contained in the downloadItems array
            percentageComplete = Float(downloadItems.count - remainingItems) / Float(downloadItems.count)
        } else {
            // For a delta sync, if we have not retrieved delta images set percentage to 0.5 (since we've downloaded one file to get here)
            // otherwise assume 0.5 + amount of images downloaded
            if let deltaImageItems = deltaImageItems {
                // If there are no delta items, we're complete
                if deltaImageItems.count == 0 {
                    percentageComplete = 1.0
                } else {
                    // Determine number of remaining delta image downloads
                    for downloadItem in deltaImageItems {
                        if downloadItem.status == .Active { remainingItems += 1 }
                        if downloadItem.status == .InProgress { remainingItems += 1 }
                    }
                    
                    percentageComplete = 0.5 + (Float(deltaImageItems.count - remainingItems) / Float(deltaImageItems.count)) * 0.5
                }
            } else {
                // If we haven't generated the delta image list, assume we're halfway done
                percentageComplete = 0.5
            }
        }
        
        // Ensure we're always sending out a valid number
        if percentageComplete.isNaN {
            percentageComplete = 0
        }
        
        return (remainingItems, percentageComplete)
    }
}

extension CatalogManager : URLSessionManagerDelegate {
    
    func downloadItemCompleted(downloadItem: DownloadItem) {
        if downloadItem.status == .Completed {
            if downloadItem.fileType == .SQLiteZip { processSQLiteZipFile(downloadItem: downloadItem) }
            if downloadItem.fileType == .Zip {
                // Unzipping is asyncronyous, so set status to processing and call this method again after unzipping is complete
                downloadItem.status = .Processing
                processZipFile(downloadItem: downloadItem)
                return
            }
        } else if downloadItem.status == .Processing && downloadItem.fileType == .Zip {
            // Finished unzipping images, set status to completed so we can continue to the logic below
            downloadItem.status = .Completed
        } else {
            if let catalogError = downloadItem.catalogError {
                raiseError(error: catalogError)
            }
        }
        
        let counts = downloadCounts()
        percentageComplete = counts.percentageComplete
        
        DispatchQueue.main.async(execute: {() -> Void in
            self.delegate.downloadProgress(percentageComplete: self.percentageComplete)
        })
        
        // Checking downloadInProgress variable in case an error was raised earlier in the process and the download was stopped
        if downloadInProgress && counts.remainingItems == 0 {
            // All assets have been downloaded if there are no active or in progress downloads
            if fullSync || deltaImageItems != nil {
                // Full sync is complete, or delta sync is complete if we've already generated list of delta images (deltaImageItems != nil)
                completeSync()
            } else {
                // Retrieve list of delta images
                continueDeltaSync()
            }
        }
    }
    
    func sessionDidBecomeInvalidWithError(error: Error?) {
        raiseError(error: .SessionInvalid)
    }
}

extension Date {
    func sameDay(date: Date?) -> Bool {
        if let d = date {
            return ComparisonResult.orderedSame == Calendar.current.compare(self, to: d, toGranularity: Calendar.Component.day)
        } else {
            return false
        }
    }
}
