//
//  AlertController.swift
//  MLCameraCapture
//
//  Created by Wilhelm Thieme on 10/09/2019.
//  Copyright © 2019 Sogeti Nederland B.V. All rights reserved.
//

import UIKit

class AlertController {
    
    enum ActionType {
        case ok
        case settings
        case cancel
        case custom(title: String, style: UIAlertAction.Style, action: (() -> Void)?)
        
        var action: UIAlertAction {
            var title: String
            var action: (() -> Void)?
            var style: UIAlertAction.Style = .default
            switch self {
            case .ok:
                title = LocalizedString("ok")
                style = .cancel
            case .cancel:
                title = LocalizedString("cancel")
                style = .cancel
            case .settings:
                title = LocalizedString("settings")
                action = {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            case .custom(let t, let s, let a):
                title = t
                style = s
                action = a
            }
            let a = UIAlertAction(title: title, style: style) { _ in action?() }
            if style != .destructive { a.setValue(UIColor(named: "text"), forKey: "titleTextColor") }
            return a
        }
    }
    
    
    static func showAlert(on controller: UIViewController, with message: String? = nil, and actions: [ActionType] = [], of type: UIAlertController.Style = .alert) {
        guard Thread.isMainThread else { DispatchQueue.main.async { showAlert(on: controller, with: message, and: actions, of: type) }; return }
        
        let alert = UIAlertController(title: nil, message: message, preferredStyle: type)
        alert.view.tintColor = UIColor(named: "tint")
        
        actions.forEach { alert.addAction($0.action) }
        
        controller.present(alert, animated: true, completion: nil)
    }
    
}

