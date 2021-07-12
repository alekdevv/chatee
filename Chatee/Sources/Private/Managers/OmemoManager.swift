//
//  OmemoManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import XMPPFramework
import SignalProtocolObjC

protocol OmemoManagerDelegate: AnyObject {
    func omemoManager(_ omemoManager: OmemoManager, didAddNewMessage message: ChateeMessage, forRoomID roomID: String)
    func omemoManager(_ omemoManager: OmemoManager, didMarkMessageAs messageStatus: ChateeMessageStatus, forMessageID messageID: String)
    
    func omemoManager(_ omemoManager: OmemoManager, errorOccurred error: ChateeError)
}

private let callbackQueue = DispatchQueue(label: "OmemoManager-callbackQueue")
private let workQueue = DispatchQueue(label: "OmemoManager-workQueue")

/// Performs Omemo operations.
class OmemoManager: NSObject {
    
    weak var delegate: OmemoManagerDelegate?
    
    private let signalManager: SignalManager
//    private let fileTransferManager: FileTransferManager // TODO: File Transfer Manager
    private let omemoStorageManager: OmemoStorageManager!
    private let messageStorage: MessageStorage
    
    private weak var omemoModule: OMEMOModule? {
        didSet {
            self.signalManager.omemoModule = self.omemoModule
        }
    }
    private weak var omemoModuleQueue: DispatchQueue?
    private weak var xmppStream: XMPPStream?
    
    private var outstandingXMPPStanzaResponseBlocks: [String: (Bool) -> Void] = [:]
    
    private var initDeviceIdFetchCallbacks: [XMPPJID: ([NSNumber], Bool) -> Void] = [:]
    private var deviceIdFetchCallbacks: [XMPPJID: ([NSNumber], Bool) -> Void] = [:]

    private let userJID: XMPPJID
    
    private let preKeyCount = 100
    
    init(xmppStream: XMPPStream, thisUserJid: XMPPJID, hostName: String) {
        self.xmppStream = xmppStream
        self.userJID = thisUserJid
        
        self.omemoStorageManager = OmemoStorageManager()
        self.signalManager = try! SignalManager()
//        self.fileTransferManager = FileTransferManager(xmppStream: xmppStream, hostName: hostName)
        self.messageStorage = MessageStorageManager()

        super.init()
    }
    
    func initBundlePublish(omemoModule: OMEMOModule) {
        if let thisDatabaseBundle = self.fetchMyBundle() {
            print("THIS DATABASE BUNDLE DEVICE ID: \(thisDatabaseBundle.deviceId)")
            self.omemoModule?.publishBundle(thisDatabaseBundle, elementId: nil)
            self.omemoModule?.publishDeviceIds([NSNumber(value: thisDatabaseBundle.deviceId)], elementId: nil)
        }
    }
    
    func fetchDevices(forJid: XMPPJID) {
        self.omemoModule?.fetchDeviceIds(for: forJid, elementId: nil)
        
        self.initDeviceIdFetchCallbacks[forJid] = { fetchedDevices, success in
            if success  {
                fetchedDevices.forEach { deviceId in
                    if self.signalManager.registrationId != Int(truncating: deviceId) {
                        self.omemoStorageManager.addDevice(for: forJid.bare, deviceId: Int(truncating: deviceId))
                    }
                }
                
                self.deviceIdFetchCallbacks[forJid] = nil
            }
        }
    }
    
    func checkIfDevicesExistsFor(forJid: XMPPJID) -> Bool {
        return self.omemoStorageManager.checkIfDevicesAreStored(forJid: forJid.bare)
    }
    
