//
//  ViewController.swift
//  Object Info
//
//  Created by Leslie Helou on 8/16/17.
//  Copyright © 2017 jamf. All rights reserved.
//

import AppKit
import Cocoa
import Foundation

class EndpointData: NSObject {
    @objc dynamic var column1: String
    @objc dynamic var column2: String
    @objc dynamic var column3: String
    @objc dynamic var column4: String
    @objc dynamic var column5: String
    @objc dynamic var column6: String
    @objc dynamic var column7: String
    
    init(column1: String, column2: String, column3: String, column4: String, column5: String, column6: String, column7: String) {
        self.column1 = column1
        self.column2 = column2
        self.column3 = column3
        self.column4 = column4
        self.column5 = column5
        self.column6 = column6
        self.column7 = column7
    }
}
class getInfo: NSObject {
    @objc var id             : String
    @objc var endpointAddress: String
    @objc var theEndpoint    : String
    
    init(id: String, endpointAddress: String, theEndpoint: String) {
        self.id              = id
        self.endpointAddress = endpointAddress
        self.theEndpoint     = theEndpoint
    }
}

class ViewController: NSViewController, URLSessionDelegate, SendingLoginInfoDelegate {
    
    func sendLoginInfo(loginInfo: (String,String,String,String,Int)) {
        //create log file
        cleanup()
        
        var saveCredsState: Int?
        (JamfProServer.displayName, JamfProServer.server, JamfProServer.username, JamfProServer.password,saveCredsState) = loginInfo
        let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.password)".data(using: String.Encoding.utf8)
        JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString())!

//        WriteToLog.shared.message(stringOfText: "[ViewController] Running SYM-Helper v\(AppInfo.version)")
        view.window?.title = "Object Info Version: \(Bundle.main.infoDictionary!["CFBundleShortVersionString"] ?? "") \t\t Jamf Pro Version: \(JamfProServer.majorVersion).\(JamfProServer.minorVersion).\(JamfProServer.patchVersion)"
        currentServer = JamfProServer.server
        username      = JamfProServer.username
        password      = JamfProServer.password
        
        
        connectedTo_TextField.stringValue = "Connected to: \(JamfProServer.displayName)"
        logout_Button.isHidden = false
        
    }

    @objc dynamic var summaryArray: [EndpointData] = [EndpointData(column1: "", column2: "", column3: "", column4: "", column5: "", column6: "", column7: "")]

    // keychain access
    
//    @IBOutlet weak var saveCreds_button: NSButton!
    
    let fm = FileManager()
    var preferencesDict = [String:AnyObject]()
    let prefsPath = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Object Info/settings.plist")

    @IBOutlet weak var connectedTo_TextField: NSTextField!
    
    @IBAction func logout_Action(_ sender: NSButton) {
        logout_Button.isHidden = true
        JamfProServer.version = ""
        select_MenuItem.title = "Select"
//        endpoint_PopUpButton.select(select_MenuItem)
        summaryArray.removeAll()
        tableView.reloadData()
        progressBar.isHidden = true
        progressBar.increment(by: -100.0)
        
        performSegue(withIdentifier: "loginView", sender: nil)
    }
    @IBOutlet weak var logout_Button: NSButton!
    
    @IBOutlet weak var action_textField: NSTextField!
    
    @IBOutlet weak var get_button: NSButton!
    @IBOutlet weak var stop_button: NSButton!
    
    @IBOutlet weak var results_ScrollView: NSScrollView!
    @IBOutlet var results_TextView: NSTextView!
    
    @IBOutlet weak var details_ScrollView: NSScrollView!
    @IBOutlet var details_TextView: NSTextView!
    
    @IBOutlet weak var spinner: NSProgressIndicator!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    @IBOutlet weak var export_button: NSButton!
    
    @IBOutlet weak var tableHeader: NSTableHeaderView!
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var endpoint_PopUpButton: NSPopUpButton!
    @IBOutlet weak var select_MenuItem: NSMenuItem!
    
    var selection = [String]()
    
    var getDetailsQ          = DispatchQueue(label: "com.jamf.getDetails", qos: DispatchQoS.utility)
    var getDetailsArray      = [getInfo]()
    var pendingGetCount      = 0
    var maxConcurrentThreads = 3
    
    var currentServer           = ""
    var username                = ""
    var password                = ""
    var jamfBase64Creds         = ""
        
//    var displayResults          = ""
    var detailedResults         = ""
    var allDetailedResults      = ""
    var theScope                = ""
    var endpointType            = ""
    var menuIdentifier          = ""
    var menuTitle               = ""
    var selectedNode            = ""    // used within the policy search to distinguish between packages and scripts
    var selectedEndpoint        = ""
    var endpointXmlTag          = ""
    var singleEndpointXmlTag    = ""
    var oSelectedEndpoint       = ""    //holds original values when working with packages and scripts
    var oEndpointXmlTag         = ""    //holds original values when working with packages and scripts
    var oSingleEndpointXmlTag   = ""
    var packageScriptArray      = [String]()    // contains id and name
    var pkgScrArray             = [String]()    // contains name only
    var allPackages             = [Dictionary<String,String>]()
    var endpointUrl             = ""
    var completeCounter         = [String:Int]()
    var apiDetailCount          = [String:Int]()     // number of objects to look up
    var increment               = 0.0
    var pendingCount            = 0     // number of requests waiting for a response
    
    var payloadArray            = [String]()
    var limitationsExclusions   = [String:[String]]()
    var managedDist             = false
    var scopeableObjectsArray   = [String]()
    var exportTitleSuffix       = ""
    
    var apiQ            = OperationQueue()
