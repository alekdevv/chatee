//
//  ChateeErrorDelegate.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public protocol ChateeErrorDelegate: AnyObject {
    func chateeError(_ chatee: Chatee, type: ChateeError, message: String)
}