    private func prepareSession(for jid: String, completion: @escaping (Bool) -> Void) {
        var devices = omemoStorageManager.getDevicesForJID(jid)

        guard let xmppJid = XMPPJID(string: jid) else {
            callbackQueue.async {
                completion(false)
            }
            return
        }
        
        let bundleFetch = { [weak self] in
            guard let strongSelf = self else { return }
            
            var finalSuccess = true
            
            let group = DispatchGroup()
            
            // For each device Check if we have a session. If not then we need to fetch it from their XMPP server.
            for deviceId in devices where deviceId != strongSelf.signalManager.registrationId {
                let deviceId = Int32(deviceId)
                
                if !strongSelf.signalManager.sessionRecordExistsForUsername(jid, deviceId: deviceId) {
                    // No session for this buddy and device combo. We need to fetch the bundle.
                    // No public idenity key data. We don't have enough information (for the user and UI) to encrypt this message.
                    
                    let elementId = UUID().uuidString
                    
                    group.enter()
                    
                    // Hold on to a closure so that when we get the call back from OMEMOModule we can call this closure.
                    strongSelf.outstandingXMPPStanzaResponseBlocks[elementId] = { success in
                        if (!success) {
                            finalSuccess = false
                        }
                        
                        group.leave()
                    }
                    
                    // Fetch the bundle
                    strongSelf.omemoModule?.fetchBundle(forDeviceId: UInt32(deviceId), jid: xmppJid, elementId: elementId)
                }
            }
            
            group.notify(queue: callbackQueue) {
                completion(finalSuccess)
            }
        }
        
        let deviceFetch = {
            let group = DispatchGroup()
            group.enter()
            
            self.omemoModule?.fetchDeviceIds(for: xmppJid, elementId: nil)
            
            self.deviceIdFetchCallbacks[xmppJid] = { fetchedDevices, success in
                fetchedDevices.forEach { deviceId in
                    if self.signalManager.registrationId != Int(truncating: deviceId) {
                        self.omemoStorageManager.addDevice(for: xmppJid.bare, deviceId: Int(truncating: deviceId))
                    }
                }

                devices = self.omemoStorageManager.getDevicesForJID(jid)
                
                if success {
                    self.deviceIdFetchCallbacks[xmppJid] = nil
                }

                group.leave()
            }
            
            group.wait()
            
            bundleFetch()
        }
        
        workQueue.async {
            // We are trying to send to someone but haven't fetched any devices
            // this might happen if we aren't subscribed to someone's presence in a group chat
            if devices.count == 0 {
                deviceFetch()
            } else {
                bundleFetch()
            }
        }
    }
    
