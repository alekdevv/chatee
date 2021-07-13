//
//  MessagingManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/13/21.
//

import Foundation
import XMPPFramework
import XMPPFrameworkSwift

protocol MessagingManagerDelegate: AnyObject {
    func messagingManager(_ messagingManager: MessagingManager, didLoadRecentConversations: [ChateeRecentConversation])
    func messagingManager(_ messagingManager: MessagingManager, didLoadConversation: ChateeConversation)
    
    func messagingManager(_ messagingManager: MessagingManager, didAddNewMessage message: ChateeMessage, forRoomID roomID: String)
    func messagingManager(_ messagingManager: MessagingManager, didMarkMessageAs messageStatus: ChateeMessageStatus, forMessageID messageID: String)

    func messagingManager(_ messagingManager: MessagingManager, errorOccurred error: ChateeError)
}

class MessagingManager: NSObject {
    
    weak var delegate: MessagingManagerDelegate?
    
    private let xmppStream: XMPPStream
    private let xmppDeliveryReceipts: XMPPMessageDeliveryReceipts
    private let xmppMessageArchiveManagement: XMPPMessageArchiveManagement
    private let xmppMessageCarbons: XMPPMessageCarbons
    
    private let userJID: XMPPJID
    
    private let omemoManager: OmemoManager
//    private let fileTransferManager: FileTransferManager
    
    private let messageStorage: MessageStorage
    
    private let workQueue: DispatchQueue
    
    init(xmppStream: XMPPStream, userJID: XMPPJID, omemoManager: OmemoManager, hostName: String, messageStorage: MessageStorage = MessageStorageManager()) {
        self.xmppStream = xmppStream
        self.userJID = userJID
        self.omemoManager = omemoManager
//        self.fileTransferManager = FileTransferManager(xmppStream: self.xmppStream, hostName: hostName)
        self.messageStorage = messageStorage
        
        self.xmppDeliveryReceipts = XMPPMessageDeliveryReceipts()
        self.xmppMessageCarbons = XMPPMessageCarbons()
        self.xmppMessageArchiveManagement = XMPPMessageArchiveManagement()
        
        self.workQueue = DispatchQueue(label: "MessagingManager-WorkQueue")
        
        super.init()
        
        self.xmppStream.addDelegate(self, delegateQueue: self.workQueue)
        
        setupMessageDeliveryReceipts()
        setupMessageCarbons()
        setupMessageArchiveManagement()
    }
    
    deinit {
        self.xmppStream.removeDelegate(self)
    }
    
    /// Notify sender that you have received the message
    private func setupMessageDeliveryReceipts() {
        self.xmppDeliveryReceipts.autoSendMessageDeliveryReceipts = false
        self.xmppDeliveryReceipts.autoSendMessageDeliveryRequests = true
        self.xmppDeliveryReceipts.activate(self.xmppStream)
        self.xmppDeliveryReceipts.addDelegate(self, delegateQueue: self.workQueue)
    }
    
    /// To forward message to this users other devices
    private func setupMessageCarbons() {
        self.xmppMessageCarbons.autoEnableMessageCarbons = true
        self.xmppMessageCarbons.activate(self.xmppStream)
    }
    
    /// To get  this users archived messages from the server
    private func setupMessageArchiveManagement() {
        self.xmppMessageArchiveManagement.addDelegate(self, delegateQueue: self.workQueue)
        self.xmppMessageArchiveManagement.activate(self.xmppStream)
    }
    
    func sendMessage(messageID: String, text: String, to jidString: String, shouldEncrypt: Bool = Configuration.shared.encryptionType == .omemo) {
        Logger.shared.log("sendMessage called", level: .verbose)

        if !shouldEncrypt {
            // Without encryption it's only this
            guard let toJID = XMPPJID(string: jidString) else { return }
            
            let xmppMessage = XMPPMessage(type: "chat", to: toJID)
            xmppMessage.addBody(text)
            xmppMessage.addOriginId(messageID)
            
            self.xmppStream.send(xmppMessage)
        } else {
            self.omemoManager.encryptAndSendMessage(OutgoingMessage(remoteMessageId: messageID, messageText: text, toJid: jidString)) { [weak self] (success, error) in
                Logger.shared.log("encryptAndSendMessage callback: \(success)", level: .verbose)
                
                guard let self = self else {
                    return
                }
                
                if !success {
                    self.delegate?.messagingManager(self, errorOccurred: .encryption) // .encryptionError(error: .failedToEncrypt(messageId: messageID))
                }
            }
        }
    }
    
