//
//  UIViewController+fromNib.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 8/16/21.
//

import UIKit

extension UIViewController {
    
    static func loadFromNib() -> Self {
        
        func instantiateFromNib<T: UIViewController>() -> T {
            return T.init(nibName: String(describing: T.self), bundle: nil)
        }

        return instantiateFromNib()
    }

}
