//
//  Credentials.swift
//  Object Info
//
//  Created by Leslie Helou on 9/20/19.
//  Copyright © 2019 jamf. All rights reserved.
//

import Foundation
import Security

let kSecAttrAccountString          = NSString(format: kSecAttrAccount)
let kSecValueDataString            = NSString(format: kSecValueData)
let kSecClassGenericPasswordString = NSString(format: kSecClassGenericPassword)
let prefix                         = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "unknown"
var sharedPrefix                   = ""
var accessGroup                    = ""

struct Credentials {
    
    static let shared = Credentials()
    public init() {
        let teamId = fetchTeamId()
        if teamId == "PS2F6S478M" {
            accessGroup = "\(teamId).jamfie.SharedJPMA"
            sharedPrefix = "JPMA"
        } else {
            accessGroup = "\(teamId).jamfie.SharedJSK"
            sharedPrefix = "JSK"
        }
    }
    
//    var userPassDict = [String:String]()
    
    func save(service: String, account: String, credential: String, useApiClient: Bool) async -> String {
        
        var returnMessage = "keychain save process completed successfully"
        
            if !service.isEmpty && !account.isEmpty && !credential.isEmpty {
                    
                var theService = service.lowercased().fqdnFromUrl
            
                if useApiClient {
                    theService = "apiClient-" + theService
                }
                
                let keychainItemName = sharedPrefix + "-" + theService
                
                WriteToLog.shared.message(stringOfText: "keychain item \(keychainItemName) for account \(account)")

                if let password = credential.data(using: String.Encoding.utf8) {

                    var keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPasswordString,
                                                        kSecAttrService as String: keychainItemName,
                                                        kSecAttrAccessGroup as String: accessGroup,
                                                        kSecUseDataProtectionKeychain as String: true,
                                                        kSecAttrAccount as String: account.lowercased(),
                                                        kSecValueData as String: password]
                    
                    // see if credentials already exist for server
                    //                    print("[save] for for keychain item: \(service) for account: \(account)")
                    let accountCheck = await retrieve(service: service, account: account, useApiClient: useApiClient)
//                        print("[save] service: \(service)")
//                        print("[save] matches found: \(accountCheck.count)")
//                        print("[save] matches: \(accountCheck)")
                    if accountCheck[account] == nil {
                        // try to add new credentials
                        WriteToLog.shared.message(stringOfText: "adding new keychain item \(keychainItemName) for account \(account)")

                        let addStatus = SecItemAdd(keychainQuery as CFDictionary, nil)
                        if (addStatus != errSecSuccess) {
                            if let addErr = SecCopyErrorMessageString(addStatus, nil) {
                                WriteToLog.shared.message(stringOfText: "write failed for service \(keychainItemName), account \(account): \(addErr)")
                            }
                            returnMessage = "keychain save process was unsuccessful"
                        } else {
                           WriteToLog.shared.message(stringOfText: "keychain item added")
                        }
                    } else {
                        // credentials already exist, try to update
                       WriteToLog.shared.message(stringOfText: "see if keychain item \(keychainItemName) for account \(account) needs updating")
                        keychainQuery = [kSecClass as String: kSecClassGenericPasswordString,
                                         kSecAttrService as String: keychainItemName,
                                         kSecAttrAccessGroup as String: accessGroup,
                                         kSecAttrAccount as String: account.lowercased(),
                                         kSecUseDataProtectionKeychain as String: true,
                                         kSecMatchLimit as String: kSecMatchLimitOne,
                                         kSecReturnAttributes as String: true]
                        if credential != accountCheck[account] {
                            let updateStatus = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueDataString:password] as [NSString : Any] as CFDictionary)
                            if (updateStatus != errSecSuccess) {
                                
                               WriteToLog.shared.message(stringOfText: "keychain item for service \(service), account \(account), failed to update.")
                                returnMessage = "keychain save process was unsuccessful"
//
                            } else {
//                                    print("[addStatus] keychain item for service \(service), account \(account), has been updated.")
                               WriteToLog.shared.message(stringOfText: "keychain item for service \(service), account \(account), has been updated.")
                            }
                        } else {
                            WriteToLog.shared.message(stringOfText: "keychain item for service \(service), account \(account), is current.")
                            returnMessage = "keychain item is current"
                        }
                    }
                    //                    }
                } else {
                    WriteToLog.shared.message(stringOfText: "failed to set password for \(keychainItemName), account \(account)")
                    returnMessage = "keychain save process was unsuccessful"
                }
            }
            
            print("[Credentials.save] returnMessage:\(returnMessage)")
        return returnMessage
    }   // func save - end
    
    func retrieve(service: String, account: String = "", useApiClient: Bool) async -> [String:String] {
       WriteToLog.shared.message(stringOfText: "fetch credentials for service: \(service), account: \(account)")
        //        print("[credentials.retrieve] service passed: \(service)")
        print("[credentials.retrieve] accessGroup: \(accessGroup)")
        var keychainResult = [String:String]()
        var theService     = service.lowercased().fqdnFromUrl

        print("[credentials] JamfProServer useApiClient: \(useApiClient)")
        
        if useApiClient {
            theService = "apiClient-" + theService
        }
        
        let keychainItemName = sharedPrefix + "-" + theService
        
        print("[retrieve] keychainItemName: \(keychainItemName)")
       // WriteToLog.shared.message(theMessage: "[credentials.retrieve] keychainName: \(keychainItemName), account: \(account)")
        // look for common keychain item
        keychainResult = itemLookup(service: keychainItemName)
//        print("[retrieve]   keychainResult: \(keychainResult)")
        
        if keychainResult.count > 1 && !account.isEmpty {
            
            for (username, password) in keychainResult {
                if username.lowercased() == account.lowercased() {
                    WriteToLog.shared.message(stringOfText: "found password/secret for: \(account)")
                    return [username:password]
                }
            }
        }
        
        return keychainResult
    }
    
    private func itemLookup(service: String) -> [String:String] {
        var userPassDict = [String:String]()
//        print("[credentials.itemLookup] keychainName: \(service)")
        let keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPasswordString,
                                            kSecAttrService as String: service,
                                            kSecAttrAccessGroup as String: accessGroup,
                                            kSecUseDataProtectionKeychain as String: true,
                                            kSecMatchLimit as String: kSecMatchLimitAll,
                                            kSecReturnAttributes as String: true,
                                            kSecReturnData as String: true] // new

        var items_ref: CFTypeRef?
        
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &items_ref)
        guard status != errSecItemNotFound else {
            WriteToLog.shared.message(stringOfText: "keychain item, \(service), was not found")
            return [:]
            
        }
        guard status == errSecSuccess else { return [:] }
        
        guard let items = items_ref as? [[String: Any]] else {
            WriteToLog.shared.message(stringOfText: "unable to read keychain item: \(service)")
            return [:]
        }
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String, let passwordData = item[kSecValueData as String] as? Data {
                let password = String(data: passwordData, encoding: String.Encoding.utf8)
                userPassDict[account] = password ?? ""
            }
        }

        WriteToLog.shared.message(stringOfText: "keychain item count: \(userPassDict.count) for \(service)")
        return userPassDict
    }
    
    func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: accessGroup,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        return status == errSecSuccess
    }
    
    private func fetchTeamId() -> String {

        guard let bundleContents = Bundle.main.resourceURL?.deletingLastPathComponent() else {
            return "PS2F6S478M"
        }
        
        let theFile = bundleContents.appending(component: "embedded.provisionprofile")
        
        do {
            // Read the provisioning profile data
            let profileData = try Data(contentsOf: bundleContents.appending(component: "embedded.provisionprofile"))
            
            // Convert the data to a string and extract the plist portion
            if let profileString = String(data: profileData, encoding: .ascii),
               let plistStartRange = profileString.range(of: "<?xml"),
               let plistEndRange = profileString.range(of: "</plist>") {
                // Extract the plist part of the profile
                let plistString = String(profileString[plistStartRange.lowerBound..<plistEndRange.upperBound])
                
                // Convert plist string back to Data for parsing
                if let plistData = plistString.data(using: .utf8) {
                    // Deserialize the plist into a dictionary
                    if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                       let entitlements = plist["Entitlements"] as? [String: Any],
                       let teamID = entitlements["com.apple.developer.team-identifier"] as? String {
                        return teamID
                    }
                }
            }
        } catch {
            print("Error reading provisioning profile: \(error)")
        }
            
        return "PS2F6S478M"
    }
}

