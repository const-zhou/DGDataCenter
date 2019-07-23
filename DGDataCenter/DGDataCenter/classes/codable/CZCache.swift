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
    private var _kvoBlockMap: [String: [AnyObject]] = [:]
    
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
            if T.self == Data.self {
                return data as! T
            }
            let value = try? JSONDecoder().decode(T.self, from: data)
            if value != nil {
                memCache.setObject(key: key, object: value!)
            }
            return value
        }
        return nil
    }
    
    func setObject<T: Codable>(key: String, value: T) {
        let oldVal = memCache.objectForKey(key: key) as? T
        
        memCache.setObject(key: key, object: value)
        if T.self == String.self {
            diskCache.setObject(key: key, jsonString: value as! String)
        } else if T.self == Data.self {
            diskCache.setObject(key: key, data: value as! Data)
        } else {
            if let data = try? JSONEncoder().encode(value) {
                let jsonString = String(data: data, encoding: .utf8)
                diskCache.setObject(key: key, jsonString: jsonString ?? "")
            }
        }
        
        _dispatchBlockQueue.async { [weak self] in
            if let list = self?._kvoBlockMap[key] {
                for item in list {
                    if let observer = item as? CZWeakWrap<CZObserver<T> > {
                        observer.value?.onChange(oldVal: oldVal, newVal: value)
                    }
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
    
    func subscribe<T: Codable>(key: String, block:@escaping CZObserver<T>.ChangeBlock) -> CZDisposeAble {
        let observer = CZObserver<T>(key: key, block: block)
        if let _ = _kvoBlockMap[key] {
            _kvoBlockMap[key]?.append(CZWeakWrap(observer))
        } else {
            let list = [CZWeakWrap(observer)]
            _kvoBlockMap[key] = list
        }
        return observer
    }
}


internal protocol CZDisposeAble {
    func dispose()
    func disposed(by bag: CZDisposeBag)
}

class CZObserver<T: Codable>: CZDisposeAble {
    typealias ChangeBlock = (_ oldVal: T?, _ newVal: T)->Void
    var block: ChangeBlock?
    var key: String = ""
    
    init() {
    }
    
    init(key: String, block: ChangeBlock?) {
        self.key = key
        self.block = block
    }
    
    func onChange(oldVal: T?, newVal: T) {
        block?(oldVal, newVal)
    }
    
    func dispose() {
        key = ""
        block = nil
    }
    
    func disposed(by bag: CZDisposeBag) {
        bag.insert(observer: self)
    }
    
    deinit {
        dispose()
    }
}

class CZDisposeBag {
    private var _observerList: [CZDisposeAble] = []
    private var _lock = NSLock()
    
    func insert(observer: CZDisposeAble) {
        _lock.lock()
        _observerList.append(observer)
        _lock.unlock()
    }
    
    func dispose() {
        _lock.lock()
        _observerList.forEach { (item) in
            item.dispose()
        }
        _observerList = []
        _lock.unlock()
    }
    
    deinit {
        dispose()
    }
}


class CZWeakWrap<T: AnyObject> {
    weak var value: T?
    init(_ val: T) {
        self.value = val
    }
}
