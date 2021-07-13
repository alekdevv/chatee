//
//  FileTransferManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/13/21.
//

import Foundation
import XMPPFramework
import OTRKit

private struct HTTPServer {
    /// Service jid for upload service
    let jid: XMPPJID
    
    /// Max upload size in bytes
    let maxSize: UInt
}

private enum URLScheme: String {
    case https = "https"
    case aesgcm = "aesgcm"
    
    static let downloadableSchemes: [URLScheme] = [.https, .aesgcm]
}

private typealias HTTPHeaders = [String: String]

private let workQueue = DispatchQueue(label: "FileUploadManager-WorkQueue")
private let callbackQueue = DispatchQueue.main // To be considered if there is a better way to handle callbacks.

// Consider using delegate instead of escaping closures.
class FileTransferManager: NSObject {
    
    private let xmppStream: XMPPStream
    private let hostName: String
    
    private let httpFileUpload: XMPPHTTPFileUpload
    private let sessionManager = URLSession.shared
    private var servers: [HTTPServer] = []
    

    init(xmppStream: XMPPStream, hostName: String) {
        self.xmppStream = xmppStream
        self.hostName = hostName
        self.httpFileUpload = XMPPHTTPFileUpload()
        
        super.init()
        
        self.httpFileUpload.activate(xmppStream)
        
        self.servers.append(HTTPServer(jid: XMPPJID(string: "upload.\(hostName)")!, maxSize: 104857600))
    }
    
    // TODO: contentType
    func send(data: Data, contentType: String, shouldEncrypt: Bool = true, completion: @escaping (URL?, FileTransferError?) -> Void) {
        let filename = "\(UUID().uuidString).png"
        
        let file = ChateeFile(contentType: contentType, fileName: filename, text: nil, data: data)
        
        upload(file: file, shouldEncrypt: shouldEncrypt, completion: completion)
    }
    
    private func upload(file: ChateeFile, shouldEncrypt: Bool, completion: @escaping (URL?, FileTransferError?) -> Void) {
        Logger.shared.log("upload called", level: .verbose)

        var outKeyIv: Data? = nil
        var outData = file.data
                
        var contentType = "image/jpeg"
        
        workQueue.async {
            if shouldEncrypt {
                guard let key = KeyGenerator.randomData(withLength: 32), let iv = SignalHelper.generateIV(withLength: 12) else {
                    callbackQueue.async {
                        completion(nil, FileTransferError.failedToGenerateKey)
                    }
                    
                    return
                }
                
                outKeyIv = iv + key
                
                Logger.shared.log("Encryption (iv + key) = \(outKeyIv ?? Data())", level: .verbose)
                
                do {
                    let crypted = try SignalHelper.encryptData(file.data, key: key, iv: iv)
                    
                    outData = crypted.data + crypted.authTag
                    
                    contentType = "application/octet-stream"
                } catch {
                    outData = Data()
                    
                    callbackQueue.async {
                        completion(nil, FileTransferError.failedToEncryptData)
                    }
                    
                    return
                }
            }
            
            guard let service = self.servers.first else {
                callbackQueue.async {
                    completion(nil, FileTransferError.noServer)
                }

                return
            }
            
            self.httpFileUpload.requestSlot(fromService: service.jid, filename: file.fileName, size: UInt(outData.count), contentType: contentType) {
                [unowned self] slot, iq, error in
                
                Logger.shared.log("requestSlot callback response: \(String(describing: iq))", level: .verbose)

                guard let slot = slot else {
                    callbackQueue.async {
                        completion(nil, FileTransferError.failedToGetSlot)
                    }

                    return
                }

                var forwardedHeaders = self.getHeaders(slot: slot)
                forwardedHeaders["Content-Type"] = file.contentType
                forwardedHeaders["Content-Length"] = "\(UInt(outData.count))"

                self.httpUpload(data: outData, outKeyIv: outKeyIv, slot: slot, headers: forwardedHeaders, completion: completion)
            }
        }
    }
        
    private func getHeaders( slot: XMPPSlot) -> HTTPHeaders {
        let allowedHeaders = ["authorization", "cookie", "expires"]
        
        var headers: HTTPHeaders = [:]
        
        for (headerName, headerValue) in slot.putHeaders {
            let name = headerName.replacingOccurrences(of: "\n", with: "").lowercased()
            
            if allowedHeaders.contains(name) {
                headers[name] = headerValue.replacingOccurrences(of: "\n", with: "")
            }
        }
        
        return headers
    }
    
