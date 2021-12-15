//
//  Globals.swift
//  Object Info
//
//  Created by Leslie Helou on 1/8/21.
//  Copyright © 2021 jamf. All rights reserved.
//

import Foundation

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/ObjectInfo/")
    static var file  = "ObjectInfo.log"
    static var maxFiles = 10
    static var maxSize  = 5000000 // 5MB
    static var lookupFailed = false
    static var FailedCount  = 0
}

