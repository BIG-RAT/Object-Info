//
//  Globals.swift
//  Object Info
//
//  Created by Leslie Helou on 1/8/21.
//  Copyright © 2021 jamf. All rights reserved.
//

import Cocoa
import Foundation

public var isRunning        = false
public var stopScan         = false
public var detailQ          = OperationQueue()
public var objectByNameDict = [String:[String:AnyObject]]()
public var idNameDict       = [Int:String]()
public var didRun           = false
public var showLoginWindow  = true

public var accountDict      = [String:String]()

let defaults                = UserDefaults.standard
var saveServers            = true
var maxServerList          = 40
var appsGroupId            = "PS2F6S478M.jamfie.SharedJPMA"
let sharedDefaults         = UserDefaults(suiteName: appsGroupId)
let sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appsGroupId)
let sharedSettingsPlistUrl = (sharedContainerUrl?.appendingPathComponent("Library/Preferences/\(appsGroupId).plist"))!

// determine if we're using dark mode
var isDarkMode: Bool {
    let mode = defaults.string(forKey: "AppleInterfaceStyle")
    return mode == "Dark"
}
var defaultTextColor = isDarkMode ? NSColor.white:NSColor.black

struct AppInfo {
    static let dict        = Bundle.main.infoDictionary!
    static let version     = dict["CFBundleShortVersionString"] as! String
    static let build       = dict["CFBundleVersion"] as! String
    static let name        = dict["CFBundleExecutable"] as! String
    static let displayname = dict["CFBundleDisplayName"] as! String
    
    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(AppInfo.version)"
}

struct JamfProServer {
    static var accessToken  = ""
    static var authExpires  = 25.0
    static var currentCred  = ""
    static var tokenCreated = Date()
    static var majorVersion = 0
    static var minorVersion = 0
    static var patchVersion = 0
    static var build        = ""
    static var version      = ""
    static var authType     = "Basic"

    static var displayName  = ""
    static var username     = ""
    static var password     = ""
    static var useApiClient = 0
    static var authCreds    = ""
    static var base64Creds  = ""        // used if we want to auth with a different account
    static var validToken   = false
    static var tokenExpires = ""
    
    static var server       = ""
}

struct token {
    static var refreshInterval:UInt32 = UInt32(20*0.8)  // 20 minutes * 0.8
    static var expires     = ""
    static var isValid     = false
    static var created:Date?
}

let endpointDefDict = ["policy":"policies",
                       "network_segment":"network segments",
                       "package":"packages",
                       "script":"scripts",
                       "computer_group":"computer groups",
                       "macapplication":"mac applications",
                       "mobiledeviceapplication":"mobile device applications",
                       "mobile_device_group":"mobile device groups",
                       "os_x_configuration_profile":"macOS config profiles",
                       "configuration_profile":"iOS config profiles",
                       "cp_all_macOS":"macOS config profiles",
                       "cp_all_iOS":"iOS config profiles",
                       "computer_extension_attribute":"macOS extension attribtes",
                       "mobiledeviceconfigurationprofile":"mobile device configuration profiles",
                       "mobile_device_extension_attribute":"iOS extension attribtes",
                       "advanced_computer_search":"advanced computer searches",
                       "advanced_mobile_device_search":"advanced mobile device searches"]

