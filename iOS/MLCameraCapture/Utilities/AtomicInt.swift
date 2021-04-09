//
//  AtomicInt.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import Foundation

class AtomicInt {
    private let sem = DispatchSemaphore(value: 1)
    private(set) var value: Int
    
    init(_ v: Int = 0) { value = v }
    
    func increment (){
        sem.wait()
        value += 1
        sem.signal()
    }
    func decrement() {
        sem.wait()
        value -= 1
        sem.signal()
    }
}
