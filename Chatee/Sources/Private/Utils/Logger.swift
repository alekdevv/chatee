//
//  Logger.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/8/21.
//

import Foundation

enum LogLevel {
    case verbose, info, debug, warning, error, none
    
    var prefix: String {
        switch self {
        case .verbose:  return "📗"
        case .info:     return "📔"
        case .debug:    return "📘"
        case .warning:  return "📙"
        case .error:    return "📕"
        case .none:     return ""
        }
    }
}

class Logger {
    
    static let shared = Logger()
    
    var shouldLog = false
    
    func log(_ item: Any, level: LogLevel) {
        if self.shouldLog {
            print("\(level.prefix) \(item)")
        }
    }
}
