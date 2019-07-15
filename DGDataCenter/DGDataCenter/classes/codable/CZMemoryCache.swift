//
//  CZMemoryCache.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/15.
//  Copyright © 2019 周敦广. All rights reserved.
//

import Foundation
import QuartzCore
import UIKit
fileprivate class _CZLinkedMapNode {
    weak var prev: _CZLinkedMapNode?
    weak var next: _CZLinkedMapNode?
    
    var time: TimeInterval = 0
    var cost: Float = 0
    var key: String = ""
    var value: Codable?
    
    static func ==(left: _CZLinkedMapNode, right: _CZLinkedMapNode) -> Bool {
        return left.key == right.key
    }
}

fileprivate class _CZLinkedMap {
    var totalCost: Float = 0
    var totalCount: UInt = 0
    
    var header: _CZLinkedMapNode?
    var tail: _CZLinkedMapNode?
    
    var nodeDictionary: [String: _CZLinkedMapNode] = [:]
    
    func insertNodeAtHead(node: _CZLinkedMapNode) {
        nodeDictionary[node.key] = node
        totalCost += node.cost
        totalCount += 1
        if header != nil {
            node.next = header
            header?.prev = node
            header = node
        } else {
            header = node
            tail = node
        }
    }
    
    func bringNodeToHead(node: _CZLinkedMapNode) {
        if (header ?? _CZLinkedMapNode()) == node {
            return
        }
        if (tail ?? _CZLinkedMapNode()) == node {
            tail = node.prev
            tail?.next = nil
        } else {
            node.next?.prev = node.prev
            node.prev?.next = node.next
        }
        node.next = header
        header?.prev = node
        node.prev = nil
        header = node
    }
    
    func removeNode(node: _CZLinkedMapNode) {
        nodeDictionary.removeValue(forKey: node.key)
        totalCount -= 1
        totalCost -= node.cost
        if (node.next != nil) {
            node.next?.prev = node.prev
        }
        if node.prev != nil {
            node.prev?.next = node.next
        }
        if node == (header ?? _CZLinkedMapNode()) {
            header = node.next
        }
        if node == (tail ?? _CZLinkedMapNode()) {
            tail = node.prev
        }
    }
    
    @discardableResult func removeTailNode() -> _CZLinkedMapNode? {
        guard let tail = self.tail else {return nil}
        nodeDictionary.removeValue(forKey: tail.key)
        totalCost -= tail.cost
        totalCount -= 1
        if (header ?? _CZLinkedMapNode()) == tail {
            header = nil
            self.header = nil
        } else {
            self.tail = self.tail?.prev
            self.tail?.next = nil
        }
        return tail
    }
    
    func removeAll() {
        totalCost = 0
        totalCount = 0
        header = nil
        tail = nil
        if nodeDictionary.count > 0 {
            nodeDictionary.removeAll()
        }
    }
}

class CZMemoryCache {
    private let _lock = NSLock()
    private let _lruCache = _CZLinkedMap()
    private let _trimQueue = DispatchQueue.init(label: "com.cz.memoryCache")
    var countLimit = UInt.max
    var costLimit = Float.Magnitude.greatestFiniteMagnitude
    var ageLimit = Double.greatestFiniteMagnitude
    var autoTrimInterval: TimeInterval = 5.0
    