var endpointDict = ["recon":            ["policies","policies","policy"],
                    "apps_macOS":       ["macapplications","mac_applications","mac_application"],
                    "apps_iOS":         ["mobiledeviceapplications","mobile_device_applications","mobile_device_application"],
                    "Network Segments": ["networksegments","network_segments","network_segment"],
                    "Packages":         ["packages","packages","package"],
                    "Policies-all":     ["policies","policies","policies"],
                    "Printers":         ["printers","printers","printer"],
                    "Scripts":          ["scripts","scripts","script"],
                    "scg":              ["computergroups","computer_groups","computer_group"],
                    "sdg":              ["mobiledevicegroups","mobile_device_groups","mobile_device_group"],
                    "mac_cp":           ["osxconfigurationprofiles","os_x_configuration_profiles","os_x_configuration_profile"],
                    "cp_all_macOS":     ["osxconfigurationprofiles","os_x_configuration_profiles","os_x_configuration_profile"],
                    "ios_cp":           ["mobiledeviceconfigurationprofiles","configuration_profiles","configuration_profile"],
                    "cp_all_iOS":       ["mobiledeviceconfigurationprofiles","configuration_profiles","configuration_profile"],
                    "cea":              ["computerextensionattributes","computer_extension_attributes","computer_extension_attribute"],
                    "mdea":             ["mobiledeviceextensionattributes","mobile_device_extension_attributes","mobile_device_extension_attribute"],
                    "acs":              ["advancedcomputersearches","advanced_computer_searches","advanced_computer_search"],
                    "ams":              ["advancedmobiledevicesearches","advanced_mobile_device_searches","advanced_mobile_device_search"]]

var headersDict = ["recon":             ["Policy","Trigger","Frequency","Scope"],
                   "Network Segments":  ["Segment Name","Start Address","End Address","Default Share","URL"],
                   "apps_iOS":          ["App Name", "Managed Dist.","Scope","Limitations","Exclusions"],
                   "apps_macOS":        ["App Name", "Managed Dist.","Scope","Limitations","Exclusions"],
                   "cp_all_iOS":        ["Profile Name", "Payloads","Scope","Limitations","Exclusions"],
                   "cp_all_macOS":      ["Profile Name", "Payloads","Scope","Limitations","Exclusions","PreStage"],
                   "Packages":          ["Package Name","Policy","Trigger","Frequency","PreStage"],
                   "Policies-all":      ["Policy Name","Payloads","Trigger","Frequency","Scope","Limitations","Exclusions"],
                   "Printers":          ["Printer Name","Policy","Trigger","Frequency"],
                   "Scripts":           ["Script Name","Policy","Trigger","Frequency"],
                   "scg":               ["Group Name","Policy","Profile","Trigger","Frequency","App"],
                   "sdg":               ["Group Name","Profile","App"],
                   "mac_cp":            ["Payload Type","Profile Name","Scope","Limitations","Exclusions"],
                   "cea":               ["Extension Attribute","Smart Group","Advanced Search","EA Type"]]