//    var detailQ         = OperationQueue()
    var authQ           = DispatchQueue(label: "com.jamf.auth")
    var theGeneralQ     = DispatchQueue(label: "com.jamf.general", qos: DispatchQoS.utility) // OperationQueue()
    var theDetailQ      = DispatchQueue(label: "com.jamf.detail", qos: DispatchQoS.utility)
    var theSpinnerQ     = DispatchQueue(label: "com.jamf.spinner", qos: DispatchQoS.background)
    
    
    @IBAction func selectedItem_MenuItem(_ sender: NSMenuItem) {
//        print("sender title: \(sender.title)")
        menuTitle           = "\(sender.title)"
        menuIdentifier      = "\(sender.identifier?.rawValue ?? "")"
        
        if menuIdentifier != "" {
            
            //get_button.isEnabled    = true
            export_button.isEnabled  = false
            exportTitleSuffix       = ""
            
            switch menuIdentifier {
            case "mac_access", "mac_ad-cert", "mac_airplay", "mac_acs", "mac_atpavpn", "mac_cert", "mac_dir", "mac_dock", "mac_energy", "mac_finder", "mac_font", "mac_ident", "mac_kext", "mac_loginitems", "mac_loginwindow", "mac_mobility", "mac_network", "mac_notifications", "mac_parental", "mac_passcode", "mac_pppc", "mac_print", "mac_proxies", "mac_restrict", "mac_scep", "mac_sec-priv-filevault", "mac_sec-priv-genfire", "mac_su", "mac_sysext", "mac_tm", "mac_vpn", "mac_xsan":
                endpointType = "mac_cp"
                select_MenuItem.title = "macOS-"+menuTitle
                exportTitleSuffix = "-" + menuIdentifier
            case "ios_airplay", "ios_airplaysec", "ios_airprint", "ios_apn", "ios_cal", "ios_cell", "ios_certt", "ios_certs", "ios_crd", "ios_contacts", "ios_cf", "ios_dnss", "ios_dnsp", "ios_domains", "ios_eas", "ios_font", "ios_global", "ios_google", "ios_hsl", "ios_ldap", "ios_lsm", "ios_mail", "ios_nur", "ios_not", "ios_passcode", "ios_restrict", "ios_scep", "ios_sam", "ios_sso", "ios_ssoe", "ios_skip", "ios_subcal", "ios_tvr", "ios_vpn", "ios_webclip", "ios_wifi":
                endpointType = "ios_cp"
                select_MenuItem.title = "iOS-"+menuTitle
                headersDict["ios_cp"]  = headersDict["mac_cp"]
                exportTitleSuffix = "-" + menuIdentifier
            case "scg","sdg":    // added sdg lnh - 201205
                endpointType = menuIdentifier
                select_MenuItem.title = menuTitle+" Groups"
            case "cea","mdea":
                endpointType = menuIdentifier
                select_MenuItem.title = menuTitle+" EA"
                headersDict["mdea"]  = headersDict["cea"]
            case "trigger_checkin","trigger_enrollment_complete","trigger_login","trigger_logout","trigger_network_state_changed","trigger_startup","trigger_other":
                endpointType = menuIdentifier
                select_MenuItem.title = menuTitle
                endpointDict[endpointType] = endpointDict["recon"]!
                headersDict[endpointType]  = headersDict["recon"]!
                exportTitleSuffix = "-" + menuIdentifier
            case "apps_iOS","apps_macOS":
                endpointType = menuIdentifier
                select_MenuItem.title = menuTitle+" Apps"
            case "cp_all_iOS","cp_all_macOS":
                endpointType = menuIdentifier
                select_MenuItem.title = menuTitle+" Config Profiles"
            default:
    //            print("menuIdentifier: \(menuIdentifier)")
    //            print("menuTitle: \(menuTitle)")
                endpointType = menuIdentifier
                select_MenuItem.title = menuTitle
            }
            
            selection               = endpointDict[endpointType]!
            oSelectedEndpoint       = "\(selection[0])"
            oEndpointXmlTag         = "\(selection[1])"
            oSingleEndpointXmlTag   = "\(selection[2])"

            WriteToLog.shared.message(stringOfText: "endpointDict[\(endpointType)]: \(endpointDict[endpointType]!)")
            
            self.action_textField.stringValue = ""
            formatTableView(columnHeaders: headersDict[endpointType]!)
            
            endpoint_PopUpButton.select(select_MenuItem)
            summaryArray.removeAll()
            tableView.reloadData()
            progressBar.isHidden = true
            progressBar.increment(by: -100.0)
            get(self)
        } else {
            endpointXmlTag   = ""
        }
    }


    @IBAction func get(_ sender: Any) {
        
        stopScan         = false
        Log.lookupFailed = false
        Log.FailedCount  = 0
        pendingGetCount  = 0
        
        // start things in motion
        export_button.isEnabled = false
        spinner.isHidden = false
        spinner.startAnimation(self)
        
        JamfPro.shared.getToken(serverUrl: JamfProServer.server) { [self]
            (result: (Int,String)) in
            
            let (statusCode,tokenResult) = result
            if tokenResult == "failed" {
                WriteToLog.shared.message(stringOfText: "[get] failed to get token")
                let response = ( statusCode == 0 ) ? "No response from the server.":"\(statusCode)"
                _ = Alert.shared.display(header: "", message: "Failed to get authentication token.\n Status code: \(response)", secondButton: "")
                spinner.isHidden = true
                spinner.stopAnimation(self)
                return
            }
            
            selectedEndpoint       = oSelectedEndpoint  //ex: .../JSSResource/selectedEndpoint
            endpointXmlTag         = oEndpointXmlTag
            singleEndpointXmlTag   = oSingleEndpointXmlTag
            if endpointXmlTag != "" {
                
                summaryArray.removeAll()
                details_TextView.string = ""
                
                for exportHeader in headersDict[endpointType]! {
                    details_TextView.string.append(exportHeader+"\t")
                }
                details_TextView.string.append("\n")

                self.results_TextView.string = ""
//                displayResults               = ""
                idNameDict.removeAll()
                objectByNameDict.removeAll()
                allDetailedResults           = ""
                packageScriptArray.removeAll()
                pkgScrArray.removeAll()

                WriteToLog.shared.message(stringOfText: "[get]       apiCall for endpoint: \(endpointXmlTag)")
                WriteToLog.shared.message(stringOfText: "[get] apiCall for menuIdentifier: \(menuIdentifier)")
                
//                print("[get] calling endpointXmlTag: \(endpointXmlTag)")
                
                apiCall(endpoint: "\(endpointXmlTag)") { [self]
                    (result: [Int:String]) in
                    WriteToLog.shared.message(stringOfText: "[get] returned from apiCall for \(endpointXmlTag) - result:\n\(result)")
                    
                    results_TextView.string = "\(result)"
                    if menuIdentifier == "Packages" || menuIdentifier == "Printers" || menuIdentifier == "Scripts" || menuIdentifier == "scg" || menuIdentifier == "sdg" || menuIdentifier == "cea" || menuIdentifier == "mdea" {
                        
                        for (_, objectName) in idNameDict {
                            WriteToLog.shared.message(stringOfText: "[get] theRecord: \(objectName)")

                            pkgScrArray.append("\(objectName)")
                        }
                        
                        if menuIdentifier == "cea" || menuIdentifier == "mdea" {
                            switch menuIdentifier {
                            case "cea":
                                selectedEndpoint     = "computergroups"
                                singleEndpointXmlTag = "computer_group"
                                action_textField.stringValue = "Querying macOS extension attributes"
                            default:
                                selectedEndpoint     = "mobiledevicegroups"
                                singleEndpointXmlTag = "mobile_device_group"
                                action_textField.stringValue = "Querying mobile device extension attributes"
                            }

                            JamfPro.shared.objectByName(endpoint: menuIdentifier, endpointData: idNameDict) { [self]
//                            JamfPro().objectByName(endpoint: menuIdentifier, endpointData: packageScriptArray) { [self]
                                (result: String) in
                                // switch lookup to eas scoped to groups - start
                                WriteToLog.shared.message(stringOfText: "[get] apiCall (\(singleEndpointXmlTag)s) for endpoint: Groups")
                                apiCall(endpoint: "\(singleEndpointXmlTag)s") { [self]
                                    (result: [Int:String]) in
                                    // need to fix
                                    results_TextView.string = "\(result)"
//                                    print("[get-menuIdentifier] result: \(result)")
                                }
                                // switch lookup to eas scoped to groups - end
                            }
                        } else if menuIdentifier != "sdg" {
                            // switch lookup to packages/printers/scripts scoped to policies - start
                            WriteToLog.shared.message(stringOfText: "[get] apiCall for endpoint: policies")
                            selectedEndpoint     = "policies"
                            singleEndpointXmlTag = "policy"
                            apiCall(endpoint: "policies") { [self]
                                (result: [Int:String]) in
                                // need to fix
                                results_TextView.string = "\(result)"
        //                        print("apiCall done with policies?\n\(result)\n")
                            }
                            // switch lookup to packages/scripts scoped to policies - end
                        } else {
                            // switch lookup to mobile device groups scoped to configuration profiles - start
                            WriteToLog.shared.message(stringOfText: "[get] apiCall for endpoint: configuration_profiles")
                            selectedEndpoint     = "mobiledeviceconfigurationprofiles"
                            singleEndpointXmlTag = "configuration_profile"
                            apiCall(endpoint: "configuration_profiles") { [self]
                                (result: [Int:String]) in
                                // need to fix
                                results_TextView.string = "\(result)"
    //                            print("apiCall done with policies?\n\(result)\n")
                            }
                            // switch lookup to mobile device groups scoped to configuration profiles - end
                        }
                    } else if menuIdentifier == "cp_all_macOS" {
                        // start looping through computer PreStages - start
                        selectedEndpoint = "computer-prestages"
                        prestages(currentPage: 0, pageSize: 200, objectCount: 0, endpoint: selectedEndpoint, subsearch: "prestageInstalledProfileIds")
                    } else if menuIdentifier == "cp_all_iOS" {
                        // mobile-device-prestages
                        selectedEndpoint = "mobile-device-prestages"
                        prestages(currentPage: 0, pageSize: 200, objectCount: 0, endpoint: selectedEndpoint, subsearch: "prestageInstalledProfileIds")
                    }
                }
            }
        }
    }
    
    func prestages(currentPage: Int, pageSize: Int, objectCount: Int, endpoint: String, subsearch: String) {
        JamfPro.shared.jpapiGET(endpoint: endpoint, page: "\(currentPage)", pageSize: "\(pageSize)", apiData: [:], id: "", token: "") { [self]
            (result: [String:Any]) in
//            print("prestage results: \(result)")
            guard let prestageCount = result["totalCount"] as? Int else {
                return
            }
//            print("total prestages: \(prestageCount)")
//            print("      subsearch: \(subsearch)")
//            print("          range: \(min(prestageCount, pageSize))")
            let range = min(prestageCount,pageSize)
            let allprestages = result["results"] as? [[String:Any]]
            for i in 0..<min(prestageCount, range) {
                let prestageInfo = allprestages?[i]
//                print("   prestageInfo: \(prestageInfo ?? [:])")
                let prestageProfiles = prestageInfo?[subsearch] as? [String]
                if prestageProfiles?.count ?? 0 > 0 {
                    let objectDisplayName = prestageInfo!["displayName"] as! String
                    for prestageID in prestageProfiles! {
                        let profileName = idNameDict[Int(prestageID)!]
                        if subsearch == "prestageInstalledProfileIds" {
                            summaryArray.append(EndpointData(column1: "\(String(describing: profileName!))", column2: "", column3: "", column4: "", column5: "", column6: "\(objectDisplayName)", column7: ""))
                            details_TextView.string.append("\(String(describing: profileName!))\t\t\t\t\t\(String(describing: objectDisplayName))\n")
                        } else {
                            summaryArray.append(EndpointData(column1: "\(String(describing: profileName!))", column2: "", column3: "", column4: "", column5: "\(objectDisplayName)", column6: "", column7: ""))
                            details_TextView.string.append("\(String(describing: profileName!))\t\t\t\t\(String(describing: objectDisplayName))\n")
                        }
//                        print("[prestage] profile name: \(String(describing: profileName!))")
                    }
                }
            }
            if range*(currentPage+1) < prestageCount {
                prestages(currentPage: currentPage+1, pageSize: pageSize, objectCount: range+1, endpoint: selectedEndpoint, subsearch: "prestageInstalledProfileIds")
            }
        }
    }
    
    @IBAction func QuitNow(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    func apiCall(endpoint: String, completion: @escaping (_ result: [Int:String]) -> Void) {
        
        if stopScan {
            print("[apiCall] stop")
            completion([:])
            return
        }
        
        WriteToLog.shared.message(stringOfText: "[apiCall] endpoint: \(endpoint)")

        completeCounter[endpoint] = 0
        progressBar.increment(by: -1.0)

        apiQ.maxConcurrentOperationCount = 4
        let semaphore = DispatchSemaphore(value: 0)
//        let semaphore = DispatchSemaphore(value: 1)   // used with theGeneralQ
        var localCounter = 0    // not needed?
        
        if self.selectedEndpoint != "" {
            WriteToLog.shared.message(stringOfText: "[apiCall] selectedEndpoint: \(selectedEndpoint)")
            endpointUrl = JamfProServer.server + "/JSSResource/\(selectedEndpoint)"
            endpointUrl = endpointUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            WriteToLog.shared.message(stringOfText: "[apiCall] endpointURL: \(endpointUrl)")
        } else {
            completion([0:"no endpoint selected"])
        }
        
        apiQ.addOperation {
            let encodedURL = NSURL(string: self.endpointUrl)
            let request = NSMutableURLRequest(url: encodedURL! as URL)
            
            request.httpMethod = "GET"
            let serverConf = URLSessionConfiguration.ephemeral
            
            serverConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.accessToken)", "User-Agent" : AppInfo.userAgentHeader, "Content-Type" : "application/json", "Accept" : "application/json"]
            URLCache.shared.removeAllCachedResponses()
            let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = serverSession.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
                serverSession.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
//                    if httpResponse.statusCode > 199 && httpResponse.statusCode <= 299 {
                    WriteToLog.shared.message(stringOfText: "[apiCall] completion - HTTP status code for \(self.endpointUrl): \(httpResponse.statusCode)")
                        do {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            
                            let fixedJson = (httpResponse.statusCode > 199 && httpResponse.statusCode <= 299) ? json:["\(endpoint)":[AnyObject.self]]
//                            if let endpointJSON = json as? [String: Any] {
                            if let endpointJSON = fixedJson as? [String: Any] {
    //                            print("[ViewController.apiCall] endpoint: \(endpoint)")
    //                            print("[ViewController.apiCall] endpointJSON: \(endpointJSON)")
                                let endpointInfo = self.validEndpointInfo(endpointJSON: endpointJSON, endpoint: endpoint)
//                                print("[ViewController.apiCall]       endpointInfo: \(endpointInfo)")
//                                print("[ViewController.apiCall] endpointInfo.count for \(self.selectedEndpoint): \(endpointInfo.count)")

                                self.apiDetailCount[endpoint] = endpointInfo.count
                                if (self.apiDetailCount[endpoint] ?? 0 > 0) {

                                    self.stop_button.isHidden = false
                                    self.progressBar.isHidden = false
                                    self.progressBar.maxValue = 1.0
                                    self.increment = 1.0/Double(self.apiDetailCount[endpoint] ?? 0)
                                    
                                    // display what is being search
    //                                print(" selectedEndpoint: \(self.selectedEndpoint)")
    //                                print("oSelectedEndpoint: \(self.oSelectedEndpoint)")
                                    switch self.selectedEndpoint {
                                    case "policies","packages","printers","scripts","computergroups":
                                        if self.oSelectedEndpoint == "computerextensionattributes" {
                                            self.action_textField.stringValue = "Querying Computer Groups"
                                        } else {
                                            self.action_textField.stringValue = "Querying policies"
                                        }
                                    case "computerconfigurations":
                                        self.action_textField.stringValue = "Querying computer configurations"
                                    case "osxconfigurationprofiles":
                                        self.action_textField.stringValue = "Querying macOS configuration profiles"
                                    case "mobiledeviceconfigurationprofiles","mobiledevicegroups":
                                        if self.oSelectedEndpoint == "mobiledeviceextensionattributes" {
                                            self.action_textField.stringValue = "Querying Mobile Device Groups"
                                        } else {
                                            self.action_textField.stringValue = "Querying mobile configuration profiles"
                                        }
                                    case "macapplications":
                                        self.action_textField.stringValue = "Querying macOS apps"
                                    case "mobiledeviceapplications":
                                        self.action_textField.stringValue = "Querying mobile apps"
                                    case "advancedcomputersearches", "advancedmobiledevicesearches":
                                        self.action_textField.stringValue = "Querying Advanced Searches"
                                    default:
                                        self.action_textField.stringValue = ""
                                    }

                                } else {
                                    if self.selectedEndpoint != "computerconfigurations" && self.selectedEndpoint != "advancedmobiledevicesearches" {
                                        self.alert_dialog(header: "Alert", message: "Nothing found at:\n\(self.endpointUrl)")
                                        WriteToLog.shared.message(stringOfText: "[apiCall] completion - Nothing found at: \(self.endpointUrl)")
                                    }
                                    if self.selectedEndpoint == "computerconfigurations" || self.selectedEndpoint == "macapplications" {
    //                                    self.increment = 100.0
    //                                    self.apiDetailCount = self.completeCounter
                                        self.queryComplete()
                                    }
                                    completion([:])
                                }
                    
                                var i = 0
//                                for i in (0..<endpointInfo.count) {
                                while i < endpointInfo.count {
                                    
                                    if stopScan {
                                        break
                                    }
                                    
                                    let theRecord  = endpointInfo[i] as! [String : AnyObject]
                                    let recordId   = theRecord["id"] as! Int
                                    let recordName = theRecord["name"] as! String
                                
                                    idNameDict[recordId] = recordName
//                                    self.displayResults.append("\(recordId)\t\(recordName)\n")
//                                    print("[apiCall] \(i)\t\(recordId)\t\(recordName)")

//                                    print("[apiCall] switch endpoint: \(endpoint)")
                                    switch endpoint {
                                        case "network_segments","os_x_configuration_profiles":
                                            self.getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) {
                                                (result: String) in
                                                self.allDetailedResults.append("\(result)")
                                                localCounter+=1
                                                if localCounter == endpointInfo.count && self.menuIdentifier == "scg" {
                                                    // start looping through macapplications - start
                                                    self.selectedEndpoint     = "macapplications"
                                                    self.singleEndpointXmlTag = "mac_application"
                                                    self.apiCall(endpoint: "mac_applications") {
                                                        (result: [Int:String]) in
                                                        // need to fix
                                                        self.results_TextView.string = "\(result)"
    //                                                  print("apiCall done with mobile device applications?\n\(result)\n")
                                                    }
                                                }
                                            }
                                        case "mac_applications":
                                            self.getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) {
                                                (result: String) in
                                                self.allDetailedResults.append("\(result)")
                                            }
                                        case "policies":    // used for packages and scripts
        //                                        print("policy: \(recordName)")
                                            self.getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) { [self]
                                                (result: String) in
                                                allDetailedResults.append("\(result)")
                                                localCounter+=1
        //                                                print("localCounter: \(localCounter) \tarray count: \(endpointInfo.count)")
                                                if localCounter == endpointInfo.count {
                                                    // display packages and script not attached to any policies
                                                    
        //                                            if self.menuIdentifier != "recon" {
                                                    switch menuIdentifier {
//                                                    case "Packages","Scripts":
                                                        case "Packages":
                                                            // start looping through computer PreStages - start
                                                        print("[Packages] call prestages query")
                                                            selectedEndpoint = "computer-prestages"
                                                        prestages(currentPage: 0, pageSize: 200, objectCount: 0, endpoint: selectedEndpoint, subsearch: "customPackageIds")
//                                                        JamfPro().jpapiGET(endpoint: "computer-prestages", apiData: [:], id: "", token: "") {
//                                                            (result: [String:Any]) in
//                                                            print("prestage results: \(result)")
//                                                        }
//                                                            self.selectedEndpoint = "computerconfigurations"
//                                                            self.singleEndpointXmlTag = "computer_configuration"
//                                                            self.apiCall(endpoint: "computer_configurations") {
//                                                                (result: String) in
//                                                                self.results_TextView.string = "\(result)"
//        //                                                      print("apiCall done with configurations?\n\(result)\n")
//                                                            }
                                                        case "scg":
                                                            // start looping through configurations - start
                                                            selectedEndpoint = "osxconfigurationprofiles"
                                                            singleEndpointXmlTag = "os_x_configuration_profile"
                                                            apiCall(endpoint: "os_x_configuration_profiles") { [self]
                                                                (result: [Int:String]) in
                                                                // need to fix
                                                                results_TextView.string = "\(result)"
            //                                                  print("apiCall done with configurations?\n\(result)\n")
                                                                }
                                                        default:
                                                            break
                                                    }
        //                                            }   // if self.menuIdentifier != "recon" - end
                                                }
                                            }
                                        case "computer_configurations":
                                        self.getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) { [self]
                                                (result: String) in
                                                self.allDetailedResults.append("\(result)")
                                                if localCounter == endpointInfo.count { //i == (endpointInfo.count-1) {
                                                    // display packages and script not attached to any policies
                                                    for unused in self.pkgScrArray {
                                                        summaryArray.append(EndpointData(column1: unused, column2: "", column3: "", column4: "", column5: "", column6: "", column7: ""))
                                                    }
                                                }
                                            }

                                        case "configuration_profiles":  // added 201207 lnh
                                             self.getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) {
                                                 (result: String) in
                                                 self.allDetailedResults.append("\(result)")
                                                 localCounter+=1
            //                                                print("localCounter: \(localCounter) \tarray count: \(endpointInfo.count)")
                                                 if localCounter == endpointInfo.count {
                                                     // display packages and script not attached to any policies

            //                                            if self.menuIdentifier != "recon" {
                                                     switch self.menuIdentifier {
                                                         case "sdg":
                                                             // start looping through configurations - start
                                                             self.selectedEndpoint     = "mobiledeviceapplications"
                                                             self.singleEndpointXmlTag = "mobile_device_application"
                                                             self.apiCall(endpoint: "mobile_device_applications") {
                                                                 (result: [Int:String]) in
                                                                 // need to fix
                                                                 self.results_TextView.string = "\(result)"
             //                                                  print("apiCall done with mobile device applications?\n\(result)\n")
                                                                 }
                                                         default:
                                                             break
                                                     }
            //                                            }   // if self.menuIdentifier != "recon" - end
                                                 }
                                             }

                                        case "mobile_device_applications":
                                        self.getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) { [self]
                                                (result: String) in
                                                allDetailedResults.append("\(result)")
                                                if localCounter == endpointInfo.count { //i == (endpointInfo.count-1) {
                                                    // display packages and script not attached to any policies
                                                    for unused in self.pkgScrArray {
                                                        summaryArray.append(EndpointData(column1: unused, column2: "", column3: "", column4: "", column5: "", column6: "", column7: ""))
                                                    }
                                                }
                                            }
                                                
                                        case "computer_groups","mobile_device_groups":
                                            if self.menuIdentifier != "scg" && self.menuIdentifier != "sdg" {
                                                getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) { [self]
                                                    (result: String) in
                                                    allDetailedResults.append("\(result)")
                                                    localCounter+=1
                                                    if localCounter == endpointInfo.count {
                                                         
                                                         switch self.menuIdentifier {
                                                             case "cea":
    //                                                             print("start advanced computer searches query")
                                                                 self.selectedEndpoint     = "advancedcomputersearches"
                                                                 self.singleEndpointXmlTag = "advanced_computer_search"
                                                                 self.apiCall(endpoint: "advanced_computer_searches") {
                                                                     (result: [Int:String]) in
                                                                     // need to fix
                                                                     self.results_TextView.string = "\(result)"
                                                                }
                                                             default:
    //                                                            print("start advanced mobile device searches query")
                                                                self.selectedEndpoint     = "advancedmobiledevicesearches"
                                                                self.singleEndpointXmlTag = "advanced_mobile_device_search"
                                                                self.apiCall(endpoint: "advanced_mobile_device_searches") {
                                                                    (result: [Int:String]) in
                                                                    // need to fix
                                                                    self.results_TextView.string = "\(result)"
                                                               }
                                                         }
                                                     }
                                                 }
                                            }
                                            
                                        case "advanced_computer_searches", "advanced_mobile_device_searches":
                                             self.getDetailsQueue(id: "\(recordId)", endpointAddress: self.endpointUrl, theEndpoint: endpoint) {
                                                (result: String) in
                                                self.allDetailedResults.append("\(result)")
                                                localCounter+=1
                                                if localCounter == endpointInfo.count {
                                                    self.queryComplete()
                                                }
                                             }

                                            default:
                                                break
        //                                  print("Script or Package")
                                    }
                                    i = stopScan ? endpointInfo.count-1:i + 1
                                }   // for i in (0..<endpointInfo.count) - end
                                
                            }  else {  // if let serverEndpointJSON - end
                                WriteToLog.shared.message(stringOfText: "apiCall - existing endpoints: error serializing JSON: \(String(describing: error))")
                            }
                        }   // end do
                        if httpResponse.statusCode > 199 && httpResponse.statusCode <= 299 {

                            WriteToLog.shared.message(stringOfText: "[apiCall] completion - status code: \(httpResponse.statusCode)")
                            completion(idNameDict)

                        } else {
                            // something went wrong
                            WriteToLog.shared.message(stringOfText: "[apiCall] completion - Something went wrong, status code: \(httpResponse.statusCode)")
                            switch httpResponse.statusCode {
                            case 401:
                                self.alert_dialog(header: "Alert", message: "Authentication failed.  Check username and password.")
                            case 404:
                                WriteToLog.shared.message(stringOfText: "[apiCall] unknown endpoint: \(self.selectedEndpoint)")
                            default:
                                break
                            }
                            self.spinner.stopAnimation(self)
                            completion(idNameDict)
                        }   // if httpResponse.statusCode - end
                    
