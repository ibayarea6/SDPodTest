//
//  ProductImagesAPI.swift
//  CatalogDownloader
//

import Foundation

class ProductImagesAPI {
    func getDeltaImageUrls(version: String) -> [String] {
        var imageUrls = [String]()
        let tempSkuImages = getSkuImageUrlAndHash(database: .TempDatabase, version: version)
        let currentSkuImages = getSkuImageUrlAndHash(database: .NormalDatabase, version: version)
        
        for skuImage in tempSkuImages {
            if !currentSkuImages.contains(where: {$0.hash == skuImage.hash}) {
                imageUrls.append(skuImage.imageUrl)
            }
        }
        
        return imageUrls
    }
    
    private func getSkuImageUrlAndHash(database: DatabaseType, version: String) -> [SkuImage] {
        let queryString = "SELECT GRID_IMAGE_URL, GRID_IMAGE_MD5_HASH from XIQ_SKU Where GRID_IMAGE_MD5_HASH NOTNULL and length(GRID_IMAGE_MD5_HASH) > 1"
        var skuImages = [SkuImage]()
        var statement: OpaquePointer? = nil
        let dbManager = CatalogDBManager.sharedInstance
        let sephoraDBHandle = dbManager.openDataBase(type: database, version: version)
        
        if sqlite3_prepare_v2(sephoraDBHandle, queryString, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let skuImage = SkuImage()
                skuImage.imageUrl = String(cString:sqlite3_column_text(statement, 0)!)
                skuImage.hash = String(cString:sqlite3_column_text(statement, 1)!)
                
                skuImages.append(skuImage)
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(sephoraDBHandle))
            NSLog("SwiftData Error -> During: SQL Prepare: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
        
        return skuImages
    }
    
    private func getSkuImageUrlAndHash(database: DatabaseType, version: String, limit: Int) -> [SkuImage] {
        let queryString = "SELECT GRID_IMAGE_URL, GRID_IMAGE_MD5_HASH from XIQ_SKU Where GRID_IMAGE_MD5_HASH NOTNULL and length(GRID_IMAGE_MD5_HASH) > 1 limit \(limit)"
        var skuImages = [SkuImage]()
        var statement: OpaquePointer? = nil
        let dbManager = CatalogDBManager.sharedInstance
        let sephoraDBHandle = dbManager.openDataBase(type: database, version: version)
        
        if sqlite3_prepare_v2(sephoraDBHandle, queryString, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let skuImage = SkuImage()
                skuImage.imageUrl = String(cString:sqlite3_column_text(statement, 0)!)
                skuImage.hash = String(cString:sqlite3_column_text(statement, 1)!)
                
                skuImages.append(skuImage)
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(sephoraDBHandle))
            NSLog("SwiftData Error -> During: SQL Prepare: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
        
        return skuImages
    }
}
