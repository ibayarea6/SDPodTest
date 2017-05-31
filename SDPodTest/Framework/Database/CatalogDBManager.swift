//
//  CatalogDBManager.swift
//  CatalogDownloader
//

import Foundation

public enum DatabaseType{
    case TempDatabase
    case NormalDatabase
    case NoDatabase
}

public typealias sqlite3 = OpaquePointer

open class CatalogDBManager: NSObject {
    var currentOpenedDatabase: DatabaseType = .NoDatabase
    var database: sqlite3? = nil
    
    public static let sharedInstance = CatalogDBManager()
    
    fileprivate override init() {
        super.init()
    }
    
    func createDatabase(type: DatabaseType, version: String? = nil) -> sqlite3 {
        var databasePath = ""
        
        switch type {
        case .NormalDatabase:
            databasePath = FileManagerUtility.getDatabasePath().path
            break
        case .TempDatabase:
            databasePath = FileManagerUtility.getTempDatabasePath(version: version!).path
            break
        default:
            break
        }
        
        NSLog("Database path: \(databasePath)")
        
        if sqlite3_open(databasePath, &database) == SQLITE_OK {
            currentOpenedDatabase = type
        } else {
            NSLog("Error opening database")
            currentOpenedDatabase = .NoDatabase
        }
        
        return database!
    }
    
    public func closeDatabase() {
        if (currentOpenedDatabase != .NoDatabase){
            sqlite3_close(database);
            currentOpenedDatabase = .NoDatabase;
        }
    }
    
    public func openDataBase(type: DatabaseType, version: String? = nil) -> sqlite3 {
        if currentOpenedDatabase == type {
            return database!
        } else {
            closeDatabase()
            return createDatabase(type: type, version: version)
        }
    }
}