//                    } else {
//                        WriteToLog.shared.message(stringOfText: "[apiCall] completion - HTTP status code for \(self.endpointUrl): \(httpResponse.statusCode)")
//                        completion("")
//                    }
                    
                } else {  // if let httpResponse = response - end
                    WriteToLog.shared.message(stringOfText: "[apiCall] completion - No response to \(self.endpointUrl)")
                    self.alert_dialog(header: "Alert", message: "No response to:\n\(self.endpointUrl)")
                    completion([:])
                }
                semaphore.signal()
            })   // let task = serverSession.dataTask - end
            task.resume()
            semaphore.wait()
        }   // theGeneralQ - end
        
    }   // func apiCall - end
    
    
    func getDetailsQueue(id: String, endpointAddress: String, theEndpoint: String, completion: @escaping (_ result: String) -> Void) {
        
        getDetailsQ.async { [self] in
            
//            print("[endPointByIDQueue] queue \(endpoint) with name \(destEpName) for get")
            getDetailsArray.append(getInfo(id: id, endpointAddress: endpointAddress, theEndpoint: theEndpoint))
            
            while pendingGetCount > 0 || getDetailsArray.count > 0 {
                if pendingGetCount < maxConcurrentThreads && getDetailsArray.count > 0 {
                    pendingGetCount += 1
                    let nextEndpoint = getDetailsArray[0]
                    getDetailsArray.remove(at: 0)
                    
                    getDetails(id: nextEndpoint.id, endpointAddress: nextEndpoint.endpointAddress, theEndpoint: nextEndpoint.theEndpoint) { [self]
                            (result: String) in
                            pendingGetCount -= 1
                        completion(result)
                    }
                } else {
                    usleep(5000)
                }
            }
        }
    }
    
    func getDetails(id: String, endpointAddress: String, theEndpoint: String, completion: @escaping (_ result: String) -> Void) {
        
        // stops the lookups
        if stopScan {
            completion("")
            return
        }
        
        DispatchQueue.main.async {
//            get_button.isEnabled = false
            isRunning            = true
            URLCache.shared.removeAllCachedResponses()
            
            detailQ.maxConcurrentOperationCount = 4
            //        let semaphore   = DispatchSemaphore(value: 0)
            
            //        let safeCharSet = CharacterSet.alphanumerics
            
//            self.username = self.uname_TextField.stringValue
//            self.password = self.passwd_TextField.stringValue
            //        let jamfCreds = "\(self.username):\(self.password)"
            
            //        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
            //        let jamfBase64Creds = (jamfUtf8Creds?.base64EncodedString())!
        }
        usleep(1000)
        
        detailQ.addOperation { [self] in
//        let idUrl = self.endpointUrl+"/id/\(id)"
            let idUrl = "\(endpointAddress)/id/\(id)"
            WriteToLog.shared.message(stringOfText: "[getDetails] idUrl: \(idUrl)")
        

            let encodedURL          = NSURL(string: idUrl)
            let request             = NSMutableURLRequest(url: encodedURL! as URL)

            var thePackageArray     = [[String: Any]]()
            var objectDict          = [String: Any]()
            
            var searchStringArray   = [String]()
            var recordName          = ""
//            var currentPayload      = ""
            var triggers            = ""
            var freq                = ""
            var currentPolicyArray  = [String]()
            var criteriaName        = ""
            var criteriaArray       = [String]()
            var displayFieldsArray  = [String]()
            
            DispatchQueue.main.async {
                self.spinner.isHidden = false
                self.spinner.startAnimation(self)
                
                self.stop_button.isHidden = false
                self.action_textField.stringValue = "Getting details for \(endpointDefDict[self.singleEndpointXmlTag] ?? self.singleEndpointXmlTag)"
            }
                                    
            if menuIdentifier.lowercased().contains("ios") {
                scopeableObjectsArray = ["mobile_devices", "mobile_device_groups", "buildings", "departments", "users", "user_groups", "network_segments"]
            } else {
                scopeableObjectsArray = ["computers", "computer_groups", "buildings", "departments", "users", "user_groups", "network_segments"]
            }

            request.httpMethod = "GET"
            let serverConf = URLSessionConfiguration.default
            serverConf.timeoutIntervalForRequest = 15
            serverConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.accessToken)", "User-Agent" : AppInfo.userAgentHeader, "Content-Type" : "application/json", "Accept" : "application/json"]
            let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = serverSession.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
                serverSession.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode > 199 && httpResponse.statusCode <= 299 {
//                    do {
                        WriteToLog.shared.message(stringOfText: "[getDetails]                  GET: \(idUrl)")
                        WriteToLog.shared.message(stringOfText: "[getDetails] singleEndpointXmlTag: \(self.singleEndpointXmlTag)")
                        WriteToLog.shared.message(stringOfText: "[getDetails]       menuIdentifier: \(self.menuIdentifier)")

                        self.progressBar.increment(by: self.increment)
                        
                        switch self.menuIdentifier {
                        case "Policies-all":
                            self.singleEndpointXmlTag = "policy"
                        case "apps_macOS":
                            self.singleEndpointXmlTag = "mac_application"
                        case "apps_iOS":
                            self.singleEndpointXmlTag = "mobile_device_application"
                        case "cp_all_macOS":
                            self.singleEndpointXmlTag = "os_x_configuration_profile"
                        case "cp_all_iOS":
                            self.singleEndpointXmlTag = "configuration_profile"
                        default:
                            break
                        }
                        

                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json as? [String: Any] {
//                            print("[ViewController.getDetails] endpoint: \(self.singleEndpointXmlTag)")
//                            print("[ViewController.getDetails] endpointJSON: \(endpointJSON)")
                            if let endpointInfo = endpointJSON["\(self.singleEndpointXmlTag)"] as? [String : AnyObject] {
//                                print("[ViewController.getDetails] endpointInfo: \(endpointInfo)")
//                                print("[getDetails] self.singleEndpointXmlTag: \(self.singleEndpointXmlTag)")
                                if self.menuIdentifier.prefix(5) == "apps_" || self.menuIdentifier.prefix(5) == "cp_al" { self.singleEndpointXmlTag = self.menuIdentifier }
                                
//                                print("[getDetails] singleEndpointXmlTag: \(singleEndpointXmlTag)")
//                                print("[getDetails] \(singleEndpointXmlTag) thePackageArray: \(endpointInfo["printers"] ?? "nil" as AnyObject)")
                                
                                switch singleEndpointXmlTag {
                                case "network_segment":
                                    recordName      = endpointInfo["name"] as! String
                                    let starting    = endpointInfo["starting_address"] as! String
                                    let ending      = endpointInfo["ending_address"] as! String
                                    let dp          = endpointInfo["distribution_point"] as! String
                                    let url         = endpointInfo["url"] as! String
                                    detailedResults = "\(recordName) \t\(starting) \t\(ending) \t\(dp) \t\(url)"
                                case "os_x_configuration_profile","mac_application","configuration_profile","mobile_device_application":
                                    if let generalTag = endpointInfo["general"] as? [String : AnyObject] {
//                                        print("endpointInfo: \(endpointInfo)")
                                        self.detailedResults = ""
                                        recordName = generalTag["name"] as! String

                                        WriteToLog.shared.message(stringOfText: "[getDetails] \(self.singleEndpointXmlTag) name: \(recordName)")
                                        if !(self.menuIdentifier == "scg" || self.menuIdentifier == "sdg") {
                                            let payload = generalTag["payloads"]?.replacingOccurrences(of: "\"", with: "") ?? ""
    //                                        print("\(String(describing: payload))")
                                            switch self.menuIdentifier {
                                            case "mac_access":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Accessibility</string>", "<key>PayloadType</key><string>com.apple.universalaccess</string>"]
                                            case "mac_acs":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Custom Settings</string>", "<key>PayloadType</key><string>com.apple.ManagedClient.preferences</string>"]
                                            case "mac_ad-cert":
                                                searchStringArray = ["<string>com.apple.ADCertificate.managed</string>", "<key>PayloadDisplayName</key><string>AD Certificate</string>"]
                                            case "mac_airplay":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>AirPlay Payload</string>", "<key>PayloadType</key><string>com.apple.airplay</string>"]
                                            case "mac_atpavpn":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>App to Per-App VPN Mapping Payload</string>", "<key>PayloadType</key><string>com.apple.vpn.managed.appmapping</string>"]
                                            case "mac_cert":
                                                searchStringArray = ["<key>PayloadCertificateFileName</key>", "<key>PayloadType</key><string>com.apple.security.", "<key>AllowAllAppsAccess</key>"]
                                            case "mac_cf":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Web Content Filter Payload</string>"]
                                            case "mac_dir":
                                                searchStringArray = ["<string>com.apple.DirectoryService.managed</string>"]
                                            case "mac_dock":
                                                searchStringArray = ["<string>com.apple.dock</string>", "<string>Dock</string>"]
                                            case "mac_energy":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>MCX</string>", "<key>com.apple.EnergySaver.desktop.ACPower</key>", "<key>com.apple.EnergySaver.portable.ACPower-ProfileNumber</key>"]
                                            case "mac_finder":
                                                searchStringArray = ["<key>PayloadType</key><string>com.apple.finder</string>", "<key>InterfaceLevel</key><string>Full</string>"]
                                            case "mac_font":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Font</string>", "<key>PayloadType</key><string>com.apple.font</string>"]
                                            case "mac_ident":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Identity</string>", "<key>PayloadType</key><string>com.apple.configurationprofile.identification</string>"]
                                            case "mac_kext":
                                                searchStringArray = ["<string>com.apple.syspolicy.kernel-extension-policy</string>"]
                                            case "mac_loginitems":
                                                searchStringArray = ["<string>com.apple.loginitems.managed</string>"]
                                            case "mac_loginwindow":
                                                searchStringArray = ["<string>com.apple.MCX</string>", "<string>Login Window:  Global Preferences</string>", "<string>Login Window</string>"]
                                            case "mac_mobility":
                                                searchStringArray = ["<key>cachedaccounts.WarnOnCreate.allowNever</key>", "<string>com.apple.homeSync</string>"]
                                            case "mac_network":
                                                searchStringArray = ["<key>HIDDEN_NETWORK</key>"]
                                            case "mac_notifications":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Notifications Payload</string>", "<key>PayloadType</key><string>com.apple.notificationsettings</string>"]
                                            case "mac_parental":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Parental Controls</string>"]
                                            case "mac_passcode":
                                                searchStringArray = ["<string>com.apple.mobiledevice.passwordpolicy</string>"]
                                            case "mac_pppc":
                                                searchStringArray = ["<key>PayloadType</key><string>com.apple.TCC.configuration-profile-policy</string>"]
                                            case "mac_print":
                                                searchStringArray = ["<string>com.apple.mcxprinting</string>"]
                                            case "mac_proxies":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Proxies</string>", "<key>PayloadType</key><string>com.apple.SystemConfiguration</string>"]
                                            case "mac_restrict":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>MCX</string>", "<key>PayloadType</key><string>com.apple.MCX</string>", "<key>PayloadType</key><string>com.apple.applicationaccess.new</string>"]
                                            case "mac_scep":
                                                searchStringArray = ["<string>com.apple.security.scep</string>"]
                                            case "mac_sec-priv-filevault":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>FileVault</string>"]
                                            case "mac_sec-priv-genfire":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>PreferenceSecurity</string>"]
                                            case "mac_su":
                                                searchStringArray = ["<string>com.apple.SoftwareUpdate</string>"]
                                            case "mac_sysext":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>System Extensions</string>", "<key>PayloadType</key><string>com.apple.system-extension-policy</string>"]
                                            case "mac_tm":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Time Machine</string>", "<key>PayloadType</key><string>com.apple.MCX.TimeMachine</string>"]
                                            case "mac_vpn":
                                                searchStringArray = ["<key>VPNType</key>"]
                                            case "mac_xsan":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Xsan</string>", "<key>PayloadType</key><string>com.apple.xsan</string>"]
                                            case "ios_airplay":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>AirPlay Payload</string>", "<key>PayloadType</key><string>com.apple.airplay</string>"]
                                            case "ios_airplaysec":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.airplay.security</string>", "<key>PayloadType</key><string>com.apple.airplay.security</string>"]
                                            case "ios_airprint":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.airprint</string>", "<key>PayloadType</key><string>com.apple.airprint</string>"]
                                            case "ios_apn":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.apn.managed</string>", "<key>PayloadType</key><string>com.apple.apn.managed</string>"]
                                            case "ios_cal":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>CalDAV</string>", "<key>PayloadType</key><string>com.apple.caldav.account</string>"]
                                            case "ios_cell":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.cellular</string>", "<key>PayloadType</key><string>com.apple.cellular</string>"]
                                            case "ios_certs":
                                                searchStringArray = ["<key>PayloadCertificateFileName</key>", "<key>PayloadType</key><string>com.apple.security.", "<key>AllowAllAppsAccess</key>"]
                                            case "ios_certt":
                                                searchStringArray = ["<string>com.apple.security.certificatetransparency</string>"]
                                            case "ios_cf":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.webcontent-filter</string>", "<key>PayloadType</key><string>com.apple.webcontent-filter</string>"]
                                            case "ios_contacts":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.carddav.account</string>", "<key>PayloadType</key><string>com.apple.carddav.account</string>"]
                                            case "ios_crd":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.conferenceroomdisplay</string>", "<key>PayloadType</key><string>com.apple.conferenceroomdisplay</string>"]
                                            case "ios_dnsp":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>DNS Proxy</string>", "<string>com.apple.dnsProxy.managed</string>"]
                                            case "ios_dnss":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>DNS Settings</string>", "<string>com.apple.dnsSettings.managed</string>"]
                                            case "ios_domains":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.domains</string>", "<key>PayloadType</key><string>com.apple.domains</string>"]
                                            case "ios_eas":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Exchange ActiveSync</string>", "<key>PayloadType</key><string>com.apple.eas.account</string>"]
                                            case "ios_font":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.font</string>", "<key>PayloadType</key><string>com.apple.font</string>"]
                                            case "ios_global":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.proxy.http.global</string>", "<key>PayloadType</key><string>com.apple.proxy.http.global</string>"]
                                            case "ios_google":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.google-oauth</string>", "<key>PayloadType</key><string>com.apple.google-oauth</string>"]
                                            case "ios_hsl":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.homescreenlayout</string>", "<key>PayloadType</key><string>com.apple.homescreenlayout</string>"]
                                            case "ios_ldap":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.ldap.account</string>", "<key>PayloadType</key><string>com.apple.ldap.account</string>"]
                                            case "ios_lsm":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Lock Screen Message Payload</string>", "<key>PayloadType</key><string>com.apple.shareddeviceconfiguration</string>"]
                                            case "ios_mail":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.mail.managed</string>", "<key>PayloadType</key><string>com.apple.mail.managed</string>"]
                                            case "ios_not":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Notifications Payload</string>", "<key>PayloadType</key><string>com.apple.notificationsettings</string>"]
                                            case "ios_nur":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.networkusagerules</string>", "<key>PayloadType</key><string>com.apple.networkusagerules</string>"]
                                            case "ios_passcode":
                                                searchStringArray = ["<string>com.apple.mobiledevice.passwordpolicy</string>"]
                                            case "ios_restrict":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Restrictions Payload</string>", "<key>PayloadType</key><string>com.apple."]
                                            case "ios_sam":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.app.lock</string>", "<key>PayloadType</key><string>com.apple.app.lock</string>"]
                                            case "ios_scep":
                                                searchStringArray = ["<string>com.apple.security.scep</string>"]
                                            case "ios_skip":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Setup Assistant</string>", "<key>PayloadType</key><string>com.apple.SetupAssistant.managed</string>"]
                                            case "ios_sso":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.sso</string>", "<key>PayloadType</key><string>com.apple.sso</string>"]
                                            case "ios_ssoe":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Single Sign-On Extensions Payload</string>", "<key>PayloadType</key><string>com.apple.extensiblesso</string>"]
                                            case "ios_subcal":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.subscribedcalendar.account</string>", "<key>PayloadType</key><string>com.apple.subscribedcalendar.account</string>"]
                                            case "ios_tvr":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Tv Remote Payload</string>", "<key>PayloadType</key><string>com.apple.tvremote</string>"]
                                            case "ios_vpn":
                                                searchStringArray = ["<key>VPNType</key>"]
                                            case "ios_webclip":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>Web Clip</string>", "<key>PayloadType</key><string>com.apple.webClip.managed</string>"]
                                            case "ios_wifi":
                                                searchStringArray = ["<key>HIDDEN_NETWORK</key>"]

                                            default:
                                                break
                                            }

                                            WriteToLog.shared.message(stringOfText: "[searchResults] looking for \(self.menuTitle)")
                                            if searchResult(payload: payload, critereaArray: searchStringArray) {
                                                WriteToLog.shared.message(stringOfText: "[searchResults] \(self.menuTitle) found in \(recordName)")
                                                self.detailedResults = "\(self.menuTitle) \t\(recordName)"
//                                                switch self.endpointType {
//                                                case "ios_cp":
                                                    self.getScope(endpointInfo: endpointInfo, scopeObjects: scopeableObjectsArray)
                                                limitationsExclusions = getLimitationsExceptions(endpointInfo: endpointInfo, endpointType: selectedEndpoint)
//                                                    self.getScope(endpointInfo: endpointInfo, scopeObjects: ["mobile_devices", "mobile_device_groups", "buildings", "departments", "users", "user_groups", "network_segments")
//                                                default:
//                                                    self.getScope(endpointInfo: endpointInfo, scopeObjects: scopeableObjectsArray)
//                                                    self.getScope(endpointInfo: endpointInfo, scopeObjects: ["computers", "computer_groups", "buildings", "departments", "users", "user_groups", "network_segments")
//                                                }

                                            } else {
                                                WriteToLog.shared.message(stringOfText: "[searchResults] \(recordName) not found")
                                                self.detailedResults = ""
                                            }

                                        }

                                        switch self.menuIdentifier {
                                            case "scg":
                                                let packageConfigTag = endpointInfo["scope"] as! [String:AnyObject]
                                                thePackageArray      = packageConfigTag["computer_groups"] as! [[String: Any]]
                                                if packageConfigTag["all_computers"] as! Bool {
                                                    thePackageArray.append(["id": 1, "name": "All Computers"])
                                                }
                                                searchStringArray    = [""]
                                            case "sdg": // added 201207 lnh
                                                WriteToLog.shared.message(stringOfText: "[getDetails] Checking scope for \(self.singleEndpointXmlTag)")
                                                let packageConfigTag = endpointInfo["scope"] as! [String:AnyObject]
                                                thePackageArray      = packageConfigTag["mobile_device_groups"] as! [[String: Any]]
                                                if packageConfigTag["all_mobile_devices"] as! Bool {
                                                    thePackageArray.append(["id": 1, "name": "All iOS Devicces"])
                                                }
                                                searchStringArray    = [""]
                                            default:
                                                break
                                        }

                                    }

                                case "policy","computer_configuration","apps_macOS","apps_iOS","cp_all_macOS","cp_all_iOS":
                                    if let generalTag = endpointInfo["general"] as? [String : AnyObject] {
                                        recordName = generalTag["name"] as! String
                                        self.detailedResults = "\(recordName)"
                                        WriteToLog.shared.message(stringOfText: "[getDetails] case policy,computer_configuration - Policy Name: \(recordName)")
                                        // get triggers
                                        if self.selectedEndpoint == "policies" {
                                            triggers = self.triggersAsString(generalTag: generalTag)
                                            if generalTag["enabled"] as! Bool {
                                                freq = generalTag["frequency"] as! String
                                            } else {
                                                freq = "[disabled]"
                                            }
                                        }
                                    }
                                    switch self.menuIdentifier {
                                    case "recon", "trigger_checkin","trigger_enrollment_complete","trigger_login","trigger_logout","trigger_network_state_changed","trigger_startup","trigger_other":
                                        let theTag = (self.menuIdentifier == "recon") ? "maintenance":"general"
                                        objectDict = endpointInfo[theTag] as! [String: Any]
                                        if (objectDict[self.menuIdentifier] as? Bool ?? false) || (self.menuIdentifier == "trigger_other" && objectDict["trigger_other"] as! String != "") {
                                            self.getScope(endpointInfo: endpointInfo, scopeObjects: ["computers", "computer_groups", "buildings", "departments", "users", "user_groups", "network_segments"])
                                            self.detailedResults = "\(recordName) \t\(triggers) \t\(freq) \t\(self.theScope)"
//                                            print("self.detailedResults: \(self.detailedResults)")
                                        }

                                    case "Packages":
                                        if self.selectedEndpoint == "policies" {
                                            let packageConfigTag = endpointInfo["package_configuration"] as! [String:AnyObject]
                                            thePackageArray      = packageConfigTag["packages"] as! [[String: Any]]
                                        } else {
                                            // packages in computerconfigurations
                                            thePackageArray = endpointInfo["packages"] as? [[String: Any]] ?? [[:]]
                                        }
                                        
                                    case "Printers":
                                        if let printerInfo = endpointInfo["printers"] as? [Any], printerInfo.count > 1 {
                                            thePackageArray.removeAll()
                                            for thePrinter in printerInfo {
                                                if let printerData = thePrinter as? [String: Any] {
                                                    print("[getDetails] printers append: \(printerData["name"] ?? "unknown")")
                                                    thePackageArray.append(printerData)
                                                }
                                            }
//                                            print("[getDetails] printers printerInfo: \(printerInfo)")
//                                            thePackageArray = printerInfo[1] as? [[String: Any]] ?? [[:]]
                                            print("[getDetails] printers thePackageArray: \(thePackageArray)")
                                        }

                                    case "Scripts":
                                        thePackageArray = endpointInfo["scripts"] as? [[String: Any]] ?? [[:]]

                                    case "scg":
                                        let packageConfigTag = endpointInfo["scope"] as! [String:AnyObject]
                                        thePackageArray      = packageConfigTag["computer_groups"] as! [[String: Any]]
                                        if packageConfigTag["all_computers"] as! Bool {
                                            thePackageArray.append(["id": 1, "name": "All Computers"])
                                        }
                                        
                                    case "Policies-all","apps_macOS","apps_iOS","cp_all_macOS","cp_all_iOS":
                                        if let generalTag = endpointInfo["general"] as? [String : AnyObject] {
                                            recordName = generalTag["name"] as! String
            
                                            WriteToLog.shared.message(stringOfText: "[getDetails] case all items (\(menuIdentifier)) - Name: \(recordName)")
                                            
                                            switch menuIdentifier {
                                            case "Policies-all":
                                                payloadArray = policyPayloads(xml: endpointInfo)
                                            case "apps_macOS","apps_iOS":
                                                managedDist = false
                                                if let vpp = endpointInfo["vpp"] as? [String : AnyObject] {
                                                    if let md = vpp["assign_vpp_device_based_licenses"] as? Bool {
                                                        managedDist = md
                                                    }
                                                }
                                            case "cp_all_macOS","cp_all_iOS":
                                                payloadArray = profilePayloads(payloadXML: generalTag["payloads"] as? String ?? "", platform: menuIdentifier)
                                            default:
                                                break
                                            }
                                            
                                            thePackageArray = [["id": "\(String(describing: generalTag["id"]))", "name": recordName]]
                                            
//                                            if menuIdentifier.lowercased().contains("ios") {
//                                                scopeableObjectsArray = ["mobile_devices", "mobile_device_groups", "buildings", "departments", "users", "user_groups", "network_segments"]
//                                            } else {
//                                                scopeableObjectsArray = ["computers", "computer_groups", "buildings", "departments", "users", "user_groups", "network_segments"]
//                                            }
                                            
                                            self.getScope(endpointInfo: endpointInfo, scopeObjects: scopeableObjectsArray)
                                            limitationsExclusions = getLimitationsExceptions(endpointInfo: endpointInfo, endpointType: selectedEndpoint)
                                            
                                            switch self.menuIdentifier {
                                            case "Policies-all":
                                                self.detailedResults = "\(recordName) \t\(thePackageArray) \t\(triggers) \t\(freq) \t\(self.theScope) \t\(String(describing: limitationsExclusions["limitations"]))\t\(limitationsExclusions["exclusions"] ?? [])"
                                            case "apps_macOS","apps_iOS":
                                                self.detailedResults = "\(recordName) \t\(managedDist) \t\(self.theScope) \t\(limitationsExclusions["limitations"] ?? [])\t\(limitationsExclusions["exclusions"] ?? [])"
                                            default:
                                                break
                                            }
                                        }

                                    default:
                                        break
                                    }
                                    
                                case "computer_group", "advanced_computer_search", "mobile_device_group", "advanced_mobile_device_search":
                                    if let _ = endpointInfo["name"] as? String {
                                        recordName = endpointInfo["name"] as! String
                                        let groupCriteria = endpointInfo["criteria"] as? [[String: Any]]
                                        
                                        for theCriteria in groupCriteria! {
                                            criteriaName = theCriteria["name"] as! String
                                            if self.pkgScrArray.firstIndex(of: criteriaName) != nil {
                                                if criteriaArray.firstIndex(of: criteriaName) == nil {
                                                    criteriaArray.append(criteriaName)
                                                }
                                            }
                                        }
                                    
                                        if let displayFields = endpointInfo["display_fields"] as? [[String: Any]] {
                                            for theDisplayField in displayFields {
                                                let displayFieldName = theDisplayField["name"] as! String
                                                if self.pkgScrArray.firstIndex(of: displayFieldName) != nil {
                                                    if displayFieldsArray.firstIndex(of: displayFieldName) == nil {
                                                        displayFieldsArray.append(displayFieldName)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        self.detailedResults = "\(recordName)"
                                        WriteToLog.shared.message(stringOfText: "[getDetails] case computer_group - Group Name: \(recordName)")
                                    }

                                default:
                                    break
                                }

                                WriteToLog.shared.message(stringOfText: "[getDetails] singleEndpointXmlTag: \(singleEndpointXmlTag)")
                                WriteToLog.shared.message(stringOfText: "[getDetails]     selectedEndpoint: \(selectedEndpoint)")

                                switch singleEndpointXmlTag {
                                case "policy","computer_configuration","mac_application","os_x_configuration_profile","configuration_profile","mobile_device_application":
                                    for i in (0..<thePackageArray.count) {

//                                        print("[getDetails] package name in policy: \(String(describing: thePackageArray[i]["name"]!))")
//                                        print("      selectedEndpoint: \(String(describing: self.selectedEndpoint))")

                                        if let currentPayload = thePackageArray[i]["name"] as? String {
                                            //                                        let currentPayloadID = "\(String(describing: thePackageArray[i]["id"]!))"
                                            currentPolicyArray.append("\(recordName)")
                                            if let pkgIndex = self.pkgScrArray.firstIndex(of: "\(currentPayload)") {
                                                self.pkgScrArray.remove(at: pkgIndex)
                                            }
                                            
                                            switch selectedEndpoint {
                                                // format the data to the columns in the table
                                            case "policies":
                                                
                                                switch self.menuIdentifier {
                                                case "Packages","Printers","Scripts":
                                                    if self.selectedEndpoint != "computerconfigurations" {
                                                        summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "\(triggers)", column4: "\(freq)", column5: "", column6: "", column7: ""))
                                                        details_TextView.string.append("\(currentPayload)\t\(recordName)\t\(triggers)\t\(freq)\n")
                                                    } else {
                                                        summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "\(triggers)", column4: "", column5: "\(freq)", column6: "", column7: ""))
                                                        details_TextView.string.append("\(currentPayload)\t\(recordName)\t\(triggers)\t\t\(freq)\n")
                                                    }
                                                case "Policies-all":
                                                    summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "\(payloadArray)", column3: "\(triggers)", column4: "\(freq)", column5: "\(theScope)", column6: "\(limitationsExclusions["limitations"] ?? [])", column7: "\(limitationsExclusions["exclusions"] ?? [])"))
                                                    details_TextView.string.append("\(currentPayload)\t\(self.payloadArray)\t\(triggers)\t\(freq)\t\(self.theScope)\t\(limitationsExclusions["limitations"] ?? [])\t\(limitationsExclusions["exclusions"] ?? [])\n")
                                                case "apps_macOS","apps_iOS":
                                                    summaryArray.append(EndpointData(column1: "\(recordName)", column2: "\(managedDist)", column3: "\(self.theScope)", column4: "\(limitationsExclusions["limitations"] ?? [])", column5: "\(limitationsExclusions["exclusions"] ?? [])", column6: "", column7: ""))
                                                    details_TextView.string.append("\(recordName)\t\(managedDist)\t\(theScope)\t\(limitationsExclusions["limitations"] ?? [])\t\(limitationsExclusions["exclusions"] ?? [])\n")
                                                default:
                                                    summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "", column4: "\(triggers)", column5: "\(freq)", column6: "", column7: ""))
                                                    details_TextView.string.append("\(currentPayload)\t\(recordName)\t\t\(triggers)\t\(freq)\n")
                                                }
                                            case "macapplications":
                                                summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "", column3: "", column4: "", column5: "", column6: "\(recordName)", column7: ""))
                                                details_TextView.string.append("\(currentPayload)\t\t\t\t\t\(recordName)\n")
                                            case "mobiledeviceconfigurationprofiles":
                                                summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "", column4: "", column5: "", column6: "", column7: ""))
                                                details_TextView.string.append("\(currentPayload)\t\(recordName)\t\t\(triggers)\n")
                                            case "mobiledeviceapplications":
                                                summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "", column3: "\(recordName)", column4: "", column5: "", column6: "", column7: ""))
                                                details_TextView.string.append("\(currentPayload)\t\t\(recordName)\n")
                                            case "osxconfigurationprofiles":
                                                summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "", column3: "\(recordName)", column4: "", column5: "", column6: "", column7: ""))
                                                details_TextView.string.append("\(currentPayload)\t\t\(recordName)\n")
                                            case "computerconfigurations":
                                                summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "", column3: "", column4: "", column5: "\(recordName)", column6: "", column7: ""))
                                                details_TextView.string.append("\(currentPayload)\t\t\t\t\(recordName)\n")
                                            default:
                                                summaryArray.append(EndpointData(column1: "\(currentPayload)", column2: "", column3: "", column4: "\(recordName)", column5: "", column6: "", column7: ""))
                                                details_TextView.string.append("\(currentPayload)\t\t\t\(recordName)\n")
                                            }
                                            
                                            if self.menuIdentifier != "recon" && self.menuIdentifier.prefix(8) != "trigger_" {
                                                detailedResults = "\(currentPayload) \t\(recordName) \t\(triggers) \t\(freq)"
                                            }
                                        }
                                    }