    private func httpUpload(data: Data, outKeyIv: Data?, slot: XMPPSlot, httpMethod: String = "PUT", headers: HTTPHeaders, completion: @escaping (URL?, FileTransferError?) -> Void) {
        var urlRequest = URLRequest(url: slot.putURL)
        urlRequest.httpMethod = httpMethod
        urlRequest.allHTTPHeaderFields = headers
        
        let task = self.sessionManager.uploadTask(with: urlRequest, from: data) { data, response, error in
            guard error == nil else {
                return
            }
            
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                // Bad status code, unsuccessful upload
                return
            }
            
            if let outKeyIv = outKeyIv {
                // If there's a AES-GCM key, we gotta put it in the url
                // and change the scheme to `aesgcm`
                if var components = URLComponents(url: slot.getURL, resolvingAgainstBaseURL: true) {
                    components.scheme = URLScheme.aesgcm.rawValue
                    components.fragment = outKeyIv.hexString()
                    
                    if let outURL = components.url {
                        completion(outURL, nil)
                    } else {
                        completion(nil, FileTransferError.failedToFormatUrl)
                    }
                } else {
                    completion(nil, FileTransferError.failedToFormatUrl)
                }
            } else {
                // The plaintext case
                completion(slot.getURL, nil)
            }
        }
        
        task.resume()
    }
        
    func download(url: URL, completion: @escaping (URL?, Error?) -> Void) {
                
        let task = self.sessionManager.dataTask(with: url.httpFromAes) { [weak self] data, response, error in
            if var data = data, let url = response?.url {
                let authTagSize = 16 // i'm not sure if this can be assumed, but how else would we know the size?
                if let (key, iv) = url.aesGcmKey, data.count > authTagSize {
                    
                    let cryptedData = data.subdata(in: 0..<data.count - authTagSize)
                    let authTag = data.subdata(in: data.count - authTagSize..<data.count)
                    let cryptoData = OTRCryptoData(data: cryptedData, authTag: authTag)
                    
                    do {
                        data = try OTRCryptoUtility.decryptAESGCMData(cryptoData, key: key, iv: iv)
                    } catch let error {
                        Logger.shared.log("Decryption unsuccessful \(error)", level: .error)
                    }
                    
                    Logger.shared.log("Decryption successful", level: .verbose)
                    Logger.shared.log("Data: \(data)", level: .verbose)
                    
                    let fileUrl = self?.saveFile(data: data)
                    
                    completion(fileUrl, nil)
                }

            }
        }

        task.resume()
    }
    
    private func saveFile(data: Data) -> URL? {
        guard let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return nil
        }
        
        let fileUrl = documentDirectory.appendingPathComponent("\(UUID().uuidString).png")
        
        do {
            try data.write(to: fileUrl)
        } catch {
        
        }
        
        return fileUrl
    }
}

private extension URL {
    
    /** URL scheme matches aesgcm:// */
    var isAesGcm: Bool {
        return scheme == URLScheme.aesgcm.rawValue
    }
    
    var httpFromAes: URL {
        let httpUrlString = self.absoluteString.replacingOccurrences(of: "aesgcm", with: "https")
        
        return URL(string: httpUrlString) ?? self
    }
    
    /** Has hex anchor with key and IV. 48 bytes w/ 16 iv + 32 key */
    var anchorData: Data? {
        guard let anchor = self.fragment else {
            return nil
        }
        
        let data = anchor.dataFromHex()
         
        return data
    }
    
    var aesGcmKey: (key: Data, iv: Data)? {
        guard let data = self.anchorData else {
            return nil
        }
       
        let ivLength: Int
        
        switch data.count {
        case 48:
            // legacy clients send 16-byte IVs
            ivLength = 16
        case 44:
            // newer clients send 12-byte IVs
            ivLength = 12
        default:
            return nil
        }
        
        let iv = data.subdata(in: 0..<ivLength)
        let key = data.subdata(in: ivLength..<data.count)
        
        return (key, iv)
    }
}

private extension Data {
    //https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift/40089462#40089462
    func hexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

private extension String {
    
    /// Create `Data` from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a `Data` object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    func dataFromHex() -> Data? {
        let characters = (self as String)
        var data = Data(capacity: characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: (self as String), options: [], range: NSMakeRange(0, characters.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else {
            return nil
        }
        
        return data
    }
}
