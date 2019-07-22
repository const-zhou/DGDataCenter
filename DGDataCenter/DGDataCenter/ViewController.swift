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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        for i in 0..<10 {
            print(drand48())
        }
        
        
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
//        cache.memCache.countLimit = 50
        cache.setObject(key: "2", value: String.init("hello world"))
        cache.setObject(key: "1", value: [person, person, person])

        
        let x: [Person] = cache.object(key: "1") ?? []
        print(x)
        
        let y: String = cache.diskCache.fetchString(key: "2") ?? ""
        print(y)
        
        NSLog("begin1")
        var time = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10 {
            let time = CFAbsoluteTimeGetCurrent()
            for i in 0..<10000 {
                if let ob: [Int] = self.cache.object(key: "\(i)") {
//                    print(ob)
                }
            }
            NSLog("cost: \(CFAbsoluteTimeGetCurrent() - time)")
        }
        print("total = \(CFAbsoluteTimeGetCurrent() - time)")

        print("mem count = \(cache.memCache.totalCount)")
//
//
//        time = CFAbsoluteTimeGetCurrent()
//        NSLog("begin2 ---------------------")
//        for _ in 0..<10 {
//            DispatchQueue.global().async {
//                let time = CFAbsoluteTimeGetCurrent()
//                for i in 0..<10000 {
//                    if let ob: [Int] = self.cache.object(key: "\(i)") {
//
//                    }
//                }
//                NSLog("cost: \(CFAbsoluteTimeGetCurrent() - time)")
//            }
//        }
//        print("total = \(CFAbsoluteTimeGetCurrent() - time)")
        
        
//        _ = publish.asObserver().filter{print($0); return true}.startWith(3).subscribe(onNext: { item in
//            print(item)
//        })
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5.0) { [weak self] in
            self?.publish.onNext(5)
        }
        
        
        
        test()
        sleep(2)
        test()
        
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
}