//                                case "os_x_configuration_profile":
//                                    summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "", column4: "", column5: "", column6: "", column7: ""))
//                                    details_TextView.string.append("\(currentPayload)\t\t\(recordName)\n")
                                case "computer_group", "mobile_device_group":
                                    var eaType = ""
                                    for theCriteriaName in criteriaArray {
                                        if oSingleEndpointXmlTag.contains("_extension_attribute") {
                                            if let _ = objectByNameDict[theCriteriaName]?["input_type"]?["type"] {
                                                eaType = objectByNameDict[theCriteriaName]!["input_type"]!["type"] as! String
                                            } else {
                                                eaType = "unknown"
                                            }
                                        }
                                        summaryArray.append(EndpointData(column1: "\(theCriteriaName)", column2: "\(recordName)", column3: "", column4: "\(eaType)", column5: "", column6: "", column7: ""))
                                        details_TextView.string.append("\(theCriteriaName)\t\(recordName)\t\t\(eaType)\n")
                                    }
                                case "advanced_computer_search", "advanced_mobile_device_search":
                                    var eaType = ""
                                    for theCriteriaName in criteriaArray {
                                        print("\(theCriteriaName)")
                                        print("\(oSingleEndpointXmlTag)\n")
                                        if oSingleEndpointXmlTag.contains("_extension_attribute") {
                                            if let _ = objectByNameDict[theCriteriaName]?["input_type"]?["type"] {
                                                eaType = objectByNameDict[theCriteriaName]!["input_type"]!["type"] as! String
                                            } else {
                                                eaType = "unknown"
                                            }
                                        }
                                        summaryArray.append(EndpointData(column1: "\(theCriteriaName)", column2: "", column3: "\(recordName) (criteria)", column4: "\(eaType)", column5: "", column6: "", column7: ""))
                                        details_TextView.string.append("\(theCriteriaName)\t\t\(recordName) (criteria)\t\(eaType)\n")
                                    }
                                    // see if EA is used as a display field
                                    for displayFieldName in displayFieldsArray {
                                        print("[dispay field] name: \(displayFieldName)")
                                        print("[dispay field] oSingleEndpointXmlTag: \(oSingleEndpointXmlTag)")
                                        if oSingleEndpointXmlTag.contains("_extension_attribute") {
                                            if let _ = objectByNameDict[displayFieldName]?["input_type"]?["type"] {
                                                eaType = objectByNameDict[displayFieldName]!["input_type"]!["type"] as! String
                                            } else {
                                                eaType = "unknown"
                                            }
                                        }
                                        if summaryArray.firstIndex(where: { $0.column1 == displayFieldName && $0.column3 == "\(recordName) (criteria)" }) == nil {
                                            summaryArray.append(EndpointData(column1: "\(displayFieldName)", column2: "", column3: "\(recordName) (display)", column4: "\(eaType)", column5: "", column6: "", column7: ""))
                                            details_TextView.string.append("\(displayFieldName)\t\t\(recordName) (display)\t\(eaType)\n")
                                        }
                                    }
                                    
                                case "cp_all_iOS","cp_all_macOS":
                                    summaryArray.append(EndpointData(column1: "\(recordName)", column2: "\(payloadArray)", column3: "\(self.theScope)", column4: "\(limitationsExclusions["limitations"] ?? [])", column5: "\(limitationsExclusions["exclusions"] ?? [])", column6: "", column7: ""))
                                    details_TextView.string.append("\(recordName)\t\(payloadArray)\t\(theScope)\t\(limitationsExclusions["limitations"] ?? [])\t\(limitationsExclusions["exclusions"] ?? [])\n")