    func sendFile(messageID: String, text: String = "", data: Data, to jidString: String, shouldEncrypt: Bool) {
        Logger.shared.log("sendFile called", level: .verbose)
        
//        guard let toJID = XMPPJID(string: jidString) else { return }

//        TODO: FileTransferManager
//        self.fileTransferManager.send(data: data, contentType: "image/jpeg", shouldEncrypt: shouldEncrypt) { [weak self] url, error in
//            guard let url = url else {
//                return
//            }
//
//            Logger.shared.log("File successfully uploaded, url location: \(url)", level: .verbose)
//
//            let jsonObject: [String: Any] = [
//                "type": "file_url",
//                "text": text,
//                "url": "\(url)"
//            ]
//
//            guard JSONSerialization.isValidJSONObject(jsonObject),
//                  let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions.prettyPrinted),
//                  let jsonString = String(data: data, encoding: String.Encoding.utf8) else {
//
//                Logger.shared.log("sendFile json error", level: .error)
//
//                return
//            }
//
//            Logger.shared.log("sendFile file message successfully formatted", level: .verbose)
//
//            if !shouldEncrypt {
//                let xmppMessage = XMPPMessage(type: "chat", to: toJID)
//                xmppMessage.addBody(jsonString)
//                xmppMessage.addOriginId(messageID)
//
//                self?.xmppStream.send(xmppMessage)
//            } else {
//                self?.omemoManager.encryptAndSendMessage(OutgoingMessage(remoteMessageId: messageID, messageText: jsonString, toJid: jidString)) { [weak self] (success, error) in
//                    Logger.shared.log("encryptAndSendFileMessage callback: \(success)", level: .verbose)
//
//                    if !success {
//                        self?.errorDelegate?.encryptionError(error: .failedToEncrypt(messageId: messageID))
//                    }
//                }
//            }
//        }
    }
    
    func forceSendOutgoingMessages(shouldEncrypt: Bool = true) {
        Logger.shared.log("forceSendOutgoingMessages called", level: .verbose)

        self.messageStorage.loadOutgoingMessages { [weak self] outgoingMessages, error in
            outgoingMessages.forEach {
                self?.sendMessage(messageID: $0.remoteMessageId, text: $0.messageText ?? "", to: $0.toJid, shouldEncrypt: shouldEncrypt)
            }
        }
    }
    
    func loadRecentConversations() {
        Logger.shared.log("loadRecentConversations called", level: .verbose)
        
        self.messageStorage.loadRecent { recentConversations, error in
            guard error == nil else {
                // error out
                
                return
            }
            
            self.delegate?.messagingManager(self, didLoadRecentConversations: recentConversations)
        }
    }
    
    func loadConversation(withID roomID: String) {
        Logger.shared.log("loadConversation with: \(roomID) called", level: .verbose)

        self.messageStorage.loadRoom(withID: roomID) { [weak self] conversation, error in
            guard let self = self else {
                return
            }
            
            if let error = error {
                Logger.shared.log("loadConversation with: \(roomID) error \(error.localizedDescription)", level: .verbose)
                
                self.delegate?.messagingManager(self, errorOccurred: .database)
                
                return
            }
            
            guard let conversation = conversation else {
                return
            }
            
            Logger.shared.log("loadConversation with: \(roomID) messages count \(conversation.messages.count)", level: .verbose)
            
            self.delegate?.messagingManager(self, didLoadConversation: conversation)
        }
    }
    
