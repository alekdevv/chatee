//
//  ChateeClient.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import Chatee

final class ChateeClient {
    
    static let shared = ChateeClient()
    
    private let chatee = Chatee.shared
    private let chateeShouldLog = Bool(ProcessInfo.processInfo.environment["ChateeLoggerEnabled"] ?? "false") ?? false
    
    private init() {
        setupChatee()
    }
    
    func connect(hostName: String, bareJid: String, password: String) {
        self.chatee.connect(hostName: hostName, bareJid: bareJid, password: password)
    }
    
    private func setupChatee() {
        self.chatee.shouldLog = chateeShouldLog
        self.chatee.encryptionType = .omemo
        self.chatee.chateeProfileDelegate = self
    }
    
}

extension ChateeClient: ChateeProfileDelegate {
    
    func chateeProfile(_ chatee: Chatee, didAuthenticate authenticated: Bool) {
        print(authenticated)
    }
    
    func chateeProfile(_ chatee: Chatee, didChangeAvatar avatar: Data) {
        
    }
    
}
