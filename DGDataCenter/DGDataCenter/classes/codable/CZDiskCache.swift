//
//  CZDiskCache.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/15.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation
import SQLite3

protocol SQLTable {
    static var createStatement: String {get}
}

struct _CZStorageItem {
    var key: String = ""
    var value: Data = Data()
    var fileName: String?
    var size: UInt = 0
    var modTime: TimeInterval = 0.0
    var accessTime: TimeInterval = 0.0
}

extension _CZStorageItem: SQLTable {
    static var createStatement: String {
        return "pragma journal_mode = wal; pragma synchronous = normal; create table if not exists manifest (key text, filename text, size integer, inline_data blob, modification_time integer, last_access_time integer, extended_data blob, primary key(key)); create index if not exists last_access_time_idx on manifest(last_access_time);"
    }
}

enum SQLiteError: Error {
    case OpenDatabase(message: String)
    case Prepare(message: String)
    case Step(message: String)
    case Bind(message: String)
}

class _CZSqliteDataBbase {
    private var _statementCache: [String: OpaquePointer?] = [:]
    private var _dbPath: String = ""
    private var _dbPointer: OpaquePointer?
    
    init(dbPointer: OpaquePointer?) {
        self._dbPointer = dbPointer
    }
    
    deinit {
        if let point = _dbPointer {
            _statementCache.forEach { item in
                sqlite3_finalize(item.value)
            }
            _statementCache.removeAll()
            sqlite3_close(point)
        }
    }
}

extension _CZSqliteDataBbase {
    
    var errorMessage: String {
        if let errorPointer = sqlite3_errmsg(_dbPointer) {
            let errorMessage = String(cString: errorPointer)
            return errorMessage
        } else {
            return "No error message provided from sqlite!"
        }
    }
    
    static func openDatabase(dbPath: String) throws -> _CZSqliteDataBbase {
        var db: OpaquePointer?
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            return _CZSqliteDataBbase(dbPointer: db)
        } else {
            defer {
                if db != nil {
                    sqlite3_close(db)
                }
            }
            
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String.init(cString: errorPointer)
                throw SQLiteError.OpenDatabase(message: message)
            } else {
                throw SQLiteError.OpenDatabase(message: "No error found!")
            }
        }
    }
    
    func prepareStatement(sql: String) throws -> OpaquePointer? {
        if let statement = _statementCache[sql] {
            return statement
        } else {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(_dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                _statementCache[sql] = statement
                return statement
            } else {
                throw SQLiteError.Prepare(message: errorMessage)
            }
        }
    }
}


