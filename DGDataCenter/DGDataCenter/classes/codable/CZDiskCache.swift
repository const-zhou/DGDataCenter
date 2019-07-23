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
import UIKit

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
        return "create table if not exists manifest (key text, filename text, size integer, inline_data blob, modification_time integer, last_access_time integer, primary key(key)); create index if not exists last_access_time_idx on manifest(last_access_time);"
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
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
//    private let _lock = NSLock()
    
//    var readQueue = DispatchQueue.init(label: "com.cz.disk.read")
    
//    var isReadBusying: Bool = false
//    var readStartTime: TimeInterval = -1
    
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
    
    func releaseAllStmts() {
        _statementCache.forEach { item in
            sqlite3_finalize(item.value)
        }
        _statementCache.removeAll()
    }
    
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
            let sqliteDb = _CZSqliteDataBbase(dbPointer: db)
            do {
                try sqliteDb.createTable(table: _CZStorageItem.self)
                return sqliteDb
            } catch {
                print(sqliteDb.errorMessage)
            }
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
        throw SQLiteError.OpenDatabase(message: "No error found!")
    }
    
    func prepareStatement(sql: String) throws -> OpaquePointer? {
        if let statement = _statementCache[sql] {
            sqlite3_reset(statement)
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
        guard sqlite3_bind_text(stmt, 1, item.key.cString(using: .utf8), -1, SQLITE_TRANSIENT) == SQLITE_OK,
            sqlite3_bind_text(stmt, 2, item.fileName?.cString(using: .utf8), -1, SQLITE_TRANSIENT) == SQLITE_OK,
            sqlite3_bind_int(stmt, 3, Int32(item.size)) == SQLITE_OK,
            bind_blob(point: stmt, idx: 4, data: item.value) == SQLITE_OK,
            sqlite3_bind_int(stmt, 5, Int32(timestamp)) == SQLITE_OK,
            sqlite3_bind_int(stmt, 6, Int32(timestamp)) == SQLITE_OK
        else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
        
    private func bind_blob(point: OpaquePointer!, idx: Int32, data: Data) -> Int32 {
        var code: Int32 = SQLITE_ERROR
        #if swift(>=5.0)
        code = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(point, idx, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
        #else
        code = data.withUnsafeBytes {
            sqlite3_bind_blob(sqliteStatement, index, $0, Int32(data.count), SQLITE_TRANSIENT)
        }
        #endif
        return code
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
    
    func itemCount(key: String) throws -> Int {
        let sql = "select count(key) from manifest where key = ?1;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, nil) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.Step(message: errorMessage)
        }
        return Int(sqlite3_column_int(stmt, 0))
    }
    
    func totalItemCount() throws -> Int {
        let sql = "select count(*) from manifest;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.Step(message: errorMessage)
        }
        return Int(sqlite3_column_int(stmt, 0))
    }
    
    func totalItemSize() throws -> Int {
        let sql = "select sum(size) from manifest;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SQLiteError.Step(message: errorMessage)
        }
        return Int(sqlite3_column_int(stmt, 0))
    }
    
    func itemExists(key: String) -> Bool {
        if key.count <= 0 {
            return false
        }
        guard let count = try? itemCount(key: key) else { return false }
        return count > 0
    }
    
    func deleteAllObject() throws {
        let sql = "delete from manifest;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_step(stmt) == SQLITE_OK else {
            throw SQLiteError.Step(message: errorMessage)
        }
    }
    
    func itemsSizeInfoOrderByTimeAsc(limitCount: Int) throws -> [_CZStorageItem] {
        let sql = "select key, size from manifest order by last_access_time asc limit ?1;"
        let stmt = try prepareStatement(sql: sql)
        guard sqlite3_bind_int(stmt, 1, Int32(limitCount)) == SQLITE_OK else {
            throw SQLiteError.Bind(message: errorMessage)
        }
        var items: [_CZStorageItem] = []
        repeat {
            guard sqlite3_step(stmt) == SQLITE_ROW else {
                break
            }
            var item = _CZStorageItem()
            item.key = String(cString: sqlite3_column_text(stmt, 0))
            item.size = UInt(sqlite3_column_int(stmt, 1))
            items.append(item)
        }while true
        return items
    }
    
    func removeItemsToFitSize(maxSize: Int) {
        if maxSize == Int.max {
            return
        }
        if maxSize <= 0 {
           try? deleteAllObject()
        }
        guard var total = try? totalItemSize(), total > maxSize else {
            return
        }
        
        repeat {
            let preCount = 16
            if let items = try? itemsSizeInfoOrderByTimeAsc(limitCount: preCount) {
                for item in items {
                    if total > maxSize {
                        try? deleteItem(key: item.key)
                        total -= Int(item.size)
                    } else {
                        break
                    }
                }
            } else {
                break
            }
        } while true
    }
    
    func removeItemsToFitCount(maxCount: Int) {
        if maxCount == Int.max {
            return
        }
        if maxCount <= 0 {
            try? deleteAllObject()
        }
        
        guard var total = try? totalItemCount(), total > maxCount else {
            return
        }
        
        repeat {
            let perCount = 16
            if let items = try? itemsSizeInfoOrderByTimeAsc(limitCount: perCount) {
                for item in items {
                    if total > maxCount {
                        try? deleteItem(key: item.key)
                        total -= 1
                    } else {
                        break
                    }
                }
            } else {
                break
            }
        } while true
    }
}

