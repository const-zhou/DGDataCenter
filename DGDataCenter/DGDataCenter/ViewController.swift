//
//  ViewController.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/10.
//  Copyright © 2019 周敦广. All rights reserved.
//

import UIKit
import RxSwift

struct Person {
    let firstName: String
    let lastName: String
    let age: Int
}

extension Person: Codable {
}


class Test: NSObject {
    func test(text: String, show: Bool = false) {
        print("2")
    }
}

extension Test {
    @objc func test(text: String) {
        print(text)
    }
}

class ViewController: UIViewController {
    let cache = CZCache()
    private var publish: PublishSubject<Int> = PublishSubject()
    
    var disposeBag = CZDisposeBag()
    
    let op = OperationQueue()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        op.maxConcurrentOperationCount = -1
        
        let person = Person(firstName: "zhou", lastName: "dg", age: 18)
//        cache.setObject(key: "person", value: person)
        
        
        if let person: Person = cache.object(key: "person") {
            print(person)
        }
        
//        cache.setObject(key: "12", value: "hello world")
//        cache.setObject(key: "23", value: [person, person])
        
        if let persons: [Person] = cache.object(key: "23") {
            print(persons)
        }
        cache.memCache.countLimit = 50
        cache.setObject(key: "2", value: String.init("hello world"))
        cache.setObject(key: "1", value: [person, person, person])

        
        let x: [Person] = cache.object(key: "1") ?? []
        print(x)
        
        let y: String = cache.diskCache.fetchString(key: "2") ?? ""
        print(y)
        
        
        
        cache.subscribe(key: "2") { (oldVal: String?, newVal: String) in
            print("old: \(oldVal)")
            print("new: \(newVal)")
        }.disposed(by: disposeBag)
        
        cache.setObject(key: "2", value: "11")
        
        disposeBag = CZDisposeBag()
        
        cache.setObject(key: "2", value: "588")
        
        
//        cache.setObject(key: "xx", value: true)
//        cache.setObject(key: "yy", value: 23)
//        cache.setObject(key: "zz", value: 12.00087)
        
        let xx: Bool? = cache.object(key: "xx")
        let yy: Int? = cache.object(key: "yy")
        let zz: Float? = cache.object(key: "zz")
        
        print(xx)
        print(yy)
        print(zz)
        
        threadReadTest()
        threadWriteTest()
        
        
    }
    
    func test() {
        var disposeBag: DisposeBag = DisposeBag()
        
        publish.subscribe(onNext: { item in
            print("xxx: \(item)")
            disposeBag = DisposeBag()
        }).disposed(by: disposeBag)
        
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
            self?.publish.onNext(100)
        }
    }
    
    //多线程写测试
    func threadWriteTest() {
        for i in 0..<1000 {
            op.addOperation {
                self.cache.setObject(key: "\(i)", value: i)
            }
        }
    }
    
    //多线程读测试
    func threadReadTest() {
        for i in 0..<1000 {
            op.addOperation {
                let i: Int = self.cache.object(key: "\(i)") ?? 1
                if i % 10 == 0 {
                    print(i)
                }
            }
        }
    }
}
