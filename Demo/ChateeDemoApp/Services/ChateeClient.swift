//
//  ChateeClient.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import Chatee

protocol ProfileObserver: AnyObject {
    func accountAuth(success: Bool)
}

final class ChateeClient {
    
    static let shared = ChateeClient()
    
    private let chatee = Chatee.shared
    private let chateeShouldLog = Bool(ProcessInfo.processInfo.environment["ChateeLoggerEnabled"] ?? "false") ?? false
    
    var profileObservers = [ProfileObserver]()
    
    private init() {
        setupChatee()
    }
    
    func connect(hostName: String, bareJid: String, password: String) {
        self.chatee.connect(hostName: hostName, bareJid: bareJid, password: password)
    }
    
    func addProfileObserver(_ observer: ProfileObserver) {
        self.profileObservers.append(observer)
    }
    
    private func setupChatee() {
        self.chatee.shouldLog = chateeShouldLog
        self.chatee.encryptionType = .omemo
        self.chatee.chateeProfileDelegate = self
    }
    
    private func notifyAccountAuth(success: Bool) {
        self.profileObservers.forEach {
            $0.accountAuth(success: success)
        }
    }
    
}

extension ChateeClient: ChateeProfileDelegate {
    
    func chateeProfile(_ chatee: Chatee, didAuthenticate authenticated: Bool) {
        notifyAccountAuth(success: authenticated)
    }
    
    func chateeProfile(_ chatee: Chatee, didChangeAvatar avatar: Data) {
        
    }
    
}