    func loadServerArhivedMessagesFor(contactJids: [String]) {
//        let items = self.xmppRosterStorage.jids(for: self.xmppStream)
        Logger.shared.log("loadServerArhivedMessagesFor contacts: \(contactJids) called", level: .verbose)

        let contactJids = contactJids.compactMap { return XMPPJID(string: $0) }

        contactJids.forEach {
            loadServerArchive(forUserJID: $0)
        }
    }
    
    private func loadServerArchive(forUserJID otherJID: XMPPJID) {
        Logger.shared.log("loadServerArchive for user: \(otherJID) called", level: .verbose)
        
        let otherJIDString = otherJID.bare
        
        self.messageStorage.getLastMessageTimestamp(withRoomId: otherJIDString) { [weak self] lastTimestamp, error in
            guard let lastTimestamp = lastTimestamp else { return }
            guard let thisUserJID = self?.userJID.bareJID else { return }
            
            let dateTimeFormatter = DateFormatter()
            dateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"  // Format: 2010-11-05T13:05:00
            let dateString = dateTimeFormatter.string(from: lastTimestamp.addingTimeInterval(0.5))
            
            let startField = XMPPMessageArchiveManagement.field(withVar: "start", type: nil, andValue: dateString)
            let withField = XMPPMessageArchiveManagement.field(withVar: "with", type: nil, andValue: otherJIDString)
            
            var fields = [XMLElement]()
            fields.append(startField)
            fields.append(withField)

            self?.xmppMessageArchiveManagement.retrieveMessageArchive(at: thisUserJID, withFields: fields, with: nil)
        }
    }
    
    // MARK: Saving non-encrypted messages/files
    
    private func saveTextMessage(_ message: XMPPMessage, date: Date, status: ChateeMessageStatus) {
        saveMessage(message, fileUrl: nil, date: Date(), status: status)
    }
    
    private func saveFileMessage(_ message: XMPPMessage, fileUrl: URL, date: Date, status: ChateeMessageStatus) {
        Logger.shared.log("saveFileMessage called", level: .verbose)
        
//        TODO: FileTransferManager
//        self.fileTransferManager.download(url: fileUrl) { [weak self] localFileUrl, error in
//            guard let localFileUrl = localFileUrl else {
//                return
//            }
//
//            self?.saveMessage(message, fileUrl: localFileUrl.absoluteString, date: Date(), status: status)
//        }
    }
    
    private func saveMessage(_ message: XMPPMessage, fileUrl: String?, date: Date, status: ChateeMessageStatus) {
        guard let messageId = message.originId, let toJID = message.to?.bare, let text = message.body else { return }
        guard let fromJID = message.from?.bare else { return }
        
        let roomID = userJID.bare != toJID ? toJID : fromJID

        self.messageStorage.saveMessage(withID: messageId, text: text, mediaPath: fileUrl, roomID: roomID, senderID: fromJID, status: status, date: date) {
            [weak self] savedMessage, error in
            
            guard let self = self else {
                return
            }

            if let error = error {
                Logger.shared.log("saveMessage error: \(error.localizedDescription)", level: .error)
                
                self.delegate?.messagingManager(self, errorOccurred: .database)
                
                return
            }
            
            guard let savedMessage = savedMessage else {
                return
            }
            
            Logger.shared.log("saveMessage success: \(savedMessage)", level: .verbose)
            
            self.delegate?.messagingManager(self, didAddNewMessage: savedMessage, forRoomID: roomID)
            
            if status == .receivedUnread {
                self.sendDeliveryReceipt(for: message)
            }
        }
    }
    
    func markMessageAs(_ status: ChateeMessageStatus, messageId: String, date: Date) {
        Logger.shared.log("markMessageAs called, messageId: \(messageId), status: \(status.rawValue) ", level: .verbose)

        self.messageStorage.markMessageAs(status, messageID: messageId, date: date) { [weak self] success, error  in
            guard let self = self else {
                return
            }
            
            if let error = error {
                Logger.shared.log("markMessageAs error: \(error.localizedDescription)", level: .error)
                
                self.delegate?.messagingManager(self, errorOccurred: .database)
                
                return
            }

            guard success else {
                return
            }
            
            Logger.shared.log("markMessageAs success: \(success) ", level: .verbose)
            
            // Done on background queue
            self.delegate?.messagingManager(self, didMarkMessageAs: status, forMessageID: messageId)
        }
    }
    
