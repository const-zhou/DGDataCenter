//
//  CZCache.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/17.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation

class CZCache {
    typealias ChangeBlock = (_ old: Any, _ new: Any)->Void
    let memCache = CZMemoryCache()
    let diskCache = CZDiskCache()
    private let _dispatchBlockQueue = DispatchQueue.init(label: "com.cz.cache.dispatchblock")
    private var _kvoBlockMap: [String: [ChangeBlock]] = [:]
    
    var autoTrimInterval: TimeInterval = 5.0 {
        didSet {
            memCache.autoTrimInterval = self.autoTrimInterval
            diskCache.autoTrimInterval = self.autoTrimInterval
        }
    }
    
    func containsObject(key: String) -> Bool {
        return memCache.containsObjectForKey(key: key) || diskCache.containsObject(key: key)
    }
    
    func object<T: Codable>(key: String) -> T? {
        if let object = memCache.objectForKey(key: key) as? T {
            return object
        }
        if T.self == String.self {
            if let value = diskCache.fetchString(key: key) as? T {
                memCache.setObject(key: key, object: value)
                return value
            }
            return nil
        }
        if let data = diskCache.fetchObject(key: key) {
            let value = try? JSONDecoder().decode(T.self, from: data)
            if value != nil {
                memCache.setObject(key: key, object: value!)
            }
            return value
        }
        return nil
    }
    
    func setObject<T: Codable>(key: String, value: T) {
        memCache.setObject(key: key, object: value)
        if T.self == String.self {
            diskCache.setObject(key: key, jsonString: value as! String)
        } else {
            if let data = try? JSONEncoder().encode(value) {
                let jsonString = String(data: data, encoding: .utf8)
                diskCache.setObject(key: key, jsonString: jsonString ?? "")
            }
        }
        
        _dispatchBlockQueue.async { [weak self] in
            if let list = self?._kvoBlockMap[key] {
                for block in list {
                    
                }
            }
        }
    }
    
    func removeObject(key: String) {
        memCache.removeObject(key: key)
        diskCache.removeObject(key: key)
    }
    
    func removeAllObjectes() {
        memCache.removeAllObjects()
        diskCache.removeAllObjects()
    }
    
    func addObserver(key: String, block: @escaping ChangeBlock) {
        if let _ = _kvoBlockMap[key] {
            _kvoBlockMap[key]?.append(block)
        } else {
            let list = [block]
            _kvoBlockMap[key] = list
        }
    }
    
    
    
}
