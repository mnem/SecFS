//
//  SecFSFileManager.swift
//  SecFSExample
//
//  Created by David Wagner on 10/10/2016.
//  Copyright © 2016 David Wagner. All rights reserved.
//

import Foundation

class SecFSFileManager {
    fileprivate var fsi:secfs_filesystem_t
    fileprivate var fsd:secfs_filesystem_t
    
    fileprivate var filenamesToIndexMap = [String:Data]()
    
    init?() {
        fsi = secfs_open("__TEXT", "sfsi");
        guard secfs_fs_is_valid(&fsi) else { return nil }
        
        fsd = secfs_open("__TEXT", "sfsd");
        guard secfs_fs_is_valid(&fsd) else { return nil }
        
        for i in 0..<secfs_num_files(&fsi) {
            guard let filename = stringFromFSData(fs: &fsi, index: i) else {
                secfs_close(&fsi)
                secfs_close(&fsd)
                print("ERROR: Could not read filename data in sfsi")
                return nil
            }
            
            guard let file = fsData(fs: &fsd, index: i) else {
                secfs_close(&fsi)
                secfs_close(&fsd)
                print("ERROR: Could not read file data in sfsd")
                return nil
            }
            
            filenamesToIndexMap[filename] = file
        }
    }
    
    fileprivate func fsData(fs:UnsafeMutablePointer<secfs_filesystem_t>!, index:UInt64) -> Data? {
        let byteLength = secfs_file_length(fs, index)
        guard let data = UnsafeMutablePointer(mutating: secfs_file_data(fs, index)) else { return nil }
        return Data(bytesNoCopy: data, count: Int(byteLength), deallocator: .none)
    }
    
    fileprivate func stringFromFSData(fs:UnsafeMutablePointer<secfs_filesystem_t>!, index:UInt64) -> String? {
        guard let filenameData = fsData(fs: fs, index: index) else { return nil }
        return String(data: filenameData, encoding: .utf8)
    }
    
    func dataForFilename(filename:String) -> Data? {
        return filenamesToIndexMap[filename]
    }
    
}