    func encryptAndSendMessage(_ message: OutgoingMessage, noOfAttempts: Int = 1, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        guard noOfAttempts < 4 else {
            // Too Much attempts, not succesful
            completion(false, nil)
            
            return
        }
        let group = DispatchGroup()
        
        let prepareCompletion = { (success: Bool) in
            group.leave()
        }
        
        let destinationJID = XMPPJID(string: message.toJid)!
        
        saveTextMessage(withID: message.remoteMessageId, text: message.messageText ?? "", roomID: destinationJID.bare, senderID: self.userJID.bare, status: .outgoing, date: Date())
                
        group.enter()
        
        prepareSession(for: destinationJID.bare, completion: prepareCompletion)
        
        group.enter()
        
        prepareSession(for: self.userJID.bare, completion: prepareCompletion)

        group.notify(queue: workQueue) {
            // Strong self works here
            
            guard let messageBody = message.messageText, let ivData = SignalHelper.generateIV(),
                let keyData = SignalHelper.generateSymmetricKey(), let messageBodyData = messageBody.data(using: String.Encoding.utf8) else {
                return
            }
            
            do {
                // Create the encrypted payload
                let gcmData = try SignalHelper.encryptData(messageBodyData, key: keyData, iv: ivData)
                
                // This does the signal encryption. If we fail it doesn't matter here. We end up trying the next device and fail later if no devices worked.
                let encryptClosure: (Int) -> (OMEMOKeyData?) = { deviceId in
                    do {
                        // New OMEMO format puts auth tag inside omemo session
                        // See https://github.com/siacs/Conversations/commit/f0c3b31a42ac6269a0ca299f2fa470586f6120be#diff-e9eacf512943e1ab4c1fbc21394b4450R170
                        let payload = keyData + gcmData.authTag
                        
                        return try self.encryptPayloadWithSignalForDevice(UInt32(deviceId), payload: payload)
                    } catch {
                        return nil
                    }
                }
                
                /**
                 1. Get all devices for this contact.
                 2. Filter only devices that are trusted.
                 3. Encrypt to those devices.
                 4. Remove optional values
                */
                
                let contactsKeyDataArray = self.omemoStorageManager.getDevicesForJID(destinationJID.bare).map(encryptClosure).compactMap { $0 }

                // Stop here if we were not able to encrypt to any of the contacts
                if contactsKeyDataArray.count == 0 {
                    callbackQueue.async {
//                        let error = OMEMOError.noDevicesForBuddy
//
//                        completion(false, error)
                        self.encryptAndSendMessage(message, noOfAttempts: noOfAttempts + 1, completion: completion)
                    }
                    
                    return
                }
                
                /**
                 1. Get all devices for this this account.
                 2. Filter only devices that are trusted and not ourselves.
                 3. encrypt to those devices.
                 4. Remove optional values
                 */
                
                let thisUserDevicesKeyData = self.omemoStorageManager.getDevicesForThisAccount().filter { deviceId -> Bool in
                    return UInt32(deviceId) != self.signalManager.registrationId
                }.map(encryptClosure).compactMap{ $0 }

                // Combine two arrays for all key data
                let keyDataArray = thisUserDevicesKeyData + contactsKeyDataArray

                // Make sure we have encrypted the symetric key to someone
                if keyDataArray.count > 0 {
                    // New OMEMO format puts auth tag inside omemo session
                    let finalPayload = gcmData.data
                    
                    self.omemoModule?.sendKeyData(keyDataArray, iv: ivData, to: destinationJID, payload: finalPayload, elementId: message.remoteMessageId)

                    callbackQueue.async {
                        completion(true, nil)
                        
                        self.messageStorage.markMessageAs(.sent, messageID: message.remoteMessageId, date: Date()) { [weak self] success, error in
                            guard let self = self else {
                                return
                            }
                            
                            if success {
                                self.delegate?.omemoManager(self, didMarkMessageAs: .sent, forMessageID: message.remoteMessageId)
                            } else {
                                // Error saving...
                            }
                        }
                    }
                    
                    return
                } else {
                    callbackQueue.async {
//                        let error = OMEMOError.noDevices
//
//                        completion(false, error)
                        self.encryptAndSendMessage(message, noOfAttempts: noOfAttempts + 1, completion: completion)
                    }
                    
                    return
                }
            } catch {
                // This should only happen if we had an error encrypting the payload
                callbackQueue.async {
//                    completion(false, error)
                    self.encryptAndSendMessage(message, noOfAttempts: noOfAttempts + 1, completion: completion)
                }
                
                return
            }
        }
    }
    
