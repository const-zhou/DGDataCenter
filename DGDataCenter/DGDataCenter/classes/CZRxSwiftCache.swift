//
//  CZRxSwiftCache.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/19.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType where Element == Any {
    func cache(key: String, cache: CZCache)-> Observable<Any> {
        let cacheData: Data = cache.object(key: key) ?? Data()
        return self.startWith(cacheData).map({ data in
            if let tempData = data as? Data {
                cache.setObject(key: key, value: tempData)
            }
            return data
        })
    }
}


