//
//  NSLayoutConstraint+Activated.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import UIKit

extension NSLayoutConstraint {
    @discardableResult func activated(_ prio: UILayoutPriority = .required) -> NSLayoutConstraint {
        self.priority = prio
        self.isActive = true
        return self
    }
    
}

