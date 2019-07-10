//
//  ViewController.swift
//  DGDataCenter
//
//  Created by 周敦广 on 2019/7/10.
//  Copyright © 2019 周敦广. All rights reserved.
//

import UIKit


struct Person {
    let firstName: String
    let lastName: String
    let age: Int
}

extension Person: Codable {
    
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let person = Person(firstName: "a", lastName: "b", age: 10)
//
//        let data = try? JSONEncoder().encode(person)
//        let jsonString = String(data: data ?? Data(), encoding: String.Encoding.utf8)
//        print(jsonString)
        var jsonString = ""
        printJson(indata: person)
        printJson(indata: "hello world")
        jsonString = printJson(indata: ["abc", "dcb", "a", "b"])
        let ob: [String] = fetchObject(jsonString: jsonString) ?? []
        print(ob)
    }

    func printJson<T: Codable>(indata: T) -> String {
        let data = try? JSONEncoder().encode(indata)
        let jsonString = String(data: data ?? Data(), encoding: String.Encoding.utf8)
        print(jsonString)
        print(T.self)
        return jsonString ?? ""
    }
    
    func fetchObject<T: Codable>(jsonString: String) -> T? {
        let ob = try? JSONDecoder().decode(T.self, from: jsonString.data(using: String.Encoding.utf8) ?? Data())
        return ob
    }
    
}