    private func sendDeliveryReceipt(for message: XMPPMessage) {
        Logger.shared.log("sendDeliveryReceipt, for message: \(message)", level: .verbose)

        guard let receiptMessage = message.generateReceiptResponse else { return }
        receiptMessage.addOriginId(message.originId)
        
        self.xmppStream.send(receiptMessage)
    }
    
    private func sendReadChatMarker(for message: XMPPMessage) {
        Logger.shared.log("sendReadChatMarker, for message: \(message)", level: .verbose)
        
        let displayedMessage = message.generateDisplayedChatMarker()
        
        Logger.shared.log("sendReadChatMarker, for message.generateDisplayedChatMarker: \(displayedMessage)", level: .verbose)
    }
}

// MARK: - XMPPStreamDelegate

extension MessagingManager: XMPPStreamDelegate {
    
    // MARK: Receiving non-encrypted messages
    
    func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        
        guard !message.hasDisplayedChatMarker else {
            Logger.shared.log("xmppStream didReceive | message.hasDisplayedChatMarker : \(message)", level: .verbose)

            // Set as sentRead in messageStorage
            
            return
        }
        
        if message.type == "chat" {
            guard let json = message.body?.toJSON() as? [String: Any], let stringUrl = json["url"] as? String, let fileUrl = URL(string: stringUrl) else {
                return
            }
            
            Logger.shared.log("xmppStream didReceive | message.type : \(message.type ?? " - ")", level: .verbose)

            saveFileMessage(message, fileUrl: fileUrl, date: Date(), status: .receivedUnread)
        }

//        guard !message.isReceivedMessageCarbon else { return }
//
//        let receivedMessage = message.sentMessageCarbon?.forwardedMessage ?? message
//        let deliveryDate = message.delayedDeliveryDate
//        let statusType: MessageStatus = message.isSentMessageCarbon ? .sent : .receivedUnread
//
//        saveMessage(receivedMessage, date: deliveryDate ?? Date(), status: statusType)
    }
}

// MARK: - XMPPMessageArchiveManagementDelegate

extension MessagingManager: XMPPMessageArchiveManagementDelegate {
    
    // MARK: Receiving non-encrypted archived messages
    
    func xmppMessageArchiveManagement(_ xmppMessageArchiveManagement: XMPPMessageArchiveManagement, didReceiveMAMMessage message: XMPPMessage) {
        Logger.shared.log("xmppMessageArchiveManagement didReceiveMAMMessage | message \(message)", level: .verbose)

        guard let forwardedMessage = message.forwardedMessage, let deliveryDate = message.forwardedStanzaDelayedDeliveryDate else { return }
        
        let status: ChateeMessageStatus = forwardedMessage.from?.bareJID == self.userJID.bareJID ? .sent : .receivedUnread
        
        saveTextMessage(forwardedMessage, date: deliveryDate, status: status)
    }
    
    func xmppMessageArchiveManagement(_ xmppMessageArchiveManagement: XMPPMessageArchiveManagement, didFinishReceivingMessagesWith resultSet: XMPPResultSet) {
        Logger.shared.log("xmppMessageArchiveManagement didFinishReceivingMessagesWith | resultSet.count \(resultSet.count)", level: .verbose)
    }
}

// MARK: - XMPPMessageDeliveryReceiptsDelegate

extension MessagingManager: XMPPMessageDeliveryReceiptsDelegate {
    func xmppMessageDeliveryReceipts(_ xmppMessageDeliveryReceipts: XMPPMessageDeliveryReceipts, didReceiveReceiptResponseMessage message: XMPPMessage) {
        Logger.shared.log("xmppMessageDeliveryReceipts didReceiveReceiptResponseMessage | message \(message)", level: .verbose)
        
        guard let messageId = message.receiptResponseID else { return }
        
        markMessageAs(.delivered, messageId: messageId, date: Date())
    }
}
