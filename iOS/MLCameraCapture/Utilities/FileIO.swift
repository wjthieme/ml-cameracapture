//
//  FileUtil.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import Foundation

public class FileIO {
    
    enum IOError: Error { case dirNotFound }
    
    private static var _dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    
    public static func dir() throws -> URL {
        guard let dir = _dir else { throw IOError.dirNotFound }
        return dir
    }
    
    public static func save(data: Data, to url: URL) throws {
        let folder = url.deletingLastPathComponent()
        if !exists(dir: folder) { try createDir(at: folder, withIntermediates: true) }
        try data.write(to: url, options: .atomicWrite)
    }
    
    public static func read(file url: URL) throws -> Data {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return data
    }
    
    public static func createDir(at url: URL, withIntermediates: Bool = false) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: withIntermediates, attributes: nil)
    }
    
    public static func exists(file url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    public static func exists(dir url: URL) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    public static func rename(url: URL, to: URL) throws {
        try FileManager.default.moveItem(at: url, to: to)
    }
    
    public static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    public static func deleteLocalFiles() throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: try dir(), includingPropertiesForKeys: nil, options: [])
        try fileURLs.forEach { try FileManager.default.removeItem(at: $0) }
    }
    
    public static func allFileNames(at url: URL? = nil) throws -> [URL] {
        let aURL = try url ?? (try dir())
        if !exists(dir: aURL) { return [] }
        return try FileManager.default.contentsOfDirectory(at: aURL, includingPropertiesForKeys: nil, options: [])
    }
    
    public static func allFiles(at url: URL? = nil) throws -> [Data] {
        var result: [Data] = []
        try allFileNames(at: url).forEach { result.append(try Data(contentsOf: $0, options: .mappedIfSafe)) }
        return result
    }
}

extension String {
    
    var filenameSafe: String {
        var invalidCharacters = CharacterSet(charactersIn: ":/")
        invalidCharacters.formUnion(.newlines)
        invalidCharacters.formUnion(.illegalCharacters)
        invalidCharacters.formUnion(.controlCharacters)
        
        return self.components(separatedBy: invalidCharacters).joined(separator: "")
    }
    
}

