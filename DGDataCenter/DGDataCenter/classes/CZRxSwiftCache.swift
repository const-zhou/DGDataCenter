//
//  CZRxSwiftCache.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/19.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType where E == Any {
    func cache(key: String, cache: CZCache)-> Observable<(jsonData:Any, cache: Bool)> {
        let cacheData: Data = cache.object(key: key) ?? Data()
        let json = try? JSONSerialization.jsonObject(with: cacheData, options: [])
        return self.map({ jsonObject in
            if let dic = jsonObject as? [String: Any] {
                if (dic["code"] as? Int ?? 0) != 200 {
                    return (jsonObject, false)
                }
            }
            if let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                cache.setObject(key: key, value: data)
            }
            return (jsonObject, false)
        }).startWith((json, true))
    }
}


