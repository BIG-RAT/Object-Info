//
//  ViewController.swift
//  Object Info
//
//  Created by Leslie Helou on 8/16/17.
//  Copyright © 2017 jamf. All rights reserved.
//

import Cocoa
import Foundation
//import WebKit

class endpointData: NSObject {
    @objc dynamic var column1: String
    @objc dynamic var column2: String
    @objc dynamic var column3: String
    @objc dynamic var column4: String
    @objc dynamic var column5: String
    @objc dynamic var column6: String
    
    init(column1: String, column2: String, column3: String, column4: String, column5: String, column6: String) {
        self.column1 = column1
        self.column2 = column2
        self.column3 = column3
        self.column4 = column4
        self.column5 = column5
        self.column6 = column6
    }
}

class ViewController: NSViewController, URLSessionDelegate {

    @objc dynamic var summaryArray: [endpointData] = [endpointData(column1: "", column2: "", column3: "", column4: "", column5: "", column6: "")]

    // keychain access
//    let Creds = Credentials()
    let Creds = Credentials2()
    
    @IBOutlet weak var saveCreds_button: NSButton!
    
    let fm = FileManager()
    var preferencesDict = [String:AnyObject]()
    let prefsPath = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Object Info/settings.plist")

    @IBOutlet weak var jamfServer_TextField: NSTextField!
    @IBOutlet weak var uname_TextField: NSTextField!
    @IBOutlet weak var passwd_TextField: NSSecureTextField!
    
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
    
    let endpointDict = ["recon":            ["policies","policies","policy"],
                        "Network Segments": ["networksegments","network_segments","network_segment"],
                        "Packages":         ["packages","packages","package"],
                        "Scripts":          ["scripts","scripts","script"],
                        "scg":              ["computergroups","computer_groups","computer_group"],
                        "sdg":              ["mobiledevicegroups","mobile_device_groups","mobile_device_group"],
                        "mac_cp":           ["osxconfigurationprofiles","os_x_configuration_profiles","os_x_configuration_profile"],
                        "ios_cp":           ["mobiledeviceconfigurationprofiles","configuration_profiles","configuration_profile"]]
    
    var headersDict = ["recon":            ["Policy","Trigger","Scope"],
                       "Network Segments": ["Segment Name","Start Address","End Address","Default Share","URL"],
                       "Packages":         ["Package Name","Policy","Trigger","Frequency","Configuration"],
                       "Scripts":          ["Script Name","Policy","Trigger","Frequency","Configuration"],
                       "scg":              ["Group Name","Policy","Profile","Trigger","Frequency","App"],
                       "sdg":              ["Group Name","Profile","App"],
                       "mac_cp":           ["Payload Type","Profile Name","Scope"]]
    
    var currentServer           = ""
    var username                = ""
    var password                = ""
    
    var displayResults          = ""
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
    var completeCounter         = 0
    var apiDetailCount          = 0     // number of objects to look up
    var increment               = 0.0
    var pendingCount            = 0     // number of requests waiting for a response
    
    var apiQ            = OperationQueue()
    var detailQ         = OperationQueue()
    var authQ           = DispatchQueue(label: "com.jamf.auth")
    var theGeneralQ     = DispatchQueue(label: "com.jamf.general", qos: DispatchQoS.utility) // OperationQueue()
    var theDetailQ      = DispatchQueue(label: "com.jamf.detail", qos: DispatchQoS.utility)
    var theSpinnerQ     = DispatchQueue(label: "com.jamf.spinner", qos: DispatchQoS.background)
    
    
    @IBAction func selectedItem_MenuItem(_ sender: NSMenuItem) {
//        print("sender title: \(sender.title)")
        menuTitle           = "\(sender.title)"
        menuIdentifier      = "\(sender.identifier?.rawValue ?? "")"
        print("menuIdent: \(menuIdentifier)")
        
        switch menuIdentifier {
        case "mac_passcode","mac_network","mac_vpn","mac_cert","mac_scep","mac_dir","mac_kext","mac_su","mac_restrict","mac_loginitems","mac_loginwindow","mac_dock","mac_mobility","mac_print","mac_sec-priv","mac_ad-cert","mac_sysext":
            endpointType = "mac_cp"
            select_MenuItem.title = "macOS-"+menuTitle
        case "ios_passcode","ios_restrict","ios_wifi","ios_vpn","ios_mail","ios_eas","ios_google","ios_sam","ios_webclip","ios_hsl":
            endpointType = "ios_cp"
            select_MenuItem.title = "iOS-"+menuTitle
            headersDict["ios_cp"]  = headersDict["mac_cp"]
        case "scg","sdg":    // added sdg lnh - 201205
            endpointType = menuIdentifier
            select_MenuItem.title = menuTitle+" Groups"
            //headersDict["sdg"]  = headersDict["scg"]
        default:
            endpointType = menuIdentifier
            select_MenuItem.title = menuTitle
        }
        
        if menuIdentifier != "" {
            get_button.isEnabled    = true
            export_button.isEnabled = false
            let selection = endpointDict[endpointType]!

            WriteToLog().message(stringOfText: ["endpointDict[\(endpointType)]: \(endpointDict[endpointType]!)"])

            oSelectedEndpoint       = "\(selection[0])"
            oEndpointXmlTag         = "\(selection[1])"
            oSingleEndpointXmlTag   = "\(selection[2])"
            
            self.action_textField.stringValue = ""
            formatTableView(columnHeaders: headersDict[endpointType]!)
            
            endpoint_PopUpButton.select(select_MenuItem)
            summaryArray.removeAll()
            tableView.reloadData()
            progressBar.isHidden = true
            progressBar.increment(by: -100.0)
        } else {
            endpointXmlTag   = ""
        }
    }


