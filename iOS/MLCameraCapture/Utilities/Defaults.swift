//
//  Defaults.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import Foundation

enum Defaults: String {
    
    case kCropSquare
    case kCurrentCategory

    var string: String { return UserDefaults.standard.string(forKey: rawValue) ?? "" }
    var int: Int { return UserDefaults.standard.integer(forKey: rawValue) }
    var bool: Bool { return UserDefaults.standard.bool(forKey: rawValue) }
    func set(_ value: Any?) { UserDefaults.standard.set(value, forKey: rawValue) }
}

