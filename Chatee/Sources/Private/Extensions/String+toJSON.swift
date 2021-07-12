//
//  String+toJSON.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/12/21.
//

import Foundation

extension String {
    
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
    
}
