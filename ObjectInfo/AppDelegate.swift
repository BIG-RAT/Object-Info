//
//  AppDelegate.swift
//  Object Info
//
//  Created by Leslie Helou on 9/18/17.
//  Copyright © 2017 jamf. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let resourceCheck   = ResourceCheck()
    
    @IBOutlet weak var resetVersionAlert_MenuItem: NSMenuItem!
    @IBAction func resetVersionAlert_Action(_ sender: Any) {
        resetVersionAlert_MenuItem.isEnabled = false
        resetVersionAlert_MenuItem.isHidden = true
        UserDefaults.standard.set(false, forKey: "skipVersionAlert")
    }
    
    @IBAction func checkForUpdates(_ sender: AnyObject) {
        Task {
            let versionCheck = await resourceCheck.version(forceCheck: true)
//            print("versionCheck: \(versionCheck)")
            if versionCheck.0 {
                await Alert.shared.versionDialog(header: "A new version (\(versionCheck.1)) is available.", version: versionCheck.1, message: "Running \(AppInfo.displayname): v\(AppInfo.version)", updateAvail: versionCheck.0, manualCheck: true)
            } else {
                await Alert.shared.versionDialog(header: "Running \(AppInfo.displayname): v\(AppInfo.version)", version: versionCheck.1, message: "No updates are currently available.", updateAvail: versionCheck.0, manualCheck: true)
            }
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let skipVersionAlert = UserDefaults.standard.bool(forKey: "skipVersionAlert")
        resetVersionAlert_MenuItem.isEnabled = skipVersionAlert
        resetVersionAlert_MenuItem.isHidden = !skipVersionAlert
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        WriteToLog.shared.logCleanup()
    }
    
    // quit the app if the window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }

}

