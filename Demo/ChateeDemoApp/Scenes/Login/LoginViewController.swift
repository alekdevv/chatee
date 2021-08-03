//
//  LoginViewController.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

class LoginViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        ChateeClient.shared.connect(hostName: "www.xmpp.jp", bareJid: "nikola-alek@xmpp.jp", password: "chateeAlek0015")
    }

}
