//
//  LoginViewController.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

class LoginViewController: UIViewController {

    weak var coordinator: AuthFlowControl?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ChateeClient.shared.addProfileObserver(self)
    }

}


extension LoginViewController: ProfileObserver {
    
    func accountAuth(success: Bool) {
        if success {
            self.coordinator?.login()
        }
    }
    
}