    @IBAction func get(_ sender: Any) {
        if jamfServer_TextField.stringValue == "" {
            alert_dialog(header: "Alert", message: "Jamf server URL is required.")
            jamfServer_TextField.becomeFirstResponder()
            return
        } else if uname_TextField.stringValue == "" {
            alert_dialog(header: "Alert", message: "Jamf server username is required.")
            uname_TextField.becomeFirstResponder()
            return
        } else if passwd_TextField.stringValue == "" {
            alert_dialog(header: "Alert", message: "Jamf server user password is required.")
            uname_TextField.becomeFirstResponder()
            return
        }
        
        selectedEndpoint       = oSelectedEndpoint  //ex: .../JSSResource/selectedEndpoint
        endpointXmlTag         = oEndpointXmlTag
        singleEndpointXmlTag   = oSingleEndpointXmlTag
        if endpointXmlTag != "" {
            get_button.isEnabled = false
            var theRecordArray   = [String]()
            
            summaryArray.removeAll()
            self.details_TextView.string = ""
            
            for exportHeader in headersDict[endpointType]! {
                self.details_TextView.string.append(exportHeader+"\t")
            }
            self.details_TextView.string.append("\n")

            self.results_TextView.string = ""
            displayResults               = ""
            allDetailedResults           = ""
            packageScriptArray.removeAll()
            pkgScrArray.removeAll()

            WriteToLog().message(stringOfText: ["[get] apiCall for endpoint: \(endpointXmlTag)"])
            WriteToLog().message(stringOfText: ["[get] apiCall for menuIdentifier: \(menuIdentifier)"])

            apiCall(endpoint: "\(endpointXmlTag)") {
                (result: String) in
                WriteToLog().message(stringOfText: ["[get] returned from apiCall - result:\n\(result)"])

                self.results_TextView.string = "\(result)"
                if self.menuIdentifier == "Packages" || self.menuIdentifier == "Scripts" || self.menuIdentifier == "scg" || self.menuIdentifier == "sdg" {
                    
                    self.packageScriptArray = "\(result)".components(separatedBy: "\n")
//                    WriteToLog().message(stringOfText: ["packageScriptArray: \(self.packageScriptArray)")
                    for theRecord in self.packageScriptArray {
                        theRecordArray = theRecord.components(separatedBy: "\t")
                        if theRecordArray.count == 2 {
                            WriteToLog().message(stringOfText: ["[get] theRecord: \(theRecordArray[1])"])
//                            print("\(self.singleEndpointXmlTag) name: \(theRecordArray[1])")
                            self.pkgScrArray.append("\(theRecordArray[1])")
                        }
                    }
                    if self.menuIdentifier != "sdg" {
                        // switch lookup to packages/scripts scoped to policies - start
                        WriteToLog().message(stringOfText: ["[get] apiCall for endpoint: policies"])
                        self.selectedEndpoint     = "policies"
                        self.singleEndpointXmlTag = "policy"
                        self.apiCall(endpoint: "policies") {
                            (result: String) in
                            self.results_TextView.string = "\(result)"
    //                        print("apiCall done with policies?\n\(result)\n")
                        }
                        // switch lookup to packages/scripts scoped to policies - end
                    } else {
                        // switch lookup to mobile device groups scoped to configuration profiles - start
                        WriteToLog().message(stringOfText: ["[get] apiCall for endpoint: configuration_profiles"])
                        self.selectedEndpoint     = "mobiledeviceconfigurationprofiles"
                        self.singleEndpointXmlTag = "configuration_profile"
                        self.apiCall(endpoint: "configuration_profiles") {
                            (result: String) in
                            self.results_TextView.string = "\(result)"
    //                        print("apiCall done with policies?\n\(result)\n")
                        }
                        // switch lookup to mobile device groups scoped to configuration profiles - end
                    }
                }
            }
        }
    }
    