    private func processKeyData(_ keyData: [OMEMOKeyData], iv: Data, senderDeviceId: UInt32, forJID: XMPPJID,
                                payload: Data?, delayed: Date?, forwarded: Bool, isIncoming: Bool, message: XMPPMessage) {
        let aesGcmBlockLength = 16
        
        // Check if device stored? If not, add!
        if !omemoStorageManager.checkIfDeviceIsStored(deviceId: Int(senderDeviceId)), self.signalManager.registrationId != Int(senderDeviceId) {
            self.omemoStorageManager.addDevice(for: forJID.bare, deviceId: Int(senderDeviceId))
        }
        
        guard let encryptedPayload = payload, encryptedPayload.count > 0 else { return }
        
        let addressJID = isIncoming ? forJID.bareJID : self.userJID.bareJID
        
        let rid = self.signalManager.registrationId
        
        // Could have multiple matching device id.
        // This is extremely rare but possible that the sender has another device that collides with our device id.
        var unencryptedKeyData: Data?

        print("keyData count: \(keyData.count)")
        for key in keyData where key.deviceId == rid {
            let keyData = key.data
            
            do {
                unencryptedKeyData = try self.signalManager.decryptFromAddress(keyData, name: addressJID.bare, deviceId: Int32(senderDeviceId))
                // Have successfully decripted the AES key. We should break and use it to decrypt the payload
                break
            } catch let error {
                // error decrypting
                let nsError = error as NSError
                
                print("Error decrypting!")
                
                if nsError.domain == SignalErrorDomain, nsError.code == SignalError.duplicateMessage.rawValue {
                    // Duplicate messages are benign and can be ignored
                    return
                }
                let buddyAddress = SignalAddress(name: addressJID.bare, deviceId: Int32(senderDeviceId))
                if self.signalManager.signalStorageManager.sessionRecordExists(for: buddyAddress) {
                    // Session is corrupted
                    let _ = self.signalManager.signalStorageManager.deleteSessionRecord(for: buddyAddress)
                    // Session exists and is possibly corrupted. Deleting...
                }
                return
            }
        }
                
        guard var aesKey = unencryptedKeyData else { return }

        var authTag: Data?
        
        // Treat >= 32 bytes OMEMO 'keys' as containing the auth tag.
        // https://github.com/ChatSecure/ChatSecure-iOS/issues/647
        if aesKey.count >= aesGcmBlockLength * 2 {
            authTag = aesKey.subdata(in: aesGcmBlockLength..<aesKey.count)
            aesKey = aesKey.subdata(in: 0..<aesGcmBlockLength)
        }
        
        var tmpBody: Data?
        // If there's already an auth tag, that means the payload
        // doesn't contain the auth tag.
        if authTag != nil {
            // Omemo namespace
            tmpBody = encryptedPayload
        } else {
            // 'siacs' namespace fallback
            tmpBody = encryptedPayload.subdata(in: 0..<encryptedPayload.count - aesGcmBlockLength)
            authTag = encryptedPayload.subdata(in: encryptedPayload.count - aesGcmBlockLength..<encryptedPayload.count)
        }
                
        guard let tag = authTag, let encryptedBody = tmpBody else { return }
        
        do {
            guard let messageBody = try SignalHelper.decryptData(encryptedBody, key: aesKey, iv: iv, authTag: tag),
                let messageString = String(data: messageBody, encoding: String.Encoding.utf8), messageString.count > 0 else {
                    return
                }
            
            print("Message: \(messageString)")
            
            guard let messageID = message.elementID, let toJID = message.to?.bare else { return }
            guard let fromJID = message.from?.bare else { return }

            let roomID = userJID.bare != toJID ? toJID : fromJID
            let status: ChateeMessageStatus = roomID != userJID.bare ? .receivedUnread : .sent
                                    
            if let fileUrl = fileUrl(from: messageString) {
                Logger.shared.log("Saving file message", level: .verbose)

                saveFileMessage(withID: messageID, text: messageString, remoteUrl: fileUrl, roomID: roomID, senderID: fromJID, status: status, date: Date())
            }else {
                Logger.shared.log("Saving text message", level: .verbose)

                saveTextMessage(withID: messageID, text: messageString, roomID: roomID, senderID: fromJID, status: status, date: Date())
            }
        } catch {
            self.delegate?.omemoManager(self, errorOccurred: .encryption) // .encryptionError(error: .failedToDecrypt)
            
            return
        }
    }
    
    private func saveTextMessage(withID messageID: String, text: String, roomID: String, senderID: String, status: ChateeMessageStatus, date: Date, deliveryReceiptFor message: XMPPMessage? = nil) {
        self.saveMessage(withID: messageID, text: text, roomID: roomID, senderID: senderID, status: status, date: date)
    }
    
