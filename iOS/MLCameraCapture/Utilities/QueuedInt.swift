//
//  AtomicInt.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import Foundation

class QueuedInt {
    private let queue = DispatchQueue(label: UUID().uuidString)
    private(set) var value: Int
    
    init(_ v: Int = 0) { value = v }
    
    func increment (){
        queue.async { self.value += 1 }
    }
    func decrement() {
        queue.async { self.value -= 1 }
    }
}
