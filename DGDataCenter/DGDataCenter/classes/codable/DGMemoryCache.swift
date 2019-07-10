//
//  DGMemoryCache.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/10.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation

fileprivate class _DGLinkedMapNode {
    var prev: _DGLinkedMapNode?
    var next: _DGLinkedMapNode?
    
    var time: TimeInterval = 0
    var cost: Int = 0
    var key: String = ""
    var value: Codable?
}


