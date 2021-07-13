//
//  VCardManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

// Should be Foundation, but XMPP's delegate method uses UIImage:
// xmppvCardAvatarModule(_ vCardTempModule: XMPPvCardAvatarModule, didReceivePhoto photo: UIImage, for jid: XMPPJID)
import UIKit
import XMPPFramework
import XMPPFrameworkSwift

protocol VCardManagerDelegate: AnyObject {
    func vCardManager(_ vCardManager: VCardManager, userDidChangeAvatar avatar: Data)
    func vCardManager(_ vCardManager: VCardManager, didLoadContactAvatar avatar: Data, forContactJid contactJid: String)
    
    func vCardManager(_ vCardManager: VCardManager, errorOccurred error: ChateeError)
}

private let workQueue = DispatchQueue(label: "VCardManager-WorkQueue")

class VCardManager: NSObject {
    
    weak var delegate: VCardManagerDelegate?
    
    private let xmppStream: XMPPStream
    private let vCardStorage = XMPPvCardCoreDataStorage.sharedInstance()
    private let xmppvCardTempModule: XMPPvCardTempModule
    private let xmppvCardAvatarModule: XMPPvCardAvatarModule
    private let userJID: XMPPJID

    private let contactStorage: ContactStorage
    
    init(xmppStream: XMPPStream, userJID: XMPPJID, contactStorage: ContactStorage = ContactStorageManager()) {
        self.xmppStream = xmppStream
        self.userJID = userJID
        
        self.contactStorage = contactStorage

        self.xmppvCardTempModule = XMPPvCardTempModule(vCardStorage: self.vCardStorage!)
        self.xmppvCardAvatarModule = XMPPvCardAvatarModule(vCardTempModule: self.xmppvCardTempModule)
        
        super.init()
        
        setupVCardSupport()
        setupVCardAvatarSupport()
    }
    
    /// For storing information about users
    private func setupVCardSupport() {
        self.xmppvCardTempModule.addDelegate(self, delegateQueue: workQueue)
        self.xmppvCardTempModule.activate(self.xmppStream)
    }
    
    /// For storing avatars for users
    private func setupVCardAvatarSupport() {
        self.xmppvCardAvatarModule.addDelegate(self, delegateQueue: workQueue)
        self.xmppvCardAvatarModule.activate(self.xmppStream)
    }
    
    func changeAvatar(with imageData: Data) {
        guard let vCard = self.xmppvCardTempModule.myvCardTemp else { return }
        vCard.photo = imageData
        
        Logger.shared.log("changeAvatar called", level: .verbose)
        
        self.xmppvCardTempModule.updateMyvCardTemp(vCard)
    }
    
    func getVCardAvatarForContact(withJIDString jidString: String, subscription: ChateeContactSubscription) {
        guard let userJID = XMPPJID(string: jidString), let avatarData = self.xmppvCardAvatarModule.photoData(for: userJID) else { return }
        
        Logger.shared.log("getVCardAvatarForContact called for \(jidString)", level: .verbose)

        saveAvatar(for: jidString, avatarData: avatarData)
    }
        
    func saveAvatar(for contactJid: String, avatarData: Data, subscription: ChateeContactSubscription? = nil) {
        self.contactStorage.saveAvatar(avatarData, contactJid: contactJid) { [weak self] savedAvatar, error in
            guard let self = self else {
                return
            }
            
            if let error = error {
                Logger.shared.log("saveAvatar error: \(error.localizedDescription)", level: .error)

                self.delegate?.vCardManager(self, errorOccurred: .database)
            } else if let savedAvatar = savedAvatar {
                // Check for subscription if you want more control over which method from the delegate you want to call.
                Logger.shared.log("saveAvatar completed for \(contactJid)", level: .verbose)

                self.delegate?.vCardManager(self, didLoadContactAvatar: savedAvatar, forContactJid: contactJid)
            }
        }
    }
}


// MARK: - XMPPvCardAvatarDelegate

extension VCardManager: XMPPvCardAvatarDelegate {
    
    func xmppvCardAvatarModule(_ vCardTempModule: XMPPvCardAvatarModule, didReceivePhoto photo: UIImage, for jid: XMPPJID) {
        Logger.shared.log("xmppvCardAvatarModule didReceivePhoto | for \(jid.bareJID)", level: .verbose)

        if jid.bareJID == self.userJID.bareJID, let avatarData = photo.jpegData(compressionQuality: 1.0) {
            self.delegate?.vCardManager(self, userDidChangeAvatar: avatarData)
        } else {
            guard let avatarData = photo.jpegData(compressionQuality: 1.0) else { return }
            
            saveAvatar(for: jid.bare, avatarData: avatarData)
        }
    }
    
}