//                                case "osxconfigurationprofiles":
//                                    summaryArray.append(endpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "\(theRecord[2])", column4: "\(limitationsExclusions["limitations"] ?? [])", column5: "\(limitationsExclusions["exclusions"] ?? [])", column6: "", column7: ""))
//                                    details_TextView.string.append("\(recordName)\t\(payloadArray)\t\(theScope)\t\(limitationsExclusions["limitations"] ?? [])\t\(limitationsExclusions["exclusions"] ?? [])\n")
                                default:
                                    break
                                }


                            } else {
                                WriteToLog.shared.message(stringOfText: "getDetails: if let endpointInfo = endpointJSON[\(self.singleEndpointXmlTag)], id='\(id)' error.)\n\(idUrl)")
                            }
                        }  else {  // if let serverEndpointJSON - end
                            WriteToLog.shared.message(stringOfText: "getDetails - existing endpoints: error serializing JSON: \(String(describing: error))")
                        }
//                    }   // end do

                        let theRecord: [String] = "\(detailedResults)".components(separatedBy: "\t")
                        WriteToLog.shared.message(stringOfText: "[getDetails] endpointType: \(endpointType), theRecord: \(theRecord)")

                        if endpointType != "Policies-all" && endpointType != "Packages" && endpointType != "Printers" && endpointType != "Scripts" && menuIdentifier != "scg" && menuIdentifier != "sdg" && menuIdentifier != "cp_all_iOS" && menuIdentifier != "cp_all_macOS" {
                            WriteToLog.shared.message(stringOfText: "[getDetails] \(recordName) is using theRecord with theRecord.count = \(theRecord.count)")
                            switch theRecord.count {
                            case 5:
                                summaryArray.append(EndpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "\(theRecord[2])", column4: "\(theRecord[3])", column5: "\(theRecord[4])", column6: "", column7: ""))
                                details_TextView.string.append("\(theRecord[0])\t\(theRecord[1])\t\(theRecord[2])\t\(theRecord[3])\t\(theRecord[4])\n")
                            case 4:
                                summaryArray.append(EndpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "\(theRecord[2])", column4: "\(theRecord[3])", column5: "", column6: "", column7: ""))
                                details_TextView.string.append("\(theRecord[0])\t\(theRecord[1])\t\(theRecord[2])\t\(theRecord[3])\n")
                            case 3:
                                print("case 3")
                                if theRecord[0] != "" {
                                    summaryArray.append(EndpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "\(theRecord[2])", column4: "", column5: "", column6: "", column7: ""))
                                    details_TextView.string.append("\(theRecord[0])\t\(theRecord[1])\t\(theRecord[2])\n")
                                }
                            case 2:
                                if theRecord[0] != "" {
                                    summaryArray.append(EndpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "", column4: "", column5: "", column6: "", column7: ""))
                                    details_TextView.string.append("\(theRecord[0])\t\(theRecord[1])\n")
                                }
                            default: break

                            }

                        }
                        
