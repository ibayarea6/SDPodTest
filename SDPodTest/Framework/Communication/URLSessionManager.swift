//
//  URLSessionManager.swift
//  CatalogDL
//
//  Created by Marc McCotter on 4/13/17.
//  Copyright © 2017 Sephora. All rights reserved.
//

import Foundation
import UIKit

protocol URLSessionManagerDelegate: class {
    func downloadItemCompleted(downloadItem: DownloadItem)
    func sessionDidBecomeInvalidWithError(error: Error?)
}

public class URLSessionManager: NSObject, URLSessionDataDelegate {
    // MARK: Variables
    public var backgroundSessionCompletionHandler: (() -> ())?
    weak var delegate: URLSessionManagerDelegate!
    internal var downloadItems:[DownloadItem]
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: NetworkManagerConfigurations.BackgroundTaskIdentifier)
        configuration.sharedContainerIdentifier = Configuration.ApplicationGroupName
        
        let session = Foundation.URLSession(configuration: configuration, delegate:self, delegateQueue: OperationQueue.main)
        
        return session
    }()
    
    override init() {
        self.downloadItems = [DownloadItem]()
    }
    
    // MARK: Public methods
    public func download(downloadItems:[DownloadItem]) {
        self.downloadItems = downloadItems
        
        for downloadItem in self.downloadItems {
            addDownloadTask(downloadItem: downloadItem)
        }
    }
    
    public func cancel() {
        downloadItems.removeAll()
        
        session.getAllTasks(completionHandler: { (downloadTasks: [URLSessionTask]) in
            for task in downloadTasks{
                task.cancel()
            }
        })
    }
    
    // MARK: Internal methods
    internal func downloadTaskFinished(downloadItem: DownloadItem) {
        // Notify caller that an item was downloaded
        delegate.downloadItemCompleted(downloadItem: downloadItem)
        
        // Check to see if any items are currently downloading or wating to be downloaded
        var remainingDownloadItems = 0
        
        for downloadItem in downloadItems {
            if downloadItem.status == .Active || downloadItem.status == .InProgress {
                remainingDownloadItems += 1
            }
        }
    }
    
    // MARK: Private methods
    private func addDownloadTask(downloadItem: DownloadItem) {
        downloadItem.status = .InProgress
        downloadItem.startTime = Date()
        
        let downloadTask = session.downloadTask(with: URLRequest(url: downloadItem.url))
        downloadTask.resume()
        downloadItem.downloadTask = downloadTask
    }
    
    internal func retryDownloadTask(downloadItem: DownloadItem, error: Error?) {
        if downloadItem.retryCount < Configuration.MaxRetryRequest - 1 {
            // Haven't reached max attempts yet, let's try again
            if error != nil {
                if let resumeData = (error! as NSError).userInfo["NSURLSessionDownloadTaskResumeData"] as? Data {
                    // We're able to resume the task
                    downloadItem.downloadTask = session.downloadTask(withResumeData: resumeData)
                } else {
                    // Start the download from the beginning
                    downloadItem.downloadTask = session.downloadTask(with: downloadItem.url)
                }
            } else {
                // Start the download from the beginning
                downloadItem.downloadTask = session.downloadTask(with: downloadItem.url)
            }
            
            downloadItem.retryCount += 1
            downloadItem.downloadTask?.resume()
        } else {
            // Reached max attempts
            downloadItem.status = .Error
            downloadItem.downloadTask = nil
            downloadItem.catalogError = downloadItem.fileType == .Image ? CatalogError.ImageSaveError : CatalogError.DownloadError
            
            downloadTaskFinished(downloadItem: downloadItem)
        }
    }
}

extension URLSessionManager : URLSessionDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil && (error! as NSError).code != NSURLErrorCancelled {
            NSLog("************** urlSession:didCompleteWithError: (code: \((error! as NSError).code)) (error: \(error.debugDescription))")
            
            if let downloadItem = downloadItems.filter({$0.downloadTask == task}).first {
                retryDownloadTask(downloadItem: downloadItem, error: error)
            }
        }
    }
    
    func URLSession(_ session: Foundation.URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingToURL location: URL) {
        if let downloadItem = downloadItems.filter({$0.url == downloadTask.originalRequest?.url}).first {
            downloadItem.saveItem(fromLocation: location)
            
            if downloadItem.isValid() {
                downloadItem.downloadTask = nil
                downloadItem.status = .Completed
                downloadItem.endTime = Date()
                downloadTaskFinished(downloadItem: downloadItem)
            } else {
                // Downloaded item is not valid, retry
                retryDownloadTask(downloadItem: downloadItem, error: nil)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if error != nil {
            NSLog("************** urlSession:didBecomeInvalidWithError: (code: \((error! as NSError).code)) (error: \(error.debugDescription))")
            delegate.sessionDidBecomeInvalidWithError(error: error)
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: Foundation.URLSession) {
        if let backgroundSessionCompletionHandler = backgroundSessionCompletionHandler {
            backgroundSessionCompletionHandler()
            self.backgroundSessionCompletionHandler = nil
        }
    }
}