    private func saveFileMessage(withID messageID: String, text: String, remoteUrl: URL, roomID: String, senderID: String, status: ChateeMessageStatus, date: Date, deliveryReceiptFor message: XMPPMessage? = nil) {
        Logger.shared.log("saveFileMessage called", level: .verbose)
        
//        TODO: File Transfer Manager
//        self.fileTransferManager.download(url: remoteUrl) { [weak self] localFileUrl, error in
//            guard let localFileUrl = localFileUrl else {
//                return
//            }
//
//            self?.saveMessage(withID: messageID, text: text, mediaPath: localFileUrl, roomID: roomID, senderID: senderID, status: status, date: date)
//        }
    }
    
    private func saveMessage(withID messageID: String, text: String, mediaPath: URL? = nil, roomID: String, senderID: String, status: ChateeMessageStatus, date: Date, deliveryReceiptFor message: XMPPMessage? = nil) {
        self.messageStorage.saveMessage(withID: messageID, text: text, mediaPath: mediaPath?.absoluteString, roomID: roomID, senderID: senderID, status: status, date: date) {
            [weak self] savedMessage, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                Logger.shared.log("saveMessage error: \(error.localizedDescription)", level: .error)

                self.delegate?.omemoManager(self, errorOccurred: .database)
                
                return
            }
            
            guard let savedMessage = savedMessage else {
                return
            }
            
            Logger.shared.log("saveMessage success: \(savedMessage)", level: .verbose)
            
            self.delegate?.omemoManager(self, didAddNewMessage: savedMessage, forRoomID: roomID)
            
            if let deliveryReceiptMessage = message {
                self.sendDeliveryReceipt(for: deliveryReceiptMessage)
//                self?.sendReadChatMarker(for: deliveryReceiptMessage)
            }
//            if status == .receivedUnread {
//                self.sendDeliveryReceipt(for: message)
//            }
        }
    }
    
    private func fileUrl(from jsonString: String) -> URL? {
        guard let json = jsonString.toJSON() as? [String: Any], let stringUrl = json["url"] as? String, let fileUrl = URL(string: stringUrl) else {
            return nil
        }
        
        return fileUrl
    }
    
    private func markMessageAs(_ status: ChateeMessageStatus, messageID: String, date: Date) {
        self.messageStorage.markMessageAs(status, messageID: messageID, date: date, completion: { [weak self] success, error in
            guard let self = self else {
                return
            }

            if success {
                self.delegate?.omemoManager(self, didMarkMessageAs: .sent, forMessageID: messageID)
            } else {
                self.delegate?.omemoManager(self, errorOccurred: .database)
            }
        })
    }
    
    // This was needed because of the Omemo server archived messages bug.
    private func changeMessageTimestampIfExists(messageId: String, newTimestamp: Date) {
        self.messageStorage.checkIfMessageExists(messageId: messageId) { [weak self] exists, error in
            if exists {
                self?.messageStorage.changeArchivedMessageTimestamp(messageId: messageId, newTimestamp: newTimestamp) { success, error in
                    print(success)
                }
            }
        }
    }
    
    private func sendDeliveryReceipt(for message: XMPPMessage) {
        guard let receiptMessage = message.generateReceiptResponse else { return }
        receiptMessage.addOriginId(message.elementID)
                
        self.xmppStream?.send(receiptMessage)
    }
    
    private func sendReadChatMarker(for message: XMPPMessage) {
        let m = XMPPMessage(messageType: .chat, to: message.to, elementID: message.elementID, child: nil)
        
        let displayedMessage = m.generateDisplayedChatMarker()
        displayedMessage.addOriginId(m.elementID)
        
        self.xmppStream?.send(displayedMessage)
    }
    
    private func encryptPayloadWithSignalForDevice(_ deviceId: UInt32, payload: Data) throws -> OMEMOKeyData? {
        guard let user = self.omemoStorageManager.fetchUserForDeviceId(Int(deviceId)) else {
            return nil
        }
        
        let encryptedKeyData = try self.signalManager.encryptToAddress(payload, name: user, deviceId: Int32(deviceId))
        
        let isPreKey = encryptedKeyData.type == .preKeyMessage ? true : false

        return OMEMOKeyData(deviceId: deviceId, data: encryptedKeyData.data, isPreKey: isPreKey)
    }
    
    private func isThisUsersJID(_ jid: XMPPJID) -> Bool {
        return jid.isEqual(to: self.userJID, options: .bare)
    }
    
    /** Always call on internal work queue */
    private func callAndRemoveOutstandingBundleBlock(_ elementId: String, success: Bool) {
        guard let outstandingBlock = self.outstandingXMPPStanzaResponseBlocks[elementId] else { return }
        
        outstandingBlock(success)
        
        self.outstandingXMPPStanzaResponseBlocks.removeValue(forKey: elementId)
    }
    
    /** Always call on internal work queue */
    private func callAndRemoveOutstandingDeviceIdFetch(_ jid: XMPPJID, success: Bool) {
        guard let outstandingBlock = self.deviceIdFetchCallbacks[jid] else { return }
        
        outstandingBlock([], success)
        
        self.deviceIdFetchCallbacks.removeValue(forKey: jid)
    }
}