let configProfilePayloads = ["Passcode":["<string>com.apple.mobiledevice.passwordpolicy</string>"],
                            "Wi-Fi": ["<key>HIDDEN_NETWORK</key>"],
                            "AirPlay":["<key>PayloadDisplayName</key><string>AirPlay Payload</string>","<key>PayloadType</key><string>com.apple.airplay</string>"],
                            "Notifications":["<key>PayloadDisplayName</key><string>Notifications Payload</string>","<key>PayloadType</key><string>com.apple.notificationsettings</string>"],
                            "Single Sign-on Extensions":["<key>PayloadDisplayName</key><string>Single Sign-On Extensions Payload</string>","<key>PayloadType</key><string>com.apple.extensiblesso</string>"],
                            "VPN":["<key>VPNType</key>"],
                            "Certificates":["<key>PayloadCertificateFileName</key>","<key>PayloadType</key><string>com.apple.security.","<key>AllowAllAppsAccess</key>"],
                            "DNS Settings":["<key>PayloadDisplayName</key><string>DNS Settings</string>","<string>com.apple.dnsSettings.managed</string>"],
                            "DNS Proxy":["<key>PayloadDisplayName</key><string>DNS Proxy</string>","<string>com.apple.dnsProxy.managed</string>"],
                            "Mail":["<key>PayloadDisplayName</key><string>com.apple.mail.managed</string>","<key>PayloadType</key><string>com.apple.mail.managed</string>"],
                            "Exchange ActiveSync":["<key>PayloadDisplayName</key><string>Exchange ActiveSync</string>","<key>PayloadType</key><string>com.apple.eas.account</string>"],
                            "Content Caching":["<string>com.apple.AssetCache.managed</string>"],
                            "Google Account":["<key>PayloadDisplayName</key><string>com.apple.google-oauth</string>","<key>PayloadType</key><string>com.apple.google-oauth</string>"],
                             "LDAP":["<key>PayloadDisplayName</key><string>com.apple.ldap.account</string>","<key>PayloadType</key><string>com.apple.ldap.account</string>"],
                             "Calendar":["<key>PayloadDisplayName</key><string>CalDAV</string>","<key>PayloadType</key><string>com.apple.caldav.account</string>"],
                             "Contacts":["<key>PayloadDisplayName</key><string>com.apple.carddav.account</string>","<key>PayloadType</key><string>com.apple.carddav.account</string>"],
                             "Subscribed Calendars":["<key>PayloadDisplayName</key><string>com.apple.subscribedcalendar.account</string>","<key>PayloadType</key><string>com.apple.subscribedcalendar.account</string>"],
                             "Web Clips":["<key>PayloadDisplayName</key><string>Web Clip</string>","<key>PayloadType</key><string>com.apple.webClip.managed</string>"],
                             "Skip Setup Items":["<key>PayloadDisplayName</key><string>Setup Assistant</string>","<key>PayloadType</key><string>com.apple.SetupAssistant.managed</string>"],
                             "Home Screen Layout":["<key>PayloadDisplayName</key><string>com.apple.homescreenlayout</string>","<key>PayloadType</key><string>com.apple.homescreenlayout</string>"],
                             "Domains":["<key>PayloadDisplayName</key><string>com.apple.domains</string>","<key>PayloadType</key><string>com.apple.domains</string>"],
                             "APN":["<key>PayloadDisplayName</key><string>com.apple.apn.managed</string>","<key>PayloadType</key><string>com.apple.apn.managed</string>"],
                             "Cellular":["<key>PayloadDisplayName</key><string>com.apple.cellular</string>","<key>PayloadType</key><string>com.apple.cellular</string>"],
                             "Single App Mode":["<key>PayloadDisplayName</key><string>com.apple.app.lock</string>","<key>PayloadType</key><string>com.apple.app.lock</string>"],
                             "Global HTTP Proxy":["<key>PayloadDisplayName</key><string>com.apple.proxy.http.global</string>","<key>PayloadType</key><string>com.apple.proxy.http.global</string>"],
                             "Single Sign-on":["<key>PayloadDisplayName</key><string>com.apple.sso</string>","<key>PayloadType</key><string>com.apple.sso</string>"],
                             "Font-ios":["<key>PayloadDisplayName</key><string>com.apple.font</string>","<key>PayloadType</key><string>com.apple.font</string>"],
                             "AirPlay Security":["<key>PayloadDisplayName</key><string>com.apple.airplay.security</string>","<key>PayloadType</key><string>com.apple.airplay.security</string>"],
                             "Conference Room Display":["<key>PayloadDisplayName</key><string>com.apple.conferenceroomdisplay</string>","<key>PayloadType</key><string>com.apple.conferenceroomdisplay</string>"],
                             "AirPrint":["<key>PayloadDisplayName</key><string>com.apple.airprint</string>","<key>PayloadType</key><string>com.apple.airprint</string>"],
                             "Content Filter-ios":["<key>PayloadDisplayName</key><string>com.apple.webcontent-filter</string>","<key>PayloadType</key><string>com.apple.webcontent-filter</string>"],
                             "Lock Screen Message":["<key>PayloadDisplayName</key><string>Lock Screen Message Payload</string>","<key>PayloadType</key><string>com.apple.shareddeviceconfiguration</string>"],
                             "Network Usage Rules":["<key>PayloadDisplayName</key><string>com.apple.networkusagerules</string>","<key>PayloadType</key><string>com.apple.networkusagerules</string>"],
                             "TV Remote":["<key>PayloadDisplayName</key><string>Tv Remote Payload</string>","<key>PayloadType</key><string>com.apple.tvremote</string>"],
                             "Certificate Transparency":["<string>com.apple.security.certificatetransparency</string>"],
                             "Font-mac":["<key>PayloadDisplayName</key><string>Font</string>","<key>PayloadType</key><string>com.apple.font</string>"],
                             "SCEP":["<string>com.apple.security.scep</string>"],
                             "Directory":["<string>com.apple.DirectoryService.managed</string>"],
                             "Kernel Extensions":["<string>com.apple.syspolicy.kernel-extension-policy</string>"],
                             "Software Update":["<string>com.apple.SoftwareUpdate</string>"],
                             "Restrictions-ios":["<key>PayloadDisplayName</key><string>Restrictions Payload</string>","<key>PayloadType</key><string>com.apple."],
                             "Restrictions-mac": ["<key>PayloadDisplayName</key><string>MCX</string>","<key>PayloadType</key><string>com.apple.MCX</string>","<key>PayloadType</key><string>com.apple .applicationaccess.new</string>"],
                             "Login Items":["<string>com.apple.loginitems.managed</string>"],
                             "Login Window":["<string>com.apple.MCX</string>","<string>Login Window:  Global Preferences</string>","<string>Login Window</string>"],
                             "Dock":["<string>com.apple.dock</string>","<string>Dock</string>"],
                             "Mobility":["<key>cachedaccounts.WarnOnCreate.allowNever</key>","<string>com.apple.homeSync</string>"],
                             "Printing":["<string>com.apple.mcxprinting</string>"],
                             "Parental Controls":["<key>PayloadDisplayName</key><string>Parental Controls</string>"],
                             "Security and Privacy-General-ChangePassword":["<key>PayloadDisplayName</key><string>PreferenceSecurity</string>","<key>PayloadType</key><string>com.apple.preference.security</string>","<key>dontAllowPasswordResetUI</key>"],
                             "Security and Privacy-General-ScreenSaver":["<key>PayloadDisplayName</key><string>PreferenceSecurity</string>","<key>PayloadType</key><string>com.apple.screensaver</string>"],
                             "Security and Privacy-General-SetLockMessage":["<key>PayloadDisplayName</key><string>PreferenceSecurity</string>","<key>PayloadType</key><string>com.apple.preference.security</string>","<key>dontAllowLockMessageUI</key>"],
                             "Security and Privacy-General-SendData":["<key>PayloadDisplayName</key><string>SubmitDiagInfo</string>","<key>PayloadType</key><string>com.apple.SubmitDiagInfo</string>"],
                             "Security and Privacy-General-Unlock":["<key>PayloadDisplayName</key><string>Restrictions</string>","<key>PayloadType</key><string>com.apple.applicationaccess</string>","<key>allowAutoUnlock</key>"],
                             "Security and Privacy-General-RPtUS":["<key>PayloadDisplayName</key><string>ScreenSaver</string>","<key>PayloadType</key><string>com.apple.screensaver</string>","<key>askForPassword</key>","<key>askForPasswordDelay</key>"],
                             "Security and Privacy-General-Gatekeeper":["<key>PayloadDisplayName</key><string>SystemPolicyControl</string>","<key>PayloadType</key><string>com.apple.systempolicy.control</string>","<key>AllowIdentifiedDevelopers</key>","<key>EnableAssessment</key>"],
                             "Security and Privacy-General-GatekeeperOverride":["<key>PayloadDisplayName</key><string>SystemPolicyManaged</string>","<key>PayloadType</key><string>com.apple.systempolicy.managed</string>","<key>DisableOverride</key>"],
                             "Security and Privacy-General-XProtect":["<key>PayloadDisplayName</key><string>SystemPolicyControl</string>","<key>PayloadType</key><string>com.apple.systempolicy.control</string>","<key>EnableXProtectMalwareUpload</key>"],
                             "Security and Privacy-Firewall":["<key>PayloadType</key><string>com.apple.security.firewall</string>"],
                             "Security and Privacy-FileVault":["<key>PayloadType</key><string>com.apple.MCX.FileVault2</string>"],
                             "Security and Privacy-FileVault-KeyEscrow":["<key>PayloadDisplayName</key><string>FileVault Recovery Key Escrow</string>","<key>PayloadType</key><string>com.apple.security.FDERecoveryKeyEscrow</string>"],
                             "Security and Privacy-FileVault-DenyOff":["<key>PayloadDisplayName</key><string>MCX</string>","<key>PayloadType</key><string>com.apple.MCX</string>","<key>dontAllowFDEDisable</key>"],
                             "PPPC":["<key>PayloadType</key><string>com.apple.TCC.configuration-profile-policy</string>"],
                             "AD Certificate":["<string>com.apple.ADCertificate.managed</string>","<key>PayloadDisplayName</key><string>AD Certificate</string>"],
                             "Energy": ["<key>PayloadDisplayName</key><string>MCX</string>","<key>com.apple.EnergySaver.desktop.ACPower</key>","<key>com.apple.EnergySaver.portable .ACPower-ProfileNumber</key>"],
                             "App & Custom Settings":["<key>PayloadDisplayName</key><string>Custom  Settings</string>","<key>PayloadType</key><string>com.apple.ManagedClient.preferences</string>"],
                             "Identification": ["<key>PayloadDisplayName</key><string>Identity</string>","<key>PayloadType</key><string>com.apple.configurationprofile.identification</string>"],
                             "Time Machine":["<key>PayloadDisplayName</key><string>Time Machine</string>","<key>PayloadType</key><string>com.apple.MCX.TimeMachine</string>"],
                             "Finder":["<key>PayloadType</key><string>com.apple.finder</string>","<key>InterfaceLevel</key><string>Full</string>"],
                             "Accessibility":["<key>PayloadDisplayName</key><string>Accessibility</string>","<key>PayloadType</key><string>com.apple.universalaccess</string>"],
                             "Proxies":["<key>PayloadDisplayName</key><string>Proxies</string>","<key>PayloadType</key><string>com.apple.SystemConfiguration</string>"],
                             "App-To-Per-App VPN Mapping":["<key>PayloadDisplayName</key><string>App to Per-App VPN Mapping  Payload</string>","<key>PayloadType</key><string>com.apple.vpn.managed.appmapping</string>"],
                             "Xsan":["<key>PayloadDisplayName</key><string>Xsan</string>","<key>PayloadType</key><string>com.apple.xsan</string>"],
                             "Smart Card":["<key>PayloadDisplayName</key><string>SmartCard</string>","<key>PayloadType</key><string>com.apple.security.smartcard</string>"],
                             "Migration":["<key>PayloadDisplayName</key><string>System Migration</string>","<key>PayloadType</key><string>com.apple.systemmigration</string>"],
                             "Approved Kernel Extensions":["<key>PayloadDisplayName</key><string>Approved Kernel  Extensions</string>","<key>PayloadType</key><string>com.apple.syspolicy.kernel-extension-policy</string>"],
                             "Associated Domains":["<key>PayloadDisplayName</key><string>Associated Domains</string>","<key>PayloadType</key><string>com.apple.associated-domains</string>"],
                             "Extensions":["<key>PayloadDisplayName</key><string>Extensions</string>","<key>PayloadType</key><string>com.apple.NSExtension</string>"],
                             "System Extensions":["<key>PayloadDisplayName</key><string>System  Extensions</string>","<key>PayloadType</key><string>com.apple.system-extension-policy</string>"],
                             "Content Filter-mac":["<key>PayloadDisplayName</key><string>Web Content Filter Payload</string>"]]


