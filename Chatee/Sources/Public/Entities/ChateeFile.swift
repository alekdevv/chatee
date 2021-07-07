//
//  ChateeFile.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public struct ChateeFile {
    let contentType: String // TODO: FileType
    let fileName: String
    let text: String?
    let data: Data
}
