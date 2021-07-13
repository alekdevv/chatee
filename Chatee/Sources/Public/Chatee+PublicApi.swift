//
//  Chatee+PublicApi.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/13/21.
//

import Foundation

extension Chatee {
    
    /// Used to connect with XMPP server.
    public func connect(hostName: String, bareJid: String, password: String) {
        self.xmppManager.connect(hostName: hostName, bareJid: bareJid, password: password)
    }
    
}