class CZDiskCache {
    private var _db: _CZSqliteDataBbase?
    
    private var _lock = NSLock()
    private var _queue = DispatchQueue.init(label: "com.cz.diskcache")
    var countLimit = Int.max
    var costLimit = Int.max
    var ageLimit = Double.greatestFiniteMagnitude
    var autoTrimInterval: TimeInterval = 5.0
    
    private var _readDBPool: [_CZSqliteDataBbase?] = []
    
    private func _trimRecoursively() {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + autoTrimInterval) { [weak self] in
            self?._trimInBackground()
            self?._trimRecoursively()
        }
    }
    
    private func _trimInBackground() {
        self.trimToCost(cost: Int(self.costLimit))
        self.trimToCount(count: Int(self.countLimit))
        self.trimToAge(age: ageLimit)
    }
    
    init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?._trimInBackground()
        }
        _trimRecoursively()
        
        if let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, .userDomainMask, true).first {
            let sqlitePath = path + "/com.cz.cache/com.cz.cache.sqlite"
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: sqlitePath)  {
                try? fileManager.createDirectory(atPath: path + "/com.cz.cache", withIntermediateDirectories: true, attributes: nil)
            }
            _db = try? _CZSqliteDataBbase.openDatabase(dbPath: sqlitePath)
            
//            for _ in 0..<8 {
//                let readDB = try? _CZSqliteDataBbase.openDatabase(dbPath: sqlitePath)
//                _readDBPool.append(readDB)
//            }
        }
    }
    
