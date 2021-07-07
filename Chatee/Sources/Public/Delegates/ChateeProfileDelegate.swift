//
//  ChateeLoginDelegate.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public protocol ChateeProfileDelegate: AnyObject {
    func chateeProfile(_ chatee: Chatee, loggedIn: Bool)
    func chateeProfileAvatarChanged(_ chatee: Chatee, new avatar: Data)
}