//                        print("returning from: \(idUrl)\n")
//                        print("getDetails - theRecord: \(theRecord)")
                        completion(detailedResults)
                    } else {
                        // something went wrong
                        WriteToLog.shared.message(stringOfText: "[getDetails] lookup failed for \(idUrl)")
                        WriteToLog.shared.message(stringOfText: "[getDetails] status code: \(httpResponse.statusCode)")
                        Log.FailedCount+=1
                        Log.lookupFailed = true
                        completion(detailedResults)
                    }   // if httpResponse.statusCode - end
                } else {   // if let httpResponse = response - end
                    DispatchQueue.main.async {
                        self.progressBar.increment(by: 1.0)
                    }
                    WriteToLog.shared.message(stringOfText: "[getDetails] lookup failed, no response for: \(idUrl)")
                    Log.FailedCount+=1
                    Log.lookupFailed = true
                }
//                semaphore.signal()
                self.completeCounter[theEndpoint]!+=1
                WriteToLog.shared.message(stringOfText: "[getDetails] completeCounter: \(String(describing: self.completeCounter[theEndpoint]!)) of \(self.apiDetailCount[theEndpoint]!)")

                if (self.completeCounter[theEndpoint]! >= self.apiDetailCount[theEndpoint]!) {
                    if !(self.selectedEndpoint == "osxconfigurationprofiles" && self.menuIdentifier == "scg") {
                        WriteToLog.shared.message(stringOfText: "[getDetails] queryComplete")
                        self.queryComplete()
                    }
                }
            })   // let task = serverSession.dataTask - end
            task.resume()
