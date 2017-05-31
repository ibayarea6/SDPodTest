//
//  DownloadItem.swift
//  CatalogDL
//
//  Created by Marc McCotter on 4/13/17.
//  Copyright © 2017 Sephora. All rights reserved.
//

import Foundation
import UIKit

public enum DownloadStatus {
    case Active
    case InProgress
    case Completed
    case Processing
    case Error
}

public enum FileType {
    case SQLiteZip
    case Zip
    case Image
}

public class DownloadItem {
    public var version = ""
    public var url: URL
    public var fileName = ""
    public var fileType: FileType
    public var location: URL
    public var status: DownloadStatus
    public var retryCount = 0
    public var startTime: Date?
    public var endTime: Date?
    internal var catalogError: CatalogError?
    public var downloadTask: URLSessionDownloadTask?
    
    public init(version: String, fileType: FileType, url: URL) {
        self.version = version
        self.fileType = fileType
        self.url = url
        self.status = .Active
        self.fileName = url.lastPathComponent
        
        if fileType == .SQLiteZip {
            self.location = FileManagerUtility.getTempPath(version: version).appendingPathComponent(self.fileName)
        } else {
            self.location = FileManagerUtility.getTempImagesPath(version: version).appendingPathComponent(self.fileName)
        }
    }
    
    public func saveItem(fromLocation: URL) {
        // Move from temp downloaded location to intermediate location (not final location once DL is complete)
        if !FileManager.default.fileExists(atPath: location.path) {
            do {
                try FileManager.default.moveItem(at: fromLocation, to: location)
            } catch let error as NSError {
                NSLog("Unable to move file from: \(fromLocation.path) to: \(location.path) -> \(error.debugDescription)")
            }
        }
    }
    
    public func isValid() -> Bool {
        // Right now we're only validating images, not zip files
        if fileType == .Image {
            guard UIImage(contentsOfFile: location.path) != nil else {
                FileManagerUtility.removeItem(url: location)
                return false
            }
        }
        
        return true
    }
}
