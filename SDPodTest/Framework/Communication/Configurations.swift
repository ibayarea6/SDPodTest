//
//  Configurations.swift
//  CatalogDownloader

import Foundation

public struct Configuration {
    static let ApplicationGroupName = "group.com.sephora.sd"  //application group sharing identifier
    static let BackupKeyName  = "CATALOG_BACK_UP" // This values pulls from application group NSUserDefaults
    static let BackupVersionKeyName  = "CATALOG_VERSION" // This values pulls from application group NSUserDefaults
    static let MaxRetryRequest = 3
    static let ZipKeyName = "ZIP"
    static let DownloadSqlitefileName = "xiq_small_db.sqlite"
    static let SqliteFileName = "catalog.sqlite"
    static let SyncCompletionDateKey = "SYNC_COMPLETION_DATE"
    static let LibVersionKeyName = "3.14.2017.00"
}

public struct NetworkManagerConfigurations {
    static let BackgroundTaskIdentifier = "com.sephora.storedigital.BackgroundSession"
}

public enum CatalogSynchType{
    case eCatalogStartUp
    case eCatalogDailySynch
    case eCatalogForceUpgrade
    case eCatalogNone
}

enum CatalogError: Int {
    case RequestTimedOut = -1001
    case UnzipSQLiteError = 4004
    case UnzipError = 4005
    case DownloadError = 4006
    case TempToFinalLocationError = 4007
    case ImageSaveError = 4008
    case SessionInvalid = 4009
    
    var description: String {
        switch self {
        case .RequestTimedOut: return "The request timed out"
        case .UnzipSQLiteError: return "Error unzipping catalog file"
        case .UnzipError: return "Error unzipping file"
        case .DownloadError: return "Unable to download file"
        case .TempToFinalLocationError: return "Error moving files from temp to final location"
        case .ImageSaveError: return "Error saving delta image"
        case .SessionInvalid: return "The session became invalid"
        }
    }
}

public protocol CatalogProgressDelegate: class {
    // Called when the download starts
    func downloadStarted()
    
    // A delegate method called when all the download tasks are finished successfully
    func downloadFinished()
    
    // A delegate method called when all the download tasks are completed with failure
    func downloadFailedWithError(_ error : NSError?)
    
    // Reports percentage of files downloaded
    func downloadProgress(percentageComplete: Float)
}