    @IBAction func QuitNow(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    func apiCall(endpoint: String, completion: @escaping (_ result: String) -> Void) {
        WriteToLog().message(stringOfText: ["[apiCall] endpoint: \(endpoint)"])

        completeCounter = 0
        progressBar.increment(by: -1.0)

        apiQ.maxConcurrentOperationCount = 4
        let semaphore = DispatchSemaphore(value: 0)
//        let semaphore = DispatchSemaphore(value: 1)   // used with theGeneralQ
        var localCounter = 0    // not needed?
        
//        let safeCharSet = CharacterSet.alphanumerics
        
        self.currentServer   = self.jamfServer_TextField.stringValue
        self.username        = self.uname_TextField.stringValue     //.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        self.password        = self.passwd_TextField.stringValue    //.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        let jamfCreds        = "\(self.username):\(self.password)"
        
        let jamfUtf8Creds    = jamfCreds.data(using: String.Encoding.utf8)
        let jamfBase64Creds  = (jamfUtf8Creds?.base64EncodedString())!
        
        if self.selectedEndpoint != "" {
            WriteToLog().message(stringOfText: ["[apiCall] selectedEndpoint: \(self.selectedEndpoint)"])
            self.endpointUrl = self.jamfServer_TextField.stringValue + "/JSSResource/\(self.selectedEndpoint)"
            self.endpointUrl = self.endpointUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            WriteToLog().message(stringOfText: ["[apiCall] endpointURL: \(endpointUrl)"])
        } else {
            completion("no endpoint selected")
        }
        
        apiQ.addOperation {

            let encodedURL = NSURL(string: self.endpointUrl)
            let request = NSMutableURLRequest(url: encodedURL! as URL)
            
            request.httpMethod = "GET"
            let serverConf = URLSessionConfiguration.default
            serverConf.httpAdditionalHeaders = ["Authorization" : "Basic \(jamfBase64Creds)", "Content-Type" : "application/json", "Accept" : "application/json"]
            URLCache.shared.removeAllCachedResponses()
            let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = serverSession.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
                    do {
                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json as? [String: Any] {
                            let endpointInfo = self.validEndpointInfo(endpointJSON: endpointJSON, endpoint: endpoint)
                            //print("[apiCall] endpointInfo: \(endpointInfo)")

                            self.apiDetailCount = endpointInfo.count
                            if (self.apiDetailCount > 0) {
                                // start things in motion
                                self.spinner.isHidden = false
                                self.spinner.startAnimation(self)

                                self.stop_button.isHidden = false
                                self.progressBar.isHidden = false
                                self.progressBar.maxValue = 1.0
                                self.increment = 1.0/Double(self.apiDetailCount)
                                
                                // display what is being search
                                switch self.selectedEndpoint {
                                case "policies","packages","scripts","computergroups":
                                    self.action_textField.stringValue = "Searching policies"
                                case "computerconfigurations":
                                    self.action_textField.stringValue = "Searching computer configurations"
                                case "osxconfigurationprofiles":
                                    self.action_textField.stringValue = "Searching macOS configuration profiles"
                                case "mobiledeviceconfigurationprofiles","mobiledevicegroups":
                                    self.action_textField.stringValue = "Searching mobile configuration profiles"
                                case "macapplications":
                                    self.action_textField.stringValue = "Searching macOS apps"
                                case "mobiledeviceapplications":
                                    self.action_textField.stringValue = "Searching mobile apps"
                                default:
                                    self.action_textField.stringValue = ""
                                }

                            } else {
                                self.alert_dialog(header: "Alert", message: "Nothing found at:\n\(self.endpointUrl)")
                                if self.selectedEndpoint == "computerconfigurations" || self.selectedEndpoint == "macapplications" {
//                                    self.increment = 100.0
//                                    self.apiDetailCount = self.completeCounter
                                    self.queryComplete()
                                }
                                WriteToLog().message(stringOfText: ["[apiCall] completion - Nothing found at: \(self.endpointUrl)"])
                                completion("")
                            }
                
                            for i in (0..<endpointInfo.count) {
                            
                                let theRecord  = endpointInfo[i] as! [String : AnyObject]
                                let recordId   = theRecord["id"] as! Int
                                let recordName = theRecord["name"] as! String
                            
                                self.displayResults.append("\(recordId)\t\(recordName)\n")

                                //print("[apiCall] switch endpoint: \(endpoint)")
                                switch endpoint {
                                    case "network_segments","os_x_configuration_profiles":
                                        self.getDetails(id: "\(recordId)") {
                                            (result: String) in
                                            self.allDetailedResults.append("\(result)")
                                            localCounter+=1
                                            if localCounter == endpointInfo.count && self.menuIdentifier == "scg" {
                                                // start looping through macapplications - start
                                                self.selectedEndpoint     = "macapplications"
                                                self.singleEndpointXmlTag = "mac_application"
                                                self.apiCall(endpoint: "mac_applications") {
                                                    (result: String) in
                                                    self.results_TextView.string = "\(result)"
//                                                  print("apiCall done with mobile device applications?\n\(result)\n")
                                                }
                                            }
                                        }
                                    case "mac_applications":
                                        self.getDetails(id: "\(recordId)") {
                                            (result: String) in
                                            self.allDetailedResults.append("\(result)")
                                        }
                                    case "policies":    // used for packages and scripts
    //                                        print("policy: \(recordName)")
                                        self.getDetails(id: "\(recordId)") {
                                            (result: String) in
                                            self.allDetailedResults.append("\(result)")
                                            localCounter+=1
    //                                                print("localCounter: \(localCounter) \tarray count: \(endpointInfo.count)")
                                            if localCounter == endpointInfo.count {
                                                // display packages and script not attached to any policies
                                                
    //                                            if self.menuIdentifier != "recon" {
                                                switch self.menuIdentifier {
                                                    case "Packages","Scripts":
                                                        // start looping through configurations - start
                                                        self.selectedEndpoint = "computerconfigurations"
                                                        self.singleEndpointXmlTag = "computer_configuration"
                                                        self.apiCall(endpoint: "computer_configurations") {
                                                            (result: String) in
                                                            self.results_TextView.string = "\(result)"
    //                                                      print("apiCall done with configurations?\n\(result)\n")
                                                        }
                                                    case "scg":
                                                        // start looping through configurations - start
                                                        self.selectedEndpoint = "osxconfigurationprofiles"
                                                        self.singleEndpointXmlTag = "os_x_configuration_profile"
                                                        self.apiCall(endpoint: "os_x_configuration_profiles") {
                                                            (result: String) in
                                                            self.results_TextView.string = "\(result)"
        //                                                  print("apiCall done with configurations?\n\(result)\n")
                                                            }
                                                    default:
                                                        break
                                                }
    //                                            }   // if self.menuIdentifier != "recon" - end
                                            }
                                        }
                                    case "computer_configurations":
                                        self.getDetails(id: "\(recordId)") {
                                            (result: String) in
                                            self.allDetailedResults.append("\(result)")
                                            if localCounter == endpointInfo.count { //i == (endpointInfo.count-1) {
                                                // display packages and script not attached to any policies
                                                for unused in self.pkgScrArray {
                                                    self.summaryArray.append(endpointData(column1: unused, column2: "", column3: "", column4: "", column5: "", column6: ""))
                                                }
                                            }
                                        }

                                    case "configuration_profiles":  // added 201207 lnh
                                         self.getDetails(id: "\(recordId)") {
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
                                                             (result: String) in
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
                                        self.getDetails(id: "\(recordId)") {
                                            (result: String) in
                                            self.allDetailedResults.append("\(result)")
                                            if localCounter == endpointInfo.count { //i == (endpointInfo.count-1) {
                                                // display packages and script not attached to any policies
                                                for unused in self.pkgScrArray {
                                                    self.summaryArray.append(endpointData(column1: unused, column2: "", column3: "", column4: "", column5: "", column6: ""))
                                                }
                                            }
                                        }

                                    default:
                                        break
    //                                  print("Script or Package")
                                }
                            }   // for i in (0..<endpointInfo.count) - end
                            
                        }  else {  // if let serverEndpointJSON - end
                            WriteToLog().message(stringOfText: ["apiCall - existing endpoints: error serializing JSON: \(String(describing: error))"])
                        }
                    }   // end do
                    if httpResponse.statusCode > 199 && httpResponse.statusCode <= 299 {

                        WriteToLog().message(stringOfText: ["[apiCall] completion - status code: \(httpResponse.statusCode)"])
                        completion(self.displayResults)
                        if self.username != self.preferencesDict["username"] as? String || self.currentServer != self.preferencesDict["jps_url"] as! String {
                            self.preferencesDict["username"] = self.username as AnyObject
                            self.preferencesDict["jps_url"]  = self.currentServer as AnyObject
                            NSDictionary(dictionary: self.preferencesDict).write(to: self.prefsPath, atomically: true)
                        } else if self.saveCreds_button.state.rawValue == 1 {
                            NSDictionary(dictionary: self.preferencesDict).write(to: self.prefsPath, atomically: true)
                        }
                        if self.saveCreds_button.state.rawValue == 1 {
                            let serverNameArray = "\(self.jamfServer_TextField.stringValue)".components(separatedBy: "//")
                            self.Creds.save(service: "Object Info - \(serverNameArray[1])", account: self.username, data: self.passwd_TextField.stringValue)
                        }

                    } else {
                        // something went wrong
//                        self.spinner.stopAnimation(self)
                        WriteToLog().message(stringOfText: ["[apiCall] completion - Something went wrong, status code: \(httpResponse.statusCode)"])
                        switch httpResponse.statusCode {
                        case 401:
                        self.alert_dialog(header: "Alert", message: "Authentication failed.  Check username and password.")
                        default:
                            break
                        }
                        self.spinner.stopAnimation(self)
                        completion(self.displayResults)
                    }   // if httpResponse.statusCode - end
                } else {  // if let httpResponse = response - end
//                    self.spinner.stopAnimation(self)
                    WriteToLog().message(stringOfText: ["[apiCall] completion - No response to \(self.endpointUrl)"])
                    self.alert_dialog(header: "Alert", message: "No response to:\n\(self.endpointUrl)")
                    completion("")
                }
                semaphore.signal()
            })   // let task = serverSession.dataTask - end
            task.resume()
            semaphore.wait()
        }   // theGeneralQ - end
        
    }   // func apiCall - end
    

    func getDetails(id: String, completion: @escaping (_ result: String) -> Void) {
        URLCache.shared.removeAllCachedResponses()
//        let semaphore = DispatchSemaphore(value: 1)
        detailQ.maxConcurrentOperationCount = 4
        let semaphore   = DispatchSemaphore(value: 0)
        
//        let safeCharSet = CharacterSet.alphanumerics
        
        username        = self.uname_TextField.stringValue     //.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        password        = self.passwd_TextField.stringValue    //.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        let jamfCreds   = "\(self.username):\(self.password)"
        
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        let jamfBase64Creds = (jamfUtf8Creds?.base64EncodedString())!
        
        let idUrl = self.endpointUrl+"/id/\(id)"
        WriteToLog().message(stringOfText: ["[getDetails] idUrl: \(idUrl)"])
        
        detailQ.addOperation {

            
            let encodedURL          = NSURL(string: idUrl)
            let request             = NSMutableURLRequest(url: encodedURL! as URL)

            var thePackageArray     = [Dictionary<String, Any>]()
            var maintenanceDict     = Dictionary<String, Any>()
            
            var searchStringArray        = [String]()
            var recordName          = ""
            var currentPayload      = ""
            var triggers            = ""
            var freq                = ""
            var currentPolicyArray  = [String]()

            
            request.httpMethod = "GET"
            let serverConf = URLSessionConfiguration.default
            serverConf.httpAdditionalHeaders = ["Authorization" : "Basic \(jamfBase64Creds)", "Content-Type" : "application/json", "Accept" : "application/json"]
            let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = serverSession.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode > 199 && httpResponse.statusCode <= 299 {
//                    do {
                        WriteToLog().message(stringOfText: ["[getDetails] GET: \(idUrl)"])
                        WriteToLog().message(stringOfText: ["[getDetails] singleEndpointXmlTag: \(self.singleEndpointXmlTag)"])
                        WriteToLog().message(stringOfText: ["[getDetails] menuIdentifier: \(self.menuIdentifier)"])

                        self.progressBar.increment(by: self.increment)

                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json as? [String: Any] {
                            if let endpointInfo = endpointJSON["\(self.singleEndpointXmlTag)"] as? [String : AnyObject] {

                                switch self.singleEndpointXmlTag {
                                case "network_segment":
                                    recordName           = endpointInfo["name"] as! String
                                    let starting         = endpointInfo["starting_address"] as! String
                                    let ending           = endpointInfo["ending_address"] as! String
                                    let dp               = endpointInfo["distribution_point"] as! String
                                    let url              = endpointInfo["url"] as! String
                                    self.detailedResults = "\(recordName) \t\(starting) \t\(ending) \t\(dp) \t\(url)"
                                case "os_x_configuration_profile","mac_application","configuration_profile","mobile_device_application":
                                    if let generalTag = endpointInfo["general"] as? [String : AnyObject] {
                                        self.detailedResults = ""
                                        recordName = generalTag["name"] as! String

                                        WriteToLog().message(stringOfText: ["[getDetails] \(self.singleEndpointXmlTag) name: \(recordName)"])
                                        if !(self.menuIdentifier == "scg" || self.menuIdentifier == "sdg") {
                                            let payload = generalTag["payloads"]?.replacingOccurrences(of: "\"", with: "")
    //                                        print("\(String(describing: payload))")
                                            // login windown look for <string>Login Window:  Global Preferences</string>
                                            switch self.menuIdentifier {
                                            case "mac_passcode","ios_passcode":
                                                searchStringArray = ["<string>com.apple.mobiledevice.passwordpolicy</string>"]
                                            case "mac_network","ios_wifi":
                                                searchStringArray = ["<key>HIDDEN_NETWORK</key>"]
                                            case "mac_vpn","ios_vpn":
                                                searchStringArray = ["<key>VPNType</key>"]
                                            case "mac_cert":
                                                searchStringArray = ["<key>PayloadCertificateFileName</key>","<string>com.apple.security.root</string>","<key>PayloadDescription</key><string/>"]
                                            case "mac_scep":
                                                searchStringArray = ["<string>com.apple.security.scep</string>"]
                                            case "mac_dir":
                                                searchStringArray = ["<string>com.apple.DirectoryService.managed</string>"]
                                            case "mac_kext":
                                                searchStringArray = ["<string>com.apple.syspolicy.kernel-extension-policy</string>"]
                                            case "mac_sysext":
                                                searchStringArray = ["<string>com.apple.system-extension-policy</string>"]
                                            case "mac_su":
                                                searchStringArray = ["<string>com.apple.SoftwareUpdate</string>"]
                                            case "mac_restrict":
                                                searchStringArray = ["<string>com.apple.MCX</string>","<key>PayloadDisplayName</key><string>Application Restrictions</string>"]
                                            case "ios_restrict":
                                                searchStringArray = ["<string>com.apple.applicationaccess</string>","<key>allowGlobalBackgroundFetchWhenRoaming</key>","<key>allowAppCellularDataModification</key>"]
                                            case "mac_loginitems":
                                                searchStringArray = ["<string>com.apple.loginitems.managed</string>"]
                                            case "mac_loginwindow":
                                                searchStringArray = ["<string>com.apple.MCX</string>","<string>Login Window:  Global Preferences</string>","<string>Login Window</string>"]
                                            case "mac_dock":
                                                searchStringArray = ["<string>com.apple.dock</string>","<string>Dock</string>"]
                                            case "mac_mobility":
                                                searchStringArray = ["<key>cachedaccounts.WarnOnCreate.allowNever</key>","<string>com.apple.homeSync</string>"]
                                            case "mac_print":
                                                searchStringArray = ["<string>com.apple.mcxprinting</string>"]
                                            case "mac_sec-priv":
                                                searchStringArray = ["<key>DestroyFVKeyOnStandby</key>","<string>Security And Privacy</string>"]
                                            case "mac_ad-cert":
                                                searchStringArray = ["<string>com.apple.ADCertificate.managed</string>","<key>PayloadDisplayName</key><string>AD Certificate</string>"]
                                            case "mac_energy":
                                                searchStringArray = [""]
                                            case "ios_mail":
                                                searchStringArray = ["<string>com.apple.mail.managed</string>","<string>EmailTypeIMAP</string>"]
                                            case "ios_eas":
                                                searchStringArray = ["<key>PayloadType</key><string>com.apple.eas.account</string>","<key>MailNumberOfPastDaysToSync</key>"]
                                            case "ios_google":
                                                searchStringArray = ["<key>PayloadDisplayName</key><string>com.apple.google-oauth</string>"]
                                            case "ios_sam":
                                                searchStringArray = ["<string>com.apple.app.lock</string>","<key>Identifier</key><string>com.apple.Maps</string>"]
                                            case "ios_webclip":
                                                searchStringArray = ["<string>com.apple.webClip.managed</string>"]
                                            case "ios_hsl":
                                                searchStringArray = ["<string>com.apple.homescreenlayout</string>"]
                                            case "2":
                                                searchStringArray = [""]
                                            case "3":
                                                searchStringArray = [""]
                                            default:
                                                break
                                            }

                                            WriteToLog().message(stringOfText: ["[searchResults] looking for \(self.menuTitle)"])
                                            if self.searchResult(payload: payload!, critereaArray: searchStringArray) {
                                                WriteToLog().message(stringOfText: ["[searchResults] \(self.menuTitle) found in \(recordName)"])
                                                self.detailedResults = "\(self.menuTitle) \t\(recordName)"
                                                switch self.endpointType {
                                                case "ios_cp":
                                                    self.getScope(endpointInfo: endpointInfo, scopeObjects: ["mobile_devices", "mobile_device_groups", "buildings", "departments", "users", "user_groups", "network_segments"])
                                                default:
                                                    self.getScope(endpointInfo: endpointInfo, scopeObjects: ["computers", "computer_groups", "buildings", "departments", "users", "user_groups", "network_segments"])
                                                }

//                                                self.summaryArray.append(endpointData(column1: "\(self.menuTitle)", column2: "\(recordName)", column3: "", column4: "", column5: "", column6: ""))
//                                                self.details_TextView.string.append("\(self.menuTitle)\t\(recordName)\n")

                                            } else {
                                                WriteToLog().message(stringOfText: ["[searchResults] \(recordName) not found"])
                                                self.detailedResults = ""
                                            }

                                        }

                                        switch self.menuIdentifier {
                                            case "scg":
                                                let packageConfigTag = endpointInfo["scope"] as! [String:AnyObject]
                                                thePackageArray      = packageConfigTag["computer_groups"] as! [Dictionary<String, Any>]
                                                if packageConfigTag["all_computers"] as! Bool {
                                                    thePackageArray.append(["id": 1, "name": "All Computers"])
                                                }
                                                searchStringArray    = [""]
                                            case "sdg": // added 201207 lnh
                                                WriteToLog().message(stringOfText: ["[getDetails] Checking scope for \(self.singleEndpointXmlTag)"])
                                                let packageConfigTag = endpointInfo["scope"] as! [String:AnyObject]
                                                thePackageArray      = packageConfigTag["mobile_device_groups"] as! [Dictionary<String, Any>]
                                                if packageConfigTag["all_mobile_devices"] as! Bool {
                                                    thePackageArray.append(["id": 1, "name": "All iOS Devicces"])
                                                }
                                                searchStringArray    = [""]
                                            default:
                                                break
                                        }

                                    }

                                case "policy","computer_configuration":
                                    //print("policy endpointInfo: \(endpointInfo)")
                                    if let generalTag = endpointInfo["general"] as? [String : AnyObject] {
                                        recordName = generalTag["name"] as! String
                                        self.detailedResults = "\(recordName)"
                                        WriteToLog().message(stringOfText: ["[getDetails] case policy,computer_configuration - Policy Name: \(recordName)"])
                                        // get triggers
                                        if self.selectedEndpoint == "policies" {
                                            triggers = self.triggersAsString(generalTag: generalTag)
                                            freq = generalTag["frequency"] as! String
                                        }
                                    }
                                    switch self.menuIdentifier {
                                    case "recon":
                                        maintenanceDict = endpointInfo["maintenance"] as! Dictionary<String, Any>
                                        if maintenanceDict["recon"] as! Bool {
                                            self.getScope(endpointInfo: endpointInfo, scopeObjects: ["computers", "computer_groups", "buildings", "departments", "users", "user_groups", "network_segments"])
                                            self.detailedResults = "\(recordName) \t\(triggers) \t\(self.theScope)"
                                        }

                                    case "Packages":
                                        if self.selectedEndpoint == "policies" {
                                            let packageConfigTag = endpointInfo["package_configuration"] as! [String:AnyObject]
                                            thePackageArray      = packageConfigTag["packages"] as! [Dictionary<String, Any>]
                                        } else {
                                            thePackageArray = endpointInfo["packages"] as! [Dictionary<String, Any>]
                                        }

                                    case "Scripts":
                                        thePackageArray = endpointInfo["scripts"] as! [Dictionary<String, Any>]

                                    case "scg":
                                        let packageConfigTag = endpointInfo["scope"] as! [String:AnyObject]
                                        thePackageArray      = packageConfigTag["computer_groups"] as! [Dictionary<String, Any>]
                                        if packageConfigTag["all_computers"] as! Bool {
                                            thePackageArray.append(["id": 1, "name": "All Computers"])
                                        }

//                                    case "sdg": // added 201207 lnh
//                                        let packageConfigTag = endpointInfo["scope"] as! [String:AnyObject]
//                                        thePackageArray = packageConfigTag["mobile_device_groups"] as! [Dictionary<String, Any>] all_mobile_devices
                                    default:
                                        break
                                    }

                                default:
                                    break
                                }

                                WriteToLog().message(stringOfText: ["[getDetails] singleEndpointXmlTag: \(self.singleEndpointXmlTag)"])
                                switch self.singleEndpointXmlTag {
                                case "policy","computer_configuration","mac_application","os_x_configuration_profile","configuration_profile","mobile_device_application":
                                    for i in (0..<thePackageArray.count) {

//                                        print("package name in policy: \(String(describing: thePackageArray[i]["name"]!))")
//                                        print("      selectedEndpoint: \(String(describing: self.selectedEndpoint))")

                                        currentPayload = "\(String(describing: thePackageArray[i]["name"]!))"
                                        currentPolicyArray.append("\(recordName)")
                                        if let pkgIndex = self.pkgScrArray.index(of: "\(currentPayload)") {
                                            self.pkgScrArray.remove(at: pkgIndex)
                                        }
                                        switch self.selectedEndpoint {
                                        // format the data to the columns in the table
                                        case "policies":
                                            if self.menuIdentifier == "Packages" || self.menuIdentifier == "Scripts" {
                                                self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "\(triggers)", column4: "\(freq)", column5: "", column6: ""))
                                                self.details_TextView.string.append("\(currentPayload)\t\(recordName)\t\(triggers)\t\(freq)\n")
                                            } else {
                                                self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "", column4: "\(triggers)", column5: "\(freq)", column6: ""))
                                                self.details_TextView.string.append("\(currentPayload)\t\(recordName)\t\t\(triggers)\t\(freq)\n")

                                            }
                                        case "macapplications":
                                            self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "", column3: "", column4: "", column5: "", column6: "\(recordName)"))
                                            self.details_TextView.string.append("\(currentPayload)\t\t\t\t\t\(recordName)\n")
                                        case "mobiledeviceconfigurationprofiles":
                                            self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "", column4: "", column5: "", column6: ""))
                                            self.details_TextView.string.append("\(currentPayload)\t\(recordName)\t\t\(triggers)\n")
                                        case "mobiledeviceapplications":
                                            self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "", column3: "\(recordName)", column4: "", column5: "", column6: ""))
                                            self.details_TextView.string.append("\(currentPayload)\t\t\(recordName)\n")
                                        case "osxconfigurationprofiles":
                                            self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "", column3: "\(recordName)", column4: "", column5: "", column6: ""))
                                            self.details_TextView.string.append("\(currentPayload)\t\t\(recordName)\n")
                                        default:
                                            self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "", column3: "", column4: "\(recordName)", column5: "", column6: ""))
                                            self.details_TextView.string.append("\(currentPayload)\t\t\t\(recordName)\n")
                                        }

                                        if self.menuIdentifier != "recon" {
                                            self.detailedResults = "\(currentPayload) \t\(recordName) \t\(triggers) \t\(freq)"
                                        }
                                    }