//            semaphore.wait()
        }   // detailQ - end
    }   // func getDetails - end
    
//    func copy(sender: AnyObject?){
//        
//        var textToDisplayInPasteboard = ""
//        let indexSet = tableView.selectedRowIndexes
//        print("indexSet: \(indexSet)")
//        for (_, rowIndex) in indexSet.enumerated() {
//            var iterator: CoreDataObjectTypes
//            iterator=tableDataSource.objectAtIndex(rowIndex)
//            textToDisplayInPasteboard = (iterator.name)!
//        }
//        let pasteBoard = NSPasteboard.general()
//        pasteBoard.clearContents()
//        pasteBoard.setString(textToDisplayInPasteboard, forType:NSPasteboardTypeString)
//
//    }
    
    func alert_dialog(header: String, message: String) {
        let dialog: NSAlert    = NSAlert()
        dialog.messageText     = header
        dialog.informativeText = message
        dialog.alertStyle      = NSAlert.Style.warning
        dialog.addButton(withTitle: "OK")
        dialog.runModal()
        //return true
    }   // func alert_dialog - end
    
    func queryComplete() {
        spinner.stopAnimation(self)
        stop_button.isHidden         = true
        export_button.isEnabled      = true
        export_button.keyEquivalent  = "\r"
        progressBar.isHidden         = true
        action_textField.stringValue = ""
//        action_textField.stringValue = "Search Complete"
        isRunning                    = false
        //get_button.isEnabled         = true
        if Log.lookupFailed {
            let query = Log.FailedCount == 1 ? "query":"queries"
            alert_dialog(header: "Attention", message: "\(Log.FailedCount) \(query) failed.\nCheck the log, ~/Library/Logs/ObjectInfo/, and search for '[getDetails] lookup failed' to get additional details.")
            Log.lookupFailed = false
        }
    }
    
    // convert an array to a comma delimited string - start
    func triggersAsString(generalTag: [String : AnyObject]) -> String {
        var elementList = ""
        
        var elementArray = [String]()
        generalTag["trigger_checkin"] as? Bool ?? false ? elementArray.append("checkin"):(_ = "")
        generalTag["trigger_enrollment_complete"] as? Bool ?? false ? elementArray.append("Enrollment Complete"):(_ = "")
        generalTag["trigger_login"] as? Bool ?? false ? elementArray.append("login"):(_ = "")
        generalTag["trigger_logout"] as? Bool ?? false ? elementArray.append("logout"):(_ = "")
        generalTag["trigger_network_state_changed"] as? Bool ?? false ? elementArray.append("Network State Change"):(_ = "")
        generalTag["trigger_startup"] as? Bool ?? false ? elementArray.append("startup"):(_ = "")
        generalTag["trigger_other"] as? String != nil ? elementArray.append("\(String(describing: generalTag["trigger_other"]!))"):(_ = "")
        
        for element in elementArray {
            if elementList != "" && element != "" {
                elementList.append(", \(element)")
            } else {
                elementList.append("\(element)")
            }
        }
        return elementList
    }
    // convert an array to a comma delimited string - end
    
    // remove policy entries generated by jamf remote - start
    func validEndpointInfo(endpointJSON: [String: Any], endpoint: String) -> [Any] {
        WriteToLog.shared.message(stringOfText: "[validEndpointInfo] endpoint: \(endpoint)")
        var filtered    = [Any]()
        var tmpFiltered = filtered
//        var tmpPolicyNames = [String]()
        
        switch endpoint {
        case "policies":
            WriteToLog.shared.message(stringOfText: "[validEndpointInfo] filter out policies from Jamf Remote")
            tmpFiltered = endpointJSON[endpoint] as! [Any]
            for i in (0..<tmpFiltered.count) {
                let localRecord = tmpFiltered[i] as! [String : AnyObject]
                let recordName  = localRecord["name"] as! String
                if recordName.range(of:"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] at", options: .regularExpression) == nil {
                    // policy was generated from jamf remote, remove it
                    filtered.append(localRecord)
//                    tmpPolicyNames.append(recordName)
                }
            }
/*
        case "computer_groups","mobile_device_groups": // this used?
            print("[validEndpointInfo] finding smart \(endpoint)")
            tmpFiltered = endpointJSON[endpoint] as! [Any]
            for i in (0..<tmpFiltered.count) {
                let localRecord = tmpFiltered[i] as! [String : AnyObject]
                let is_smart = localRecord["is_smart"] as! Bool
                if is_smart {
                    // is a smart group
                    filtered.append(localRecord)
//                    tmpPolicyNames.append(recordName)
                }
            }
 */
        default:
            WriteToLog.shared.message(stringOfText: "[validEndpointInfo] filtered: \(filtered)")
            filtered = endpointJSON[endpoint] as! [Any]
        }

        return filtered
    }
    // remove policy entries generated by jamf remote - end
    
    func formatTableView(columnHeaders: [String]) {
        DispatchQueue.main.async { [self] in
            let tableWidth = CGFloat(tableView.frame.size.width)
            var tableColumn: NSTableColumn?
            var columnHeader: NSTableHeaderCell
            let numberOfColumns = columnHeaders.count
           
            for i in (0..<numberOfColumns) {
                tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "column\(i+1)"))
                columnHeader = (tableColumn?.headerCell)!
                columnHeader.title = "\(columnHeaders[i])"
                columnHeader.alignment = .center
                if columnHeader.title == "Limitations" || columnHeader.title == "Exclusions" {
                    tableColumn?.headerToolTip = "user groups only"
                }
    //            tableColumn?.self.tableView!.alignment = .natural
                tableColumn?.width = tableWidth/CGFloat(numberOfColumns+1)
                tableColumn?.tableView?.alignment = .natural
                tableColumn?.isHidden = false
                usleep(10000)
            }
            for j in (numberOfColumns..<7) {
                tableColumn  = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "column\(j+1)"))
                columnHeader = (tableColumn?.headerCell)!
                columnHeader.title = ""
                tableColumn?.tableView?.alignment = .natural
                tableColumn?.width = 0.0
                tableColumn?.isHidden = true
            }
        }
    }
    
    func getLimitationsExceptions(endpointInfo: [String : AnyObject], endpointType: String) -> [String:[String]] {
//        WriteToLog.shared.message(stringOfText: "[getLimitationsExceptions] endpointInfo: \(endpointInfo)")
//        WriteToLog.shared.message(stringOfText: "[getLimitationsExceptions] scopeObjects: \(scopeObjects)")
        
        var limitationsExclusionsDict = [String:[String]]()

        WriteToLog.shared.message(stringOfText: "[getLimitationsExceptions] endpointType: \(endpointType)")

        if let scope = endpointInfo["scope"] as? [String : AnyObject] {
            for lore in ["limitations", "exclusions"] {
                var currentList = [String]()
                if let limitationsExclusions = scope[lore] as? [String: AnyObject] {
                    if let groupDict = limitationsExclusions["user_groups"] as? [[String:String]] {
                        for groupInfo in groupDict {
                            if let groupName = groupInfo["name"] {
                                currentList.append(groupName)
                            }
                        }
                    }
                }
                limitationsExclusionsDict[lore] = currentList
                self.detailedResults.append("\t\(limitationsExclusionsDict[lore] ?? [])")
            }
            
        }
        return limitationsExclusionsDict
    }
    
    func getScope(endpointInfo: [String : AnyObject], scopeObjects: [String]) {
//        WriteToLog.shared.message(stringOfText: "[getScope] endpointInfo: \(endpointInfo)")
//        WriteToLog.shared.message(stringOfText: "[getScope] scopeObjects: \(scopeObjects)")
        
        var allScope            = ""
        var currentScopeArray   = [String]()

        WriteToLog.shared.message(stringOfText: "[getScope] endpointType: \(endpointType)")

        switch endpointType {
        case "ios_cp","sdg","apps_iOS","cp_all_iOS":
            allScope = "all_mobile_devices"
            self.theScope = "All iOS Devices"
        default:
            allScope = "all_computers"
            self.theScope = "All Computers"
        }
        
        if let scope = endpointInfo["scope"] as? [String : AnyObject] {
            if scope["\(allScope)"] as! Bool {
//                print("[getScope] scoped to All")
//                self.detailedResults.append(" \tAll Computers")
                switch self.endpointType {
                case "ios_cp":
//                    self.detailedResults.append(" \tAll iOS Devices")
                    currentScopeArray.append("group: \(String(describing: self.theScope))")
                default:
//                    self.detailedResults.append(" \tAll Computers")
//                    self.theScope = "All Computers"
                    currentScopeArray.append("group: \(String(describing: self.theScope))")
                }
            } else {
//                let scopeObjects = ["computers", "computer_groups", "buildings", "departments"]
                for scopeObject in scopeObjects {
                    var scopeObjectArray = [String]()
                    if let scopeArray = scope[scopeObject] as? [Any] {
                        for i in (0..<scopeArray.count) {
                            let theRecord  = scopeArray[i] as! [String : AnyObject]
                            var recordName = theRecord["name"] as! String
                            recordName = recordName.replacingOccurrences(of: "\'", with: "'")
                            scopeObjectArray.append(recordName)
                        }
                        if scopeObjectArray.count > 0 {
                            scope[scopeObject] != nil ? currentScopeArray.append("\(scopeObject):\(String(describing: scopeObjectArray))") : ()
                        }
                    }
                    
                }
            }   // else - end
            // convert array to comma seperated list (newline not working)
            var scopeList = "[]"
            for scopeItem in currentScopeArray {
                if scopeList != "[]" {
                    scopeList.append(", \(scopeItem)")
                } else {
                    scopeList = "\(scopeItem)"
//                    scopeList.append("\(scopeItem)")
                }
            }
//            if scopeList == "" { scopeList = "[]" }
//            print("[getScope] scopeList: \(scopeList)")
            self.detailedResults.append("\t\(scopeList)")  // remove this at some point, replace references with 'theScope'?
//            print("[getScope] self.detailedResults: \(self.detailedResults)")
            self.theScope = scopeList
        }
    }
    
    @IBAction func export_action(_ sender: NSButton) {
//        print(details_TextView.string ?? "Nothing found.")
        
        let savePanel = NSSavePanel()
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first! as URL
        savePanel.nameFieldStringValue = oSelectedEndpoint+exportTitleSuffix+".txt"
        savePanel.title = "Choose output file"
        savePanel.showsResizeIndicator = true
        savePanel.showsHiddenFiles = false
        savePanel.canCreateDirectories = true
        savePanel.treatsFilePackagesAsDirectories = false
        let answer = savePanel.runModal()
        if answer ==  NSApplication.ModalResponse.OK {
            var exportPath = ""
            if #available(macOS 13.0, *) {
                exportPath = (savePanel.url?.path())!
            } else {
                exportPath = savePanel.url!.path
            }
            
            if !fm.fileExists(atPath: exportPath) {
            //                    print("export file does not exist, creating.")
                fm.createFile(atPath: exportPath, contents: nil, attributes: nil)
            } else {
                do {
                    try fm.removeItem(atPath: exportPath)
                    fm.createFile(atPath: exportPath, contents: nil, attributes: nil)
                } catch {
                    alert_dialog(header: "Alert:", message: "Unable to replace exiting file.")
                    return
                }
            }
            
            do {
                let exportHandle = try FileHandle(forWritingTo: savePanel.url!)
            
                let exportData = details_TextView.string.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                exportHandle.write(exportData!)
            } catch {
                alert_dialog(header: "Alert:", message: "Unable to export data.")
            }
            // Do whatever you need with every selected file
            print ("\(exportPath)")
        } else {
            print ( "User clicked on 'Cancel'" )
            return
        }
    }
    
    func queueCheck(completion: @escaping (_ result: Bool) -> Void) {
        theGeneralQ.async {
            while self.pendingCount > 10 {
//                print("\npending: \(self.pendingCount)\n")
                sleep(1)
            }
        }
        completion(true)
    }
    
    /*
    @IBAction func saveCreds_action(_ sender: Any) {
        if saveCreds_button.state.rawValue == 1 {
            preferencesDict["save_pwd"] = 1 as AnyObject
        } else {
            preferencesDict["save_pwd"] = 0 as AnyObject
        }
    }
    */
    
    @IBAction func showLogFolder(_ sender: Any) {
        var isDir: ObjCBool = true
        if (self.fm.fileExists(atPath: Log.path!, isDirectory: &isDir)) {
//            NSWorkspace.shared.openFile(Log.path!)
            NSWorkspace.shared.open(URL(fileURLWithPath: Log.path!))
        } else {
            alert_dialog(header: "Alert", message: "Log directory cannot be found.")
        }
    }
    
    
    @IBAction func stop_action(_ sender: Any) {
        print("[stop_action] clicked")
        stopScan = true
        apiQ.cancelAllOperations()
        detailQ.cancelAllOperations()
        getDetailsArray.removeAll()
        stop_button.isHidden    = true
        export_button.isEnabled  = true
        export_button.keyEquivalent = "\r"
//        details_TextView.string = ""
        spinner.stopAnimation(self)
        self.action_textField.stringValue = "Stopped lookups"
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        let loginVC: LoginVC = segue.destinationController as! LoginVC
        loginVC.delegate = self
//        print("[viewController.prepare] nextStep: \(nextCheck) for \(String(describing: segue.identifier))")
        if segue.identifier == "loginWindow" {
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //create log file
        Log.file = getCurrentTime().replacingOccurrences(of: ":", with: "") + "_" + Log.file
        if !(FileManager.default.fileExists(atPath: Log.path! + Log.file)) {
            FileManager.default.createFile(atPath: Log.path! + Log.file, contents: nil, attributes: nil)
        }
        WriteToLog.shared.logCleanup()
        
//        self.view.layer?.backgroundColor = CGColor(red: 0x5C/255.0, green: 0x78/255.0, blue: 0x94/255.0, alpha: 1.0)
        stop_button.isHidden = true
        // Do any additional setup after loading the view.
        let additional = "-._~/?"
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: additional)
    }
    
    override func viewDidAppear() {

//        connectedTo_TextField.becomeFirstResponder()
        //get_button.isEnabled        = false
        spinner.isHidden            = true
        export_button.isEnabled     = false
        
        let settings_plist  = Bundle.main.path(forResource: "settings", ofType: "plist")!
        var isDir: ObjCBool = true

        // app version info
        let appInfo = Bundle.main.infoDictionary!
        let version = appInfo["CFBundleShortVersionString"] as! String

        // OS version info
        let os = ProcessInfo().operatingSystemVersion
        
        // Create Application Support folder for the app if missing - start
        let app_support_path = NSHomeDirectory() + "/Library/Application Support/Object Info"
        if !(fm.fileExists(atPath: app_support_path, isDirectory: &isDir)) {
            let manager = FileManager.default
            do {
                try manager.createDirectory(atPath: app_support_path, withIntermediateDirectories: true, attributes: nil)
            } catch {
//                if self.debug { self.writeToLog(stringOfText: "Problem creating '/Library/Application Support/Object Info' folder:  \(error)") }
            }
        }
        // Create Application Support folder for the app if missing - end
        
        // Create preference file if missing - start
        isDir = false
        if !(fm.fileExists(atPath: NSHomeDirectory() + "/Library/Application Support/Object Info/settings.plist", isDirectory: &isDir)) {
            do {
                try fm.copyItem(atPath: settings_plist, toPath: NSHomeDirectory() + "/Library/Application Support/Object Info/settings.plist")
            }
            catch let error as NSError {
//                if self.debug { self.writeToLog(stringOfText: "Failed creating default settings.plist! Something went wrong: \(error)") }
                alert_dialog(header: "Error:", message: "Failed creating default settings.plist.\nError \(error)")
                exit(0)
            }
        }
        // Create preference file if missing - end
        
        preferencesDict = (NSDictionary(contentsOf: prefsPath) as? [String : AnyObject])!

        WriteToLog.shared.message(stringOfText: "")
        WriteToLog.shared.message(stringOfText: "================================")
        WriteToLog.shared.message(stringOfText: "  Object Info Version: \(version)")
        WriteToLog.shared.message(stringOfText: "        macOS Version: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        WriteToLog.shared.message(stringOfText: "================================")
        
        if showLoginWindow {
            performSegue(withIdentifier: "loginView", sender: nil)
            showLoginWindow = false
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // needed, along with Info.plist changes, to connect to servers using untrusted certificates
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }

}
