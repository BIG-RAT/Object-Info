//
//  WriteToLog.swift
//  Object Info
//
//  Created by Leslie Helou on 1/8/21.
//  Copyright © 2021 jamf. All rights reserved.
//

import Foundation

struct Log {
    static var path          = "" //(NSHomeDirectory() + "/Library/Logs/")
    static var file          = "ObjectInfo.log"
    static var filePath      = ""
    static var maxFiles      = 42
    static var lookupFailed  = false
    static var FailedCount   = 0
}

class WriteToLog {
    
    static let shared = WriteToLog()
    
    let fm = FileManager()
    
    func logCleanup() {
        
        if didRun {
            var logArray: [String] = []
            var logCount: Int = 0
            do {
                let logFiles = try fm.contentsOfDirectory(atPath: Log.path)
                
                for logFile in logFiles {
                    let filePath: String = Log.path + "/" + logFile
                    logArray.append(filePath)
                }
                logArray.sort()
                logCount = logArray.count
                // remove old log files
                if logCount-1 >= Log.maxFiles {
                    for i in (0..<logCount-Log.maxFiles) {
                        message("Deleting log file: " + logArray[i] + "\n")
                        do {
                            try fm.removeItem(atPath: logArray[i])
                        }
                        catch let error as NSError {
                            message("Error deleting log file:\n    " + logArray[i] + "\n    \(error)\n")
                        }
                    }
                }
            } catch {
                print("no history")
            }
        } else {
            // delete empty log file
            do {
                try fm.removeItem(atPath: Log.filePath)
            }
            catch let error as NSError {
                message("Error deleting log file:    \n" + Log.filePath + "\n    \(error)\n")
            }
        }
    }

    func message(_ message: String) {
        let logString = "\(getCurrentTime()) \(message)\n"
        NSLog(logString)

        guard let logData = logString.data(using: .utf8) else { return }
        let logURL = URL(fileURLWithPath: Log.filePath)

        do {
            let fileHandle = try FileHandle(forWritingTo: logURL)
            defer { fileHandle.closeFile() } // Ensure file is closed
            
            fileHandle.seekToEndOfFile()
            fileHandle.write(logData)
        } catch {
//            print("[Log Error] Failed to write to log file: \(error.localizedDescription)")
            NSLog("[Log Error] Failed to write to log file: \(error.localizedDescription)")
        }
    }

}
