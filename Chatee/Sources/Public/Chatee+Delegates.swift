//
//  Chatee+Delegates.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

// MARK: - XMPPManagerDelegate
extension Chatee: XMPPManagerDelegate {
    
    func xmppManager(_ xmppManager: XMPPManager, didAuthenticate: Bool) {
        self.chateeProfileDelegate?.chateeProfile(self, loggedIn: didAuthenticate)
    }
    
}
