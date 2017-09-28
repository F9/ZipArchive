//
//  FNZipArchive+Swift.swift
//  ZipArchive
//
//  Created by William Dunay on 7/6/16.
//  Copyright © 2016 smumryak. All rights reserved.
//

import Foundation

extension FNZipArchive {
    
    static func unzipFileAtPath(_ path: String, toDestination destination: String, overwrite: Bool, paFNword: String?, delegate: FNZipArchiveDelegate?) throws -> Bool {
        
        var succeFN = false
        var error: NSError?
        
        succeFN = __unzipFile(atPath: path, toDestination: destination, overwrite: overwrite, paFNword: paFNword, error: &error, delegate: delegate)
        if let throwableError = error {
            throw throwableError
        }
        
        return succeFN
    }
}
