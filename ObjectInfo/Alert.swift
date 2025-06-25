//
//  Alert.swift
//  Object Info
//
//  Created by Leslie Helou on 8/8/22
//

import Cocoa


class Alert: NSObject {
    
    static let shared = Alert()
    private override init() { }
    
    func display(header: String, message: String, secondButton: String) -> String {
        NSApplication.shared.activate(ignoringOtherApps: true)
        var selected = ""
        let dialog: NSAlert = NSAlert()
        dialog.messageText = header
        dialog.informativeText = message
        dialog.alertStyle = NSAlert.Style.warning
        let okButton = dialog.addButton(withTitle: "OK")
        if secondButton != "" {
            let otherButton = dialog.addButton(withTitle: secondButton)
            otherButton.keyEquivalent = "v"
            okButton.keyEquivalent = "\r"
        }
        
        let theButton = dialog.runModal()
        switch theButton {
        case .alertFirstButtonReturn:
            selected = "OK"
        default:
            selected = secondButton
        }
        return selected
    }
    
    @MainActor
    func versionDialog(header: String, version: String, message: String, updateAvail: Bool, manualCheck: Bool = false) async {
        NSApp.activate(ignoringOtherApps: true)
        let skipVersion = UserDefaults.standard.string(forKey: "skipVersion") ?? ""

        if !(UserDefaults.standard.bool(forKey: "skipVersionAlert") == true && skipVersion == version) || manualCheck {
            let dialog: NSAlert = NSAlert()
            dialog.messageText = header
            dialog.informativeText = message
            dialog.alertStyle = NSAlert.Style.informational

            if updateAvail {
                dialog.addButton(withTitle: "View")
                dialog.addButton(withTitle: "Later")
            } else {
                dialog.addButton(withTitle: "OK")
            }
            if !manualCheck {
                dialog.showsSuppressionButton = true
                dialog.suppressionButton?.title = "Skip this version"
            }
            
            let clicked:NSApplication.ModalResponse = dialog.runModal()
            
            if !manualCheck {
                if let supress = dialog.suppressionButton {
                    let state = supress.state
                    switch state {
                    case .on:
                        UserDefaults.standard.set(true, forKey: "skipVersionAlert")
                        UserDefaults.standard.set(version, forKey: "skipVersion")
                    default: break
                    }
                }
            }
            
            if clicked.rawValue == 1000 && updateAvail {
                if let url = URL(string: "http://github.com/BIG-RAT/Object-Info/releases/latest") {
                    NSWorkspace.shared.open(url)
                    NSApplication.shared.terminate(self)
                }
            }
        }
    }

}