//    func fetchIdleReadDB() -> _CZSqliteDataBbase? {
//        if var db = _readDBPool.first {
//            if db?.readStartTime == -1 {
//                return db
//            }
//
//            for item in _readDBPool {
//                if item?.isReadBusying == false {
//                    return item
//                }
//                if (db?.readStartTime ?? 0) > (item?.readStartTime ?? 0) {
//                    db = item
//                }
//            }
//            return db
//        }
//        return nil
//    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func containsObject(key: String) -> Bool {
        if key.count <= 0 {
            return false
        }
        _lock.lock()
        let contains = _db?.itemExists(key: key) ?? false
        _lock.unlock()
        return contains
    }
    
    func containsObject(key: String, block: @escaping (_ key: String, _ contains: Bool)->Void) {
        _queue.async { [weak self] in
            let contains = self?.containsObject(key: key) ?? false
            block(key, contains)
        }
    }
    
    func fetchObject(key: String) -> Data? {
        guard key.count > 0 else {return nil}
        _lock.lock()
//        let data = try? _db?.fetchData(key: key)
        let data = try? _db?.fetchData(key: key)
        _lock.unlock()
        return data
    }
    
    func fetchObject(key: String, block: ((_ key: String, _ data: Data?)->Void)?) {
        _queue.async { [weak self] in
            let data = self?.fetchObject(key: key)
            block?(key, data)
        }
    }
    
    func fetchString(key: String) -> String? {
        if let data = fetchObject(key: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func fetchString(key: String, block: @escaping (_ key: String, _ json: String?)->Void) {
        fetchObject(key: key) { (key, data) in
            if let data = data {
                block(key, String(data: data, encoding: .utf8))
            } else {
                block(key, nil)
            }
        }
    }
    
    func setObject(key: String, data: Data) {
        guard key.count > 0 else {return}
        _lock.lock()
        let time = CFAbsoluteTimeGetCurrent()
        let item = _CZStorageItem(key: key, value: data, fileName: "", size: UInt(data.count), modTime: time, accessTime: time)
        try? _db?.insertItem(item: item)
        _lock.unlock()
    }
    
    func setObject(key: String, data: Data, block: (()->Void)?) {
        _queue.async { [weak self] in
            self?.setObject(key: key, data: data)
            block?()
        }
    }
    
    func setObject(key: String, jsonString: String) {
        guard key.count > 0 else {return}
        if let data = jsonString.data(using: .utf8) {
            self.setObject(key: key, data: data)
        }
    }
    
    func setObject(key: String, jsonString: String, block: (()->Void)?) {
        _queue.async { [weak self] in
            self?.setObject(key: key, jsonString: jsonString)
            block?()
        }
    }
    
    func removeObject(key: String) {
        guard key.count > 0 else {return}
        _lock.lock()
        try? _db?.deleteItem(key: key)
        _lock.unlock()
    }
    
    func removeObject(key: String, block: ((_ key: String) ->Void)?) {
        _queue.async { [weak self] in
            self?.removeObject(key: key)
            block?(key)
        }
    }
    
    func removeAllObjects() {
        _lock.lock()
        try? _db?.deleteAllObject()
        _lock.unlock()
    }
    
    func removeAllObjects(block: (()->Void)?) {
        _queue.async { [weak self] in
            self?.removeAllObjects()
            block?()
        }
    }
    
    func totalCount() -> Int {
        _lock.lock()
        let count = try? _db?.totalItemCount()
        _lock.unlock()
        return count ?? 0
    }
    
    func totalCount(block: ((_ totalCount: Int)->Void)?) {
        _queue.async { [weak self] in
            let count = self?.totalCount()
            block?(count ?? 0)
        }
    }
    
    func totalCost() -> Int {
        _lock.lock()
        let count = try? _db?.totalItemSize()
        _lock.unlock()
        return count ?? 0
    }
    
    func totalCost(block: @escaping (_ totalCost: Int)->Void) {
        _queue.async { [weak self] in
            let cost = self?.totalCost()
            block(cost ?? 0)
        }
    }
    
    func trimToCount(count: Int) {
        _lock.lock()
        _db?.removeItemsToFitCount(maxCount: count)
        _lock.unlock()
    }
    
    func trimToCost(cost: Int) {
        _lock.lock()
        _db?.removeItemsToFitSize(maxSize: cost)
        _lock.unlock()
    }
    
    func trimToAge(age: TimeInterval) {
        _lock.lock()
        if age <= 0 {
            try? _db?.deleteAllObject()
        } else {
            let time = CFAbsoluteTimeGetCurrent()
            if time > age {
                let limitage = time - age
                if Int32(limitage) < INT_MAX {
                    try? _db?.deleteItems(earlierThanTime: Int32(limitage))
                }
            }
        }
        _lock.unlock()
    }
}

