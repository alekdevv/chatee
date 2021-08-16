//
//  Coordinator.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

protocol Coordinator: AnyObject {
    
    var viewController: UIViewController? { get }
    
    func start()
    
}