extension OmemoManager: OMEMOModuleDelegate {
    
    public func omemo(_ omemo: OMEMOModule, publishedDeviceIds deviceIds: [NSNumber], responseIq: XMPPIQ, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo publishedDeviceIds | \(deviceIds)", level: .verbose)
    }
    
    public func omemo(_ omemo: OMEMOModule, failedToPublishDeviceIds deviceIds: [NSNumber], errorIq: XMPPIQ?, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo failedToPublishDeviceIds | \(deviceIds)", level: .verbose)
        
        self.delegate?.omemoManager(self, errorOccurred: .encryption) // .encryptionError(error: .failedToPublishDeviceIds)
    }
    
    public func omemo(_ omemo: OMEMOModule, deviceListUpdate deviceIds: [NSNumber], from fromJID: XMPPJID, incomingElement: XMPPElement) {
        Logger.shared.log("omemo deviceListUpdate | \(fromJID) \(deviceIds)", level: .verbose)
        
        self.initDeviceIdFetchCallbacks[fromJID]?(deviceIds, true)
        self.deviceIdFetchCallbacks[fromJID]?(deviceIds, true)
        
        workQueue.async {
            if let eid = incomingElement.elementID {
                self.callAndRemoveOutstandingBundleBlock(eid, success: true)
            }
        }
    }
    
    public func omemo(_ omemo: OMEMOModule, failedToFetchDeviceIdsFor fromJID: XMPPJID, errorIq: XMPPIQ?, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo failedToFetchDeviceIdsFor fromJID | \(fromJID), error: \(errorIq?.description ?? "Some unknown error!")", level: .verbose)

        self.delegate?.omemoManager(self, errorOccurred: .encryption) // encryptionError(error: .failedToFetchDeviceIdsFor(jid: fromJID.bare))
        
        workQueue.async { [weak self] in
            self?.callAndRemoveOutstandingDeviceIdFetch(fromJID, success: false)
            
            if let eid = outgoingIq.elementID {
                self?.callAndRemoveOutstandingBundleBlock(eid, success: false)
            }
        }
    }
    
    public func omemo(_ omemo: OMEMOModule, publishedBundle bundle: OMEMOBundle, responseIq: XMPPIQ, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo publishedBundle | with deviceId \(bundle.deviceId)", level: .verbose)
    }
    
    public func omemo(_ omemo: OMEMOModule, failedToPublishBundle bundle: OMEMOBundle, errorIq: XMPPIQ?, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo failedToPublishBundle | with deviceId \(bundle.deviceId)", level: .verbose)
    }
    
