//
//  CZDiskCache.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/15.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation
import QuartzCore
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
        return "pragma journal_mode = wal; pragma synchronous = normal; create table if not exists manifest (key text, filename text, size integer, inline_data blob, modification_time integer, last_access_time integer, primary key(key)); create index if not exists last_access_time_idx on manifest(last_access_time);"
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
    
    func createTable(table: SQLTable.Type) throws {
        let createTableSatement = try prepareStatement(sql: table.createStatement)
        guard sqlite3_step(createTableSatement) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
    func insertItem(item: _CZStorageItem) throws {
        let insertSql = "insert or replace into manifest(key, filename, size, inline_data, modification_time, last_access_time) values (?1, ?2, ?3, ?4, ?5, ?6);"
        let stmt = try prepareStatement(sql: insertSql)
        let timestamp = CFAbsoluteTimeGetCurrent()
        guard sqlite3_bind_text(stmt, 1, item.key.cString(using: .utf8), -1, nil) == SQLITE_OK,
            sqlite3_bind_text(stmt, 2, item.fileName?.cString(using: .utf8), -1, nil) == SQLITE_OK,
            sqlite3_bind_int(stmt, 3, Int32(item.size)) == SQLITE_OK,
            sqlite3_bind_blob(stmt, 4, item.value.rawPoint, -1, nil) == SQLITE_OK,
            sqlite3_bind_int(stmt, 5, Int32(timestamp)) == SQLITE_OK,
            sqlite3_bind_int(stmt, 6, Int32(timestamp)) == SQLITE_OK
        else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
    func updateAccessTime(key: String) throws {
        let sql = "update manifest set last_access_time = ?1 where key = ?2;"
        let stmt = try prepareStatement(sql: sql)
        let timestamp = CFAbsoluteTimeGetCurrent()
        guard sqlite3_bind_int(stmt, 1, Int32(timestamp)) == SQLITE_OK,
            sqlite3_bind_text(stmt, 2, key.cString(using: .utf8), -1, nil) == SQLITE_OK
        else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
    func deleteItem(key: String) throws {
        let sql = "delete from manifest where key = ?1;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, nil) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
    func deleteItems(lagerThanSize: Int32) throws {
        let sql = "delete from manifest where size > ?1;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_bind_int(stmt, lagerThanSize, 1) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
    func deleteItems(earlierThanTime: Int32) throws {
        let sql = "delete from manifest where last_access_time < ?1;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_bind_int(stmt, earlierThanTime, 1) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
    func fetchItem(key: String) throws -> _CZStorageItem {
        let sql = "select key, filename, size, inline_data, modification_time, last_access_time from manifest where key = ?1;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, nil) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.Step(message: errorMessage)
        }
        var item = _CZStorageItem()
        item.key = String(cString: sqlite3_column_text(stmt, 0))
        item.fileName = String(cString: sqlite3_column_text(stmt, 1))
        item.size = UInt(sqlite3_column_int(stmt, 2))
        let dataSize = sqlite3_column_bytes(stmt, 3)
        if let pointer = sqlite3_column_blob(stmt, 3), dataSize > 0 {
            item.value = Data.init(bytes: pointer, count: Int(dataSize))
        } else {
            throw SQLiteError.Step(message: errorMessage)
        }
        item.modTime = TimeInterval(sqlite3_column_int(stmt, 4))
        item.accessTime = TimeInterval(sqlite3_column_int(stmt, 5))
        return item
    }
    
    func fetchData(key: String) throws -> Data {
        let sql = "select inline_data from manifest where key = ?1;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, nil) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        let size = sqlite3_column_bytes(stmt, 0)
        if let pointer = sqlite3_column_blob(stmt, 0), size > 0 {
            return Data(bytes: pointer, count: Int(size))
        } else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
}


extension Data {
    var rawPoint: UnsafeRawPointer? {
        var pointer: UnsafeRawPointer?
        self.withUnsafeBytes { (bufferPoint) in
            pointer = UnsafeRawPointer(bufferPoint)
        }
        return pointer
    }
}
