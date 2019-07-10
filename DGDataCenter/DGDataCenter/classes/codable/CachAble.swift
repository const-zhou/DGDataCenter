//
//  CachAble.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/10.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation
import YYCache

fileprivate let g_cache_container = YYCache.init(name: "com.data.cache")

enum CacheLevel {
    case memory
    case memoryAndDisk
}

protocol CachAble: Codable {
    func save(key: String)
    
    func save(key: String, cacheLevel: CacheLevel)
    
    static func fectch(key: String) throws -> Self.Type
}

extension CachAble {
    func save(key: String) {
        save(key: key, cacheLevel: CacheLevel.memory)
    }
    
    func save(key: String, cacheLevel: CacheLevel) {
        g_cache_container?.setObject(<#T##object: NSCoding?##NSCoding?#>, forKey: <#T##String#>)
    }
}
