//
//  ChateeLoginDelegate.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public protocol ChateeProfileDelegate: AnyObject {
    func chateeProfile(_ chatee: Chatee, didAuthenticate authenticated: Bool)
    func chateeProfile(_ chatee: Chatee, didChangeAvatar avatar: Data)
}