    public func omemo(_ omemo: OMEMOModule, fetchedBundle bundle: OMEMOBundle, from fromJID: XMPPJID, responseIq: XMPPIQ, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo fetchedBundle | from: \(fromJID.full), with deviceId: \(bundle.deviceId)", level: .verbose)


        if isThisUsersJID(fromJID) && bundle.deviceId == self.signalManager.registrationId {
            // We fetched our own bundle
            if let thisDatabaseBundle = self.fetchMyBundle() {
                // This bundle doesn't have the correct identity key. Something has gone wrong and we should republish
                if thisDatabaseBundle.identityKey != bundle.identityKey {
                    omemo.publishBundle(thisDatabaseBundle, elementId: nil)
                }
            }
            
            return
        }

        workQueue.async { [weak self] in
            let elementId = outgoingIq.elementID
            
            if bundle.preKeys.count == 0 {
                self?.callAndRemoveOutstandingBundleBlock(elementId!, success: false)
                return
            }
            
            var result = false
            
            // Consume the incoming bundle. This goes through signal and should hit the storage delegate. So we don't need to store ourselves here.
            do {
                try self?.signalManager.consumeIncomingBundle(fromJID.bare, bundle: bundle)
                
                result = true
            } catch {
//                DDLogWarn("Error consuming incoming bundle: \(err) \(responseIq.prettyXMLString())")
            }
            
            self?.callAndRemoveOutstandingBundleBlock(elementId!, success: result)
        }
        
    }
    public func omemo(_ omemo: OMEMOModule, failedToFetchBundleForDeviceId deviceId: UInt32, from fromJID: XMPPJID, errorIq: XMPPIQ?, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo failedToFetchBundleForDeviceId | deviceId \(deviceId), from: \(fromJID)", level: .verbose)
        
        workQueue.async { [weak self] in
            let elementId = outgoingIq.elementID
            
            self?.callAndRemoveOutstandingBundleBlock(elementId!, success: false)
        }
    }
    
    public func omemo(_ omemo: OMEMOModule, removedBundleId bundleId: UInt32, responseIq: XMPPIQ, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo removedBundleId | bundleId \(bundleId)", level: .verbose)
    }
    
    public func omemo(_ omemo: OMEMOModule, failedToRemoveBundleId bundleId: UInt32, errorIq: XMPPIQ?, outgoingIq: XMPPIQ) {
        Logger.shared.log("omemo failedToRemoveBundleId | bundleId \(bundleId), error: \(String(describing: errorIq))", level: .verbose)
    }
    
    public func omemo(_ omemo: OMEMOModule, failedToRemoveDeviceIds deviceIds: [NSNumber], errorIq: XMPPIQ?, elementId: String?) {
        Logger.shared.log("omemo failedToRemoveDeviceIds | deviceIds \(deviceIds)", level: .verbose)
        
        workQueue.async { [weak self] in
            if let eid = elementId {
                self?.callAndRemoveOutstandingBundleBlock(eid, success: false)
            }
        }
    }
    
    // Omemo message is received here!
    public func omemo(_ omemo: OMEMOModule, receivedKeyData keyData: [OMEMOKeyData], iv: Data, senderDeviceId: UInt32, from fromJID: XMPPJID, payload: Data?, message: XMPPMessage) {
        Logger.shared.log("omemo receivedKeyData | keyData count \(keyData.count), from: \(fromJID)", level: .verbose)
        
        let isIncoming = !isThisUsersJID(fromJID)
        
        self.processKeyData(keyData, iv: iv, senderDeviceId: senderDeviceId, forJID: fromJID, payload: payload, delayed: message.delayedDeliveryDate, forwarded: false, isIncoming: isIncoming, message: message)
    }
    
