//
//  ChateeMessageStatus.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public enum ChateeMessageStatus: String {
    case outgoing
    case notSent
    case sent
    case delivered
    case deliveredRead
    case receivedRead
    case receivedUnread
}