//                                case "os_x_configuration_profile":
//                                    self.summaryArray.append(endpointData(column1: "\(currentPayload)", column2: "\(recordName)", column3: "", column4: "", column5: "", column6: ""))
//                                    self.details_TextView.string.append("\(currentPayload)\t\t\(recordName)\n")

                                default:
                                    break
                                }


                            } else {
                                WriteToLog().message(stringOfText: ["getDetails: if let endpointInfo = endpointJSON[\(self.singleEndpointXmlTag)], id='\(id)' error.)\n\(idUrl)"])
                            }
                        }  else {  // if let serverEndpointJSON - end
                            WriteToLog().message(stringOfText: ["getDetails - existing endpoints: error serializing JSON: \(String(describing: error))"])
                        }
//                    }   // end do

                        let theRecord: [String] = "\(self.detailedResults)".components(separatedBy: "\t")
                        WriteToLog().message(stringOfText: ["[getDetails] theRecord: \(theRecord)"])

                        if self.endpointType != "Packages" && self.endpointType != "Scripts" && self.menuIdentifier != "scg" && self.menuIdentifier != "sdg" {
                            WriteToLog().message(stringOfText: ["[getDetails] \(recordName) is using theRecord with theRecord.count = \(theRecord.count)"])
                            switch theRecord.count {
                            case 5:
                                self.summaryArray.append(endpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "\(theRecord[2])", column4: "\(theRecord[3])", column5: "\(theRecord[4])", column6: ""))
                                self.details_TextView.string.append("\(theRecord[0])\t\(theRecord[1])\t\(theRecord[2])\t\(theRecord[3])\t\(theRecord[4])\n")
                            case 3:
                                if theRecord[0] != "" {
                                    self.summaryArray.append(endpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "\(theRecord[2])", column4: "", column5: "", column6: ""))
                                    self.details_TextView.string.append("\(theRecord[0])\t\(theRecord[1])\t\(theRecord[2])\n")
                                }
                            case 2:
                                if theRecord[0] != "" {
                                    self.summaryArray.append(endpointData(column1: "\(theRecord[0])", column2: "\(theRecord[1])", column3: "", column4: "", column5: "", column6: ""))
                                    self.details_TextView.string.append("\(theRecord[0])\t\(theRecord[1])\n")
                                }
                            default: break

                            }

                        }
                        
