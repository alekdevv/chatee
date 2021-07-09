//
//  ContactsManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import XMPPFramework
import XMPPFrameworkSwift

protocol ContactsManagerDelegate: AnyObject {
    
}

class ContactsManager {
    
    weak var delegate: ContactsManagerDelegate?
    
}
