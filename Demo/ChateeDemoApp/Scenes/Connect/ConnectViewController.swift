//
//  ConnectViewController.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 8/16/21.
//

import UIKit

class ConnectViewController: UIViewController {

    weak var coordinator: AuthFlowControl?

    override func viewDidLoad() {
        super.viewDidLoad()

        ChateeClient.shared.connect(hostName: "www.xmpp.jp", bareJid: "nikola-alek@xmpp.jp", password: "chateeAlek001522")
        ChateeClient.shared.addProfileObserver(self)
    }
    
    private func tryLogin() {
//        get saved user credentials
    }

}

extension ConnectViewController: ProfileObserver {
    
    func accountAuth(success: Bool) {
        if success {
            self.coordinator?.login()
        } else {
            self.coordinator?.notLoggedIn()
        }
    }
    
}