// func cleanup - start
func cleanup() {
    var logArray: [String] = []
    var logCount: Int = 0
    do {
        let logFiles = try FileManager.default.contentsOfDirectory(atPath: Log.path)
        
        for logFile in logFiles {
            let filePath: String = Log.path + logFile
//            print("filePath: \(filePath)")
            logArray.append(filePath)
        }
        logArray.sort()
        logCount = logArray.count
        if didRun {
            // remove old history files
            if logCount > Log.maxFiles {
                for i in (0..<logCount-Log.maxFiles) {                    
                    do {
                        try FileManager.default.removeItem(atPath: logArray[i])
                    }
                    catch let error as NSError {
                        WriteToLog.shared.message("Error deleting log file:\n    " + logArray[i] + "\n    \(error)")
                    }
                }
            }
        } else {
            // delete empty log file
            if logCount > 0 {
                
            }
            do {
                try FileManager.default.removeItem(atPath: logArray[0])
            }
            catch let error as NSError {
                WriteToLog.shared.message("Error deleting log file:    \n" + Log.path + logArray[0] + "    \(error)")
            }
        }
    } catch {
        WriteToLog.shared.message("no log files found")
    }
}
// get current time
public func getCurrentTime() -> String {
    let current = Date()
    let localCalendar = Calendar.current
    let dateObjects: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let dateTime = localCalendar.dateComponents(dateObjects, from: current)
    let currentMonth  = leadingZero(value: dateTime.month!)
    let currentDay    = leadingZero(value: dateTime.day!)
    let currentHour   = leadingZero(value: dateTime.hour!)
    let currentMinute = leadingZero(value: dateTime.minute!)
    let currentSecond = leadingZero(value: dateTime.second!)
    let stringDate = "\(dateTime.year!)\(currentMonth)\(currentDay)_\(currentHour)\(currentMinute)\(currentSecond)"
    return stringDate
}
// add leading zero to single digit integers
public func leadingZero(value: Int) -> String {
    var formattedValue = ""
    if value < 10 {
        formattedValue = "0\(value)"
    } else {
        formattedValue = "\(value)"
    }
    return formattedValue
}
public func policyPayloads(xml: [String:Any]) -> [String] {
    var payloadList = [String]()
//    print("[policyPayloads] xml: \(xml)")
    let policyPayloadList = [ "package_configuration":"packages", "scripts":"scripts", "printers":"printers", "dock_items":"dock items", "account_maintenance":"accounts", "maintenance":"maintenance", "files_processes":"files & processes" , "disk_encryption":"disk encryption", "reboot":"restart"]
    for (payload,payloadType) in policyPayloadList {
        switch payload {
        case "account_maintenance":
            let account_maintenance = xml[payload] as! [String: AnyObject]
            for accountOption in ["accounts","directory_bindings","management_account","open_firmware_efi_password"] {
                switch accountOption {
                case "account", "directory_bindings":
                    let itemCount = (account_maintenance[accountOption] as! [Any]).count
                    if itemCount > 0 {
                        payloadList.append(payloadType)
                        break
                    }
                case "management_account":
                    let management_account = account_maintenance[accountOption] as! [String:Any]
                    if management_account["action"] as! String != "doNotChange" {
                        payloadList.append(payloadType)
                        break
                    }
                case "open_firmware_efi_password":
                    let management_account = account_maintenance[accountOption] as! [String:String]
                    if !(management_account["of_mode"] == "none" && management_account["of_password_sha256"] == "") {
                        payloadList.append(payloadType)
                        break
                    }
                default:
                    continue
                }
            }
        case  "maintenance":
            let maintenance = xml[payload] as! [String: Bool]
            for theTask in ["recon","reset_name","install_all_cached_packages","heal","prebindings","permissions","byhost","system_cache","user_cache","verify"] {
                if maintenance[theTask] ?? false {
                    payloadList.append(payloadType)
                    break
                }
            }
        case "dock_items", "scripts", "printers":
            let itemCount = (payload == "printers") ? (xml[payload] as! [Any]).count-1:(xml[payload] as! [Any]).count
            if itemCount > 0 {
                payloadList.append(payloadType)
            }
        case "files_processes":
            let file_processes = xml[payload] as! [String: AnyObject]
            for theOption in ["search_by_path","delete_file","locate_file","update_locate_database","spotlight_search","search_for_process","kill_process","run_command"] {
                switch theOption {
                case "delete_file", "update_locate_database","kill_process":
                    if file_processes[theOption] as! Bool {
                        payloadList.append(payloadType)
                        break
                    }
                default:
                    if file_processes[theOption] as! String != "" {
                        payloadList.append(payloadType)
                        break
                    }
                }
                
            }
        case "disk_encryption":
            let dePayload = xml[payload] as! [String:Any]
            if dePayload["action"] as! String != "none" {
                payloadList.append(payloadType)
            }
        case "reboot":
            let restartPayload = xml[payload] as! [String:Any]
            let user_logged_in = restartPayload["user_logged_in"] as! String
            let no_user_logged_in = restartPayload["no_user_logged_in"] as! String
            if !(user_logged_in == "Do not restart" && no_user_logged_in == "Do not restart") {
                payloadList.append(payloadType)
            }
        default:
            let thePayload2 = xml[payload] as! [String:AnyObject]
            let size = ((payload == "scripts") ? thePayload2.count:thePayload2["packages"]?.count)!
            if size > 0 {
                payloadList.append(payloadType)
            }
        }
    }
    return payloadList.sorted()
}
public func profilePayloads(payloadXML: String, platform: String) -> [String] {
    var configuredPayloads = [String]()
    var finalPayloadType   = ""
    for (payloadType, searchStrings) in configProfilePayloads {
        if searchResult(payload: payloadXML, critereaArray: searchStrings) {
            switch platform {
            case "cp_all_iOS":
                switch payloadType {
                case "Restrictions-ios","Font-ios","Content Filter-ios":
                    finalPayloadType = payloadType.replacingOccurrences(of: "-ios", with: "")
                default:
                    finalPayloadType = payloadType
                }
            case "cp_all_macOS":
                switch payloadType {
                case "Restrictions-mac","Font-mac","Content Filter-mac":
                    finalPayloadType = payloadType.replacingOccurrences(of: "-mac", with: "")
                case "Wi-Fi":
                    finalPayloadType = "Network"
                case "Security and Privacy-General-ChangePassword","Security and Privacy-General-ScreenSaver","Security and Privacy-General-SetLockMessage","Security and Privacy-General-SendData","Security and Privacy-General-Unlock","Security and Privacy-General-RPtUS","Security and Privacy-General-Gatekeeper","Security and Privacy-Firewall","Security and Privacy-FileVault","Security and Privacy-FileVault-KeyEscrow","Security and Privacy-FileVault-DenyOff":
                    finalPayloadType = "Security and Privacy"
                default:
                    finalPayloadType = payloadType
                }
            default:
                break
            }
            if configuredPayloads.firstIndex(of: finalPayloadType) == nil {
                configuredPayloads.append(finalPayloadType)
            }
        }
    }
    return configuredPayloads
}
public func searchResult(payload: String, critereaArray: [String]) -> Bool {
    print("\n[searchResult] payload: \(payload)\ncriteriaArray: \(critereaArray)\n")
    
    switch critereaArray {
    case ["General"]:
        for payloadCritereaArray in [configProfilePayloads["Security and Privacy-General-ChangePassword"], configProfilePayloads["Security and Privacy-General-ScreenSaver"], configProfilePayloads["Security and Privacy-General-SetLockMessage"], configProfilePayloads["Security and Privacy-General-SendData"], configProfilePayloads["Security and Privacy-General-Unlock"], configProfilePayloads["Security and Privacy-General-RPtUS"], configProfilePayloads["Security and Privacy-General-Gatekeeper"]] {
            print("\n[searchResult-FileVault] payloadCritereaArray: \(payloadCritereaArray ?? [])")
            var match = true
            for criterea in payloadCritereaArray ?? [] {
                print("[searchResult-FileVault] check criteria: \(criterea)\n")
                if payload.range(of:criterea, options: .regularExpression) == nil {
                    print("\n[searchResult-FileVault] criteria not found: \(criterea)\n")
                    match = false
                }
                if match { return true }
            }
        }
        return false
    case ["FileVault"]:
        for payloadCritereaArray in [configProfilePayloads["Security and Privacy-FileVault"], configProfilePayloads["Security and Privacy-FileVault-KeyEscrow"], configProfilePayloads["Security and Privacy-FileVault-DenyOff"]] {
            print("\n[searchResult-FileVault] payloadCritereaArray: \(payloadCritereaArray ?? [])")
            var match = true
            for criterea in payloadCritereaArray ?? [] {
                print("[searchResult-FileVault] check criteria: \(criterea)\n")
                if payload.range(of:criterea, options: .regularExpression) == nil {
                    print("\n[searchResult-FileVault] criteria not found: \(criterea)\n")
                    match = false
                }
            }
            if match { return true }
        }
        return false

    default:
        for criterea in critereaArray {
            if payload.range(of:criterea, options: .regularExpression) == nil {
                print("\n[searchResult] criteria not found: \(criterea)\n")
                return false
            }
        }
        return true
    }
    
//    if critereaArray == ["FileVault"] {
//        for payloadCritereaArray in [configProfilePayloads["Security and Privacy-FileVault"], configProfilePayloads["Security and Privacy-FileVault-KeyEscrow"], configProfilePayloads["Security and Privacy-FileVault-DenyOff"]] {
//            print("\n[searchResult-FileVault] payloadCritereaArray: \(payloadCritereaArray ?? [])")
//            var match = true
//            for criterea in payloadCritereaArray ?? [] {
//                print("[searchResult-FileVault] check criteria: \(criterea)\n")
//                if payload.range(of:criterea, options: .regularExpression) == nil {
//                    print("\n[searchResult-FileVault] criteria not found: \(criterea)\n")
//                    match = false
////                    break
//                }
//                if match { return true }
//            }
//        }
//        return false
//    } else {
//        for criterea in critereaArray {
//            if payload.range(of:criterea, options: .regularExpression) == nil {
//                print("\n[searchResult] criteria not found: \(criterea)\n")
//                return false
//            }
//        }
//        return true
//    }
}

