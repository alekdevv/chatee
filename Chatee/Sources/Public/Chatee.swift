//
//  Chatee.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public class Chatee {
    
    public static let shared = Chatee()
    
    public weak var chateeProfileDelegate: ChateeProfileDelegate?
    public weak var chateeConversationDelegate: ChateeProfileDelegate?
    public weak var chateeContactsDelegate: ChateeProfileDelegate?
    public weak var chateeErrorDelegate: ChateeProfileDelegate?
    
    private init() {}
    
}
