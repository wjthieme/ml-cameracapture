//
//  LocalizedString.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import Foundation

func LocalizedString(_ key: String, _ options: String...) -> String {
    var string = NSLocalizedString(key, comment: "")
    (0..<options.count).forEach { string = string.replacingOccurrences(of: "%\($0)", with: options[$0]) }
    return string
}

func localizedDate(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
    let formatter = DateFormatter()
    formatter.formatterBehavior = .behavior10_4
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle
    
    formatter.locale = Locale.current
    return formatter.string(from: date)
}