//                        print("returning from: \(idUrl)\n")
//                        print("getDetails - theRecord: \(theRecord)")
                        completion(self.detailedResults)
                    } else {
                        // something went wrong
                        WriteToLog().message(stringOfText: ["status code: \(httpResponse.statusCode)"])
                        completion(self.detailedResults)
                    }   // if httpResponse.statusCode - end
                } else {   // if let httpResponse = response - end
                    DispatchQueue.main.async {
                        self.progressBar.increment(by: 1.0)
                    }
                    WriteToLog().message(stringOfText: ["no response for: \(idUrl)"])
                }
                semaphore.signal()
                self.completeCounter+=1
                WriteToLog().message(stringOfText: ["[getDetails] completeCounter: \(self.completeCounter)\tapiDetailCount: \(self.apiDetailCount)"])
                if (self.completeCounter == self.apiDetailCount) {
                    if !(self.selectedEndpoint == "osxconfigurationprofiles" && self.menuIdentifier == "scg") {
                        WriteToLog().message(stringOfText: ["[getDetails] queryComplete"])
                        self.queryComplete()
                    }
                }
            })   // let task = serverSession.dataTask - end
            task.resume()
            semaphore.wait()
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
        progressBar.isHidden         = true
        action_textField.stringValue = "Search Complete"
        get_button.isEnabled         = true
    }
    
    // convert an array to a comma delimited string - start
    func triggersAsString(generalTag: [String : AnyObject]) -> String {
        var elementList = ""
        
        var elementArray = [String]()
        generalTag["trigger_checkin"] as! Bool ? elementArray.append("checkin"):print("")
        generalTag["trigger_enrollment_complete"] as! Bool ? elementArray.append("Enrollment Complete"):print("")
        generalTag["trigger_login"] as! Bool ? elementArray.append("login"):print("")
        generalTag["trigger_logout"] as! Bool ? elementArray.append("logout"):print("")
        generalTag["trigger_network_state_changed"] as! Bool ? elementArray.append("Network State Change"):print("")
        generalTag["trigger_startup"] as! Bool ? elementArray.append("startup"):print("")
        generalTag["trigger_other"] as? String != nil ? elementArray.append("\(String(describing: generalTag["trigger_other"]!))"):print("")
        
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
        WriteToLog().message(stringOfText: ["[validEndpointInfo] endpoint: \(endpoint)"])
        var filtered    = [Any]()
        var tmpFiltered = filtered
//        var tmpPolicyNames = [String]()
        
        switch endpoint {
        case "policies":
            WriteToLog().message(stringOfText: ["[validEndpointInfo] filter out policies from Jamf Remote"])
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
            WriteToLog().message(stringOfText: ["[validEndpointInfo] filtered: \(filtered)"])
            filtered = endpointJSON[endpoint] as! [Any]
        }

        return filtered
    }
    // remove policy entries generated by jamf remote - end
    
    func formatTableView(columnHeaders: [String]) {
        //print("columnHeaders: \(columnHeaders)")/*
        let tableWidth = CGFloat(tableView.frame.size.width)
        var tableColumn: NSTableColumn?
        var columnHeader: NSTableHeaderCell
        let numberOfColumns = columnHeaders.count
        let columnScale = (numberOfColumns != 6) ? numberOfColumns:5
        let columnWidth     = tableWidth/CGFloat(numberOfColumns)
        for i in (0..<numberOfColumns) {
            tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "column\(i+1)"))
            columnHeader = (tableColumn?.headerCell)!
            columnHeader.title = "\(columnHeaders[i])"
            tableColumn?.width = columnWidth/CGFloat(6-columnScale)
            tableColumn?.isHidden = false
        }
        for j in (numberOfColumns..<6) {
//                tableView.removeTableColumn(tableView.tableColumns[numberOfColumns])
            tableColumn  = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "column\(j+1)"))
            columnHeader = (tableColumn?.headerCell)!
            columnHeader.title = ""
            tableColumn?.width = 10.0
            tableColumn?.isHidden = true
        }
    }
    
    func getScope(endpointInfo: [String : AnyObject], scopeObjects: [String]) {
        WriteToLog().message(stringOfText: ["[getScope] endpointInfo: \(endpointInfo)"])
        WriteToLog().message(stringOfText: ["[getScope] scopeObjects: \(scopeObjects)"])
        
        var allScope            = ""
        var currentScopeArray   = [String]()

        WriteToLog().message(stringOfText: ["[getScope] endpointType: \(endpointType)"])

        switch endpointType {
        case "ios_cp","sdg":    // added sdg lnh - 201205
            allScope = "all_mobile_devices"
        default:
            allScope = "all_computers"
        }
        
        if let scope = endpointInfo["scope"] as? [String : AnyObject] {
            if scope["\(allScope)"] as! Bool {
//                print("[getScope] scoped to All")
//                self.detailedResults.append(" \tAll Computers")
                self.theScope = "All Computers"
                switch self.endpointType {
                case "ios_cp":
//                    self.detailedResults.append(" \tAll iOS Devices")
                    self.theScope = "All iOS Devices"
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
                            let recordName = theRecord["name"] as! String
                            scopeObjectArray.append(recordName)
                        }
                        if scopeObjectArray.count > 0 {
                            scope[scopeObject] != nil ? currentScopeArray.append("\(scopeObject):\(String(describing: scopeObjectArray))") : ()
                        }
                    }
                    
                }
            }   // else - end
            // convert array to comma seperated list (newline not working)
            var scopeList = ""
            for scopeItem in currentScopeArray {
                if scopeList != "" {
                    scopeList.append(", \(scopeItem)")
                } else {
                    scopeList.append("\(scopeItem)")
                }
            }
