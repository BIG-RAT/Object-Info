//
//  Globals.swift
//  Object Info
//
//  Created by Leslie Helou on 1/8/21.
//  Copyright © 2021 jamf. All rights reserved.
//

import Foundation

struct appInfo {
    static let dict    = Bundle.main.infoDictionary!
    static let version = dict["CFBundleShortVersionString"] as! String
    static let name    = dict["CFBundleExecutable"] as! String
}

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/ObjectInfo/")
    static var file  = "ObjectInfo.log"
    static var maxFiles = 10
    static var maxSize  = 5000000 // 5MB
    static var lookupFailed = false
    static var FailedCount  = 0
}

struct JamfProServer {
    static var majorVersion = 0
    static var minorVersion = 0
    static var patchVersion = 0
    static var build        = ""
    static var authType     = "Basic"
    static var authCreds    = ""
}

struct token {
    static var refreshInterval:UInt32 = 20*60  // 20 minutes
    static var stringValue = ""
    static var expires     = ""
}