    private func _trimRecoursively() {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + autoTrimInterval) { [weak self] in
            self?._trimInBackground()
            self?._trimRecoursively()
        }
    }
    
    private func _trimInBackground() {
        _trimQueue.async {
            self._trimToCost(costLimit: self.costLimit)
            self._trimToCount(countLimit: self.countLimit)
            self._trimToAge(ageLimit: self.ageLimit)
        }
    }
    
    private func _trimToCost(costLimit: Float) {
        var finish = false
        _lock.lock()
        if costLimit == 0 {
            _lruCache.removeAll()
        } else if (_lruCache.totalCost <= costLimit) {
            finish = true
        }
        _lock.unlock()
        if finish {
            return
        }
        var holder: [_CZLinkedMapNode?] = []
        while !finish {
            if _lock.try() {
                if _lruCache.totalCost > costLimit {
                    let node = _lruCache.removeTailNode()
                    if node != nil {
                        holder.append(node)
                    }
                } else {
                    finish = true
                }
                _lock.unlock()
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    private func _trimToCount(countLimit: UInt) {
        var finish = false
        _lock.lock()
        if countLimit == 0 {
            _lruCache.removeAll()
            finish = true
        } else if _lruCache.totalCount <= countLimit {
            finish = true
        }
        if finish {
            return
        }
        var holder: [_CZLinkedMapNode?] = []
        while !finish {
            if _lock.try() {
                if _lruCache.totalCount > countLimit {
                    let node = _lruCache.removeTailNode()
                    holder.append(node)
                } else {
                    finish = true
                }
                _lock.unlock()
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    private func _trimToAge(ageLimit: TimeInterval) {
        var finish = false
        let now = CACurrentMediaTime()
        _lock.lock()
        if ageLimit <= 0 {
            _lruCache.removeTailNode()
            finish = true
        } else if _lruCache.tail == nil || (now - (_lruCache.tail?.time ?? 0)) <= ageLimit {
            finish = true
        }
        _lock.unlock()
        if finish {
            return
        }
        
        var holder: [_CZLinkedMapNode?] = []
        while !finish {
            if _lock.try() {
                if _lruCache.tail != nil && (now - _lruCache.tail!.time) > ageLimit {
                    let node = _lruCache.removeTailNode()
                    holder.append(node)
                } else {
                    finish = true
                }
                _lock.unlock()
            } else {
                usleep(10 * 1000)
            }
        }
    }
    
    init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let `self` = self else {return}
            self._trimToCount(countLimit: self.countLimit)
            self._trimToCost(costLimit: self.costLimit)
            self._trimToAge(ageLimit: self.ageLimit)
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] _ in
            self?.removeAllObjects()
        }
        _trimRecoursively()
    }
    
    deinit {
        _lruCache.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
}

extension CZMemoryCache {
    var totalCount: UInt {
        _lock.lock()
        let count = _lruCache.totalCount
        _lock.unlock()
        return count
    }
    
    var totalCost: Float {
        _lock.lock()
        let cost = _lruCache.totalCost
        _lock.unlock()
        return cost
    }
    
    func containsObjectForKey(key: String) -> Bool {
        guard key.count > 0 else {
            return false
        }
        _lock.lock()
        let contains = _lruCache.nodeDictionary.contains { (val) -> Bool in
            return val.key == key
        }
        _lock.unlock()
        return contains
    }
    
    func objectForKey(key: String) -> Codable? {
        guard key.count > 0 else {return nil}
        _lock.lock()
        let node = _lruCache.nodeDictionary[key]
        node?.time = CACurrentMediaTime()
        if node != nil {
            _lruCache.bringNodeToHead(node: node!)
        }
        _lock.unlock()
        return node?.value
    }
    
    
    func setObject(key:String, object: Codable?, cost: Float = 0) {
        guard let _ = object, key.count > 0 else {
            if object == nil {
                self.removeObject(key: key)
            }
            return
        }
        _lock.lock()
        let now = CACurrentMediaTime()
        if let node = _lruCache.nodeDictionary[key] {
            _lruCache.totalCost -= node.cost
            _lruCache.totalCost += cost
            node.time = now
            node.value = object
            node.cost = cost
            _lruCache.bringNodeToHead(node: node)
        } else {
            let node = _CZLinkedMapNode()
            node.cost = cost
            node.time = now
            node.key = key
            node.value = object
            _lruCache.bringNodeToHead(node: node)
        }
        
        if _lruCache.totalCost > costLimit {
            _trimQueue.async {
                self._trimToCost(costLimit: self.costLimit)
            }
        }
        
        if _lruCache.totalCount > countLimit {
            _lruCache.removeTailNode()
        }
        _lock.unlock()
    }
    
    func removeObject(key: String) {
        guard key.count > 0 else {return}
        _lock.lock()
        if let node = self._lruCache.nodeDictionary[key] {
            _lruCache.removeNode(node: node)
        }
        _lock.unlock()
    }
    
    func removeAllObjects() {
        _lock.lock()
        _lruCache.removeTailNode()
        _lock.unlock()
    }
    
    func trimToCount(count: UInt) {
        if count == 0 {
            removeAllObjects()
        } else {
            _trimToCount(countLimit: count)
        }
    }
    
    func trimToCost(cost: Float) {
        _trimToCost(costLimit: cost)
    }
    
    func trimToAge(age: TimeInterval) {
        _trimToAge(ageLimit: age)
    }
}