//            print("[getScope] scopeList: \(scopeList)")
            self.detailedResults.append("\t\(scopeList)")  // remove this at some point, replace references with 'theScope'
//            print("[getScope] self.detailedResults: \(self.detailedResults)")
            self.theScope = scopeList
        }
    }
    
    @IBAction func export_action(_ sender: NSButton) {
//        print(details_TextView.string ?? "Nothing found.")
        
        let savePanel = NSSavePanel()
        
        savePanel.nameFieldStringValue = oSelectedEndpoint+".txt"
        
        savePanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                let exportedFileURL  = savePanel.url
                var exportPathString = exportedFileURL?.absoluteString.replacingOccurrences(of: "file://", with: "")
                exportPathString     = exportPathString?.replacingOccurrences(of: "%20", with: " ")
                
//                let exportPath = exportedFileURL?.absoluteString
                if !self.fm.fileExists(atPath: exportPathString!) {
//                    print("export file does not exist, creating.")
                    self.fm.createFile(atPath: exportPathString!, contents: nil, attributes: nil)
                } else {
                    do {
                        try self.fm.removeItem(atPath: exportPathString!)
                        self.fm.createFile(atPath: exportPathString!, contents: nil, attributes: nil)
                    } catch {
                        self.alert_dialog(header: "Alert:", message: "Unable to replace exiting file.")
                        return
                    }
                }
                
                do {
                    let exportHandle = try FileHandle(forWritingTo: exportedFileURL!)
                    
                    let exportData = self.details_TextView.string.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                    exportHandle.write(exportData!)
                } catch {
                    self.alert_dialog(header: "Alert:", message: "Unable to export data.")
                }
            }
        } // savePanel.begin - end
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
    
    @IBAction func saveCreds_action(_ sender: Any) {
        if saveCreds_button.state.rawValue == 1 {
            preferencesDict["save_pwd"] = 1 as AnyObject
        } else {
            preferencesDict["save_pwd"] = 0 as AnyObject
        }
    }
    
    
    func searchResult(payload: String, critereaArray: [String]) -> Bool {
//        print("\n[searchResult] payload: \(payload)\ncriteriaArray: \(critereaArray)\n")
        for criterea in critereaArray {
            if payload.range(of:criterea, options: .regularExpression) == nil {
//                print("\n[searchResult] criteria not found: \(criterea)\n")
                return false
            }
        }
        return true
    }
    
    @IBAction func stop_action(_ sender: Any) {
        apiQ.cancelAllOperations()
        detailQ.cancelAllOperations()
        stop_button.isHidden = true
        export_button.isEnabled = true
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layer?.backgroundColor = CGColor(red: 0x5C/255.0, green: 0x78/255.0, blue: 0x94/255.0, alpha: 1.0)
        stop_button.isHidden = true
        // Do any additional setup after loading the view.

        // work on sorting...
//        let descriptor1 = NSSortDescriptor(key: "column1", ascending: true)
//        let descriptor2 = NSSortDescriptor(key: "column2", ascending: true)
//        let descriptor3 = NSSortDescriptor(key: "column3", ascending: true)
//
//        tableView.tableColumns[0].sortDescriptorPrototype = descriptor1
//        tableView.tableColumns[1].sortDescriptorPrototype = descriptor2
//        tableView.tableColumns[2].sortDescriptorPrototype = descriptor3
    }
    
    override func viewDidAppear() {

        jamfServer_TextField.becomeFirstResponder()
        get_button.isEnabled         = false
        self.spinner.isHidden        = true
        self.export_button.isEnabled = false
        
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
        
        // read preferences - start
        preferencesDict = (NSDictionary(contentsOf: prefsPath) as? [String : AnyObject])!
        // read preferences - end
        
        jamfServer_TextField.stringValue = (preferencesDict["jps_url"] == nil) ? "" : preferencesDict["jps_url"] as! String
        uname_TextField.stringValue      = (preferencesDict["username"] == nil) ? "" : preferencesDict["username"] as! String
        
        if preferencesDict["save_pwd"] == nil {
            saveCreds_button.state = NSControl.StateValue(rawValue: 0)
        } else {
            saveCreds_button.state = NSControl.StateValue(rawValue: preferencesDict["save_pwd"] as! Int)
        }
        
        if jamfServer_TextField.stringValue != "" {
            //check of saved password
            let serverNameArray = "\(self.jamfServer_TextField.stringValue)".components(separatedBy: "//")
            let storedPassword  = Creds.retrieve(service: "Object Info - \(serverNameArray[1])")
            if storedPassword.count == 2 {
                uname_TextField.stringValue  = storedPassword[0]
                passwd_TextField.stringValue = storedPassword[1]
            }
        }

        WriteToLog().message(stringOfText: [""])
        WriteToLog().message(stringOfText: ["================================"])
        WriteToLog().message(stringOfText: ["  Object Info Version: \(version)"])
        WriteToLog().message(stringOfText: ["        macOS Version: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"])
        WriteToLog().message(stringOfText: ["================================"])
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