func tagValue(xmlString:String, xmlTag:String) -> String {
    var rawValue = ""
    if let start = xmlString.range(of: "<\(xmlTag)>"),
        let end  = xmlString.range(of: "</\(xmlTag)", range: start.upperBound..<xmlString.endIndex) {
        rawValue.append(String(xmlString[start.upperBound..<end.lowerBound]))
    } else {
        WriteToLog.shared.message("[tagValue] invalid input for tagValue function or tag not found.")
        WriteToLog.shared.message("\t[tagValue] tag: \(xmlTag)")
        WriteToLog.shared.message("\t[tagValue] xml: \(xmlString)")
    }
    return rawValue
}

public func timeDiff(startTime: Date) -> (Int, Int, Int, Double) {
    let endTime = Date()
//                    let components = Calendar.current.dateComponents([.second, .nanosecond], from: startTime, to: endTime)
//                    let timeDifference = Double(components.second!) + Double(components.nanosecond!)/1000000000
//                    WriteToLog.shared.message("[ViewController.download] time difference: \(timeDifference) seconds")
    let components = Calendar.current.dateComponents([
        .hour, .minute, .second, .nanosecond], from: startTime, to: endTime)
    var diffInSeconds = Double(components.hour!)*3600 + Double(components.minute!)*60 + Double(components.second!) + Double(components.nanosecond!)/1000000000
    diffInSeconds = Double(round(diffInSeconds * 1000) / 1000)
//    let timeDifference = Int(components.second!) //+ Double(components.nanosecond!)/1000000000
//    let (h,r) = timeDifference.quotientAndRemainder(dividingBy: 3600)
//    let (m,s) = r.quotientAndRemainder(dividingBy: 60)
//    WriteToLog.shared.message("[ViewController.download] download time: \(h):\(m):\(s) (h:m:s)")
    return (Int(components.hour!), Int(components.minute!), Int(components.second!), diffInSeconds)
}

extension String {
    var fqdnFromUrl: String {
        get {
            var fqdn = ""
            let nameArray = self.components(separatedBy: "/")
            if nameArray.count > 2 {
                fqdn = nameArray[2]
            } else {
                fqdn =  self
            }
            if fqdn.contains(":") {
                let fqdnArray = fqdn.components(separatedBy: ":")
                fqdn = fqdnArray[0]
            }
            return fqdn
        }
    }
    var trimTrailingSlash: String {
        get {
            var newString = self
                
            while newString.last == "/" {
                newString = "\(newString.dropLast(1))"
            }
            return newString
        }
    }
}