    // Forwarded Omemo message is received here!
    public func omemo(_ omemo: OMEMOModule, receivedForwardedKeyData keyData: [OMEMOKeyData], iv: Data, senderDeviceId: UInt32, for forJID: XMPPJID,
                      payload: Data?, isIncoming: Bool, delayed: Date?, forwardedMessage: XMPPMessage, originalMessage: XMPPMessage) {
        Logger.shared.log("omemo receivedForwardedKeyData | keyData count \(keyData.count), for: \(forJID)", level: .verbose)
        
        guard let messageId = forwardedMessage.elementID else { return }
        
        self.messageStorage.checkIfMessageExists(messageId: messageId) { [weak self] exists, error in
            if !exists {
                self?.processKeyData(keyData, iv: iv, senderDeviceId: senderDeviceId, forJID: forJID, payload: payload, delayed: delayed, forwarded: true, isIncoming: isIncoming, message: forwardedMessage)
            }
        }
    }
}

extension OmemoManager: OMEMOStorageDelegate {
    func configure(withParent aParent: OMEMOModule, queue: DispatchQueue) -> Bool {
        self.omemoModule = aParent
        self.omemoModuleQueue = queue

        return true
    }
    
    func storeDeviceIds(_ deviceIds: [NSNumber], for jid: XMPPJID) {
        let isThisUserDeviceList = self.isThisUsersJID(jid)

        if isThisUserDeviceList {
            self.omemoStorageManager.storeThisUserDevices(deviceIds)
        }
//        else {
//            self.omemoStorageManager.storeContactDevices(deviceIds, contactJid: jid.bare) {
//            }
//        }
        
        callAndRemoveOutstandingDeviceIdFetch(jid, success: true)
    }
    
    func fetchDeviceIds(for jid: XMPPJID) -> [NSNumber] {
        let deviceIds = isThisUsersJID(jid) ? self.omemoStorageManager.getDevicesForThisAccount() : self.omemoStorageManager.getDevicesForJID(jid.bare)

        // Convert from devices array to NSNumber array.
        return deviceIds.map { return NSNumber(value: $0) }
    }
    
    func fetchMyBundle() -> OMEMOBundle? {
        var _bundle: OMEMOBundle? = nil
        
        do {
            _bundle = try signalManager.signalStorageManager.fetchThisUserExistingBundle()
        } catch let omemoError as OMEMOBundleError {
            switch omemoError {
            case .invalid:
//                DDLogError("Found invalid stored bundle!")
                // delete???
                break
            default:
                break
            }
        } catch {
//            DDLogError("Other error fetching bundle! \(error)")
        }
        
        let maxTries = 50
        var tries = 0
        
        while _bundle == nil && tries < maxTries {
            tries = tries + 1
            do {
                _bundle = try self.signalManager.generateOutgoingBundle(self.preKeyCount)
            } catch {
//                DDLogError("Error generating bundle! Try #\(tries)/\(maxTries) \(error)")
            }
        }
        guard let bundle = _bundle else {
//            DDLogError("Could not fetch or generate valid bundle!")
            return nil
        }
        
        var preKeys = bundle.preKeys
        
        let keysToGenerate = Int(self.preKeyCount) - preKeys.count
        
        // Check if we don't have all the prekeys we need
        if keysToGenerate > 0 {
            var start: UInt = 0
            
            if let maxId = self.signalManager.signalStorageManager.currentMaxPreKeyId() {
                start = UInt(maxId) + 1
            }
            
            if let newPreKeys = self.signalManager.generatePreKeys(start, count: UInt(keysToGenerate)) {
                let omemoKeys = OMEMOPreKey.preKeysFromSignal(newPreKeys)
                
                preKeys.append(contentsOf: omemoKeys)
            }
        }
        
        let newBundle = bundle.copyBundle(newPreKeys: preKeys)
        
        return newBundle
    }
    
    func isSessionValid(_ jid: XMPPJID, deviceId: UInt32) -> Bool {
        return self.signalManager.sessionRecordExistsForUsername(jid.bare, deviceId: Int32(deviceId))
    }
}
