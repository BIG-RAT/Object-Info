//
//  Copyright 2025, Jamf
//

import Foundation
//import OSLog

class ResourceCheck: NSObject, URLSessionDelegate {
    
    static let shared = ResourceCheck()
    
    @MainActor func launchCheck(prohibitedCheck: Bool = true, versionCheck: Bool = true) async {
        WriteToLog.shared.message("[launchCheck] performing launch check")
        let prohibitedVersions = prohibitedCheck ? await ResourceCheck.shared.prohibited(): []
        let prohibited = prohibitedVersions.contains(AppInfo.version)
        
        let versionResult = await ResourceCheck.shared.version(forceCheck: versionCheck)
//        let versionResult = await ResourceCheck.shared.version(forceCheck: prohibited)
        
        if prohibited {
            _ = Alert.shared.display(header: "", message: "This version, v\(AppInfo.version), is prohibited from running.", secondButton: "")
            WriteToLog.shared.message("[launchCheck] this version, v\(AppInfo.version), is prohibited from running. Application terminated.")
            if !versionResult.0 {
                exit(1)
            }
        }
        
        if versionResult.0 {
            Task {
                _ = await Alert.shared.versionDialog(header: "A new version (\(versionResult.1)) is available.", version: versionResult.1, message: "Running \(AppInfo.displayname): v\(AppInfo.version)", updateAvail: versionResult.0)
                if prohibited {
                    exit(1)
                }
            }
        }
    }
    
    func prohibited() async -> [String] {
        
        URLCache.shared.removeAllCachedResponses()
        
        let versionUrl = URL(string: "https://raw.githubusercontent.com/BIG-RAT/Object-Info/refs/heads/main/resources/version/version-info.json")
        
        let configuration = URLSessionConfiguration.ephemeral
        var request = URLRequest(url: versionUrl!)
        request.httpMethod = "GET"
        
        configuration.httpAdditionalHeaders = ["Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        do {
            
            let checkResult = try await session.data(for: request)
//            if let responseString = String(data: checkResult.0, encoding: .utf8) {
//                print("prohibitedVersions: \(responseString)")
//            } else {
//                print("prohibitedVersions: No response data returned")
//            }
            
            session.finishTasksAndInvalidate()
            if let httpResponse = checkResult.1 as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: checkResult.0, options: .allowFragments)
                    if let endpointJSON = json as? [String: Any] {
                        
                        let prohibitedVersion = (endpointJSON["do_not_run_versions"] as? [String]) ?? []
                        if prohibitedVersion.count > 0 {
                            WriteToLog.shared.message("[prohibited] prohibited versions found: \(prohibitedVersion.description)")
                        }
                        UserDefaults.standard.set(prohibitedVersion, forKey: "prohibitedVersions")
                        return prohibitedVersion
                        
                    } else {    // if let endpointJSON error
                        return []
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    WriteToLog.shared.message("[launchCheck] prohibited response error: \(httpResponse.statusCode)")
                    return []
                }
                
            } else {
                return []
            }
        } catch {
            return []
        }
    }
    
    func version(forceCheck: Bool = false) async -> (Bool, String) {
        
        if !forceCheck {
            WriteToLog.shared.message("[version] skipping version check")
//            UserDefaults.standard.set(false, forKey: "prohibited") // currently does nothing
            return (false, AppInfo.version)
        }
        
        URLCache.shared.removeAllCachedResponses()

        let (currMajor, currMinor, currPatch, runningBeta, currBeta) = versionDetails(theVersion: AppInfo.version)
        
        var updateAvailable = false
        var versionTest     = true

        let versionUrl = URL(string: "https://api.github.com/repos/BIG-RAT/Object-Info/releases/latest")

        let configuration = URLSessionConfiguration.ephemeral
        var request = URLRequest(url: versionUrl!)
        request.httpMethod = "GET"
        
        configuration.httpAdditionalHeaders = ["Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        do {
            
            let checkResult = try await session.data(for: request)
            
            session.finishTasksAndInvalidate()
            if let httpResponse = checkResult.1 as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: checkResult.0, options: .allowFragments)
                    if let endpointJSON = json as? [String: Any] {
                        
                        let fullVersion = (endpointJSON["tag_name"] as! String).replacingOccurrences(of: "v", with: "")
                        
                        if !runningBeta && fullVersion.firstIndex(of: "b") == nil {
                            versionTest = self.compareVersions(currMajor: currMajor,
                                                               currMinor: currMinor,
                                                               currPatch: currPatch,
                                                               runningBeta: runningBeta,
                                                               currBeta: currBeta,
                                                               available: fullVersion)
                        } else if runningBeta && fullVersion.firstIndex(of: "b") != nil {
                            versionTest = self.compareVersions(currMajor: currMajor,
                                                               currMinor: currMinor,
                                                               currPatch: currPatch,
                                                               runningBeta: runningBeta,
                                                               currBeta: currBeta,
                                                               available: fullVersion)
                        }
                        if !versionTest {
                            updateAvailable = true
                        }

//                        return (true, "1.2.1")  // for testing
                        return (updateAvailable, "\(fullVersion)")
                        
                    } else {    // if let endpointJSON error
                        return (false, "")
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    WriteToLog.shared.message("[version] version check response error: \(httpResponse.statusCode)")
                    return (false, "")
                }
                
            } else {
                return (false, "")
            }
        } catch {
            return (false, "")
        }
    }
    
    private func compareVersions(currMajor: Int, currMinor: Int, currPatch: Int, runningBeta: Bool, currBeta: Int, available: String) -> Bool {
        var runningCurrent = true
        var betaVer = ""
        if runningBeta {
            betaVer = "b\(currBeta)"
        }
        if available != "\(currMajor).\(currMinor).\(currPatch)\(betaVer)" {
            let (availMajor, availMinor, availPatch, availBeta, availBetaVer) = versionDetails(theVersion: available)
            if availMajor > currMajor {
                runningCurrent = false
            } else if availMajor == currMajor {
                if availMinor > currMinor {
                    runningCurrent = false
                } else if availMinor == currMinor {
                    if availPatch > currPatch {
                        runningCurrent = false
                    } else if availPatch == currPatch && ((runningBeta && availBeta) || (runningBeta && !availBeta))  {
                        if availBetaVer > currBeta {
                            runningCurrent = false
                        }
                    }
                }
            }
        }
        return runningCurrent
    }
    
    func versionDetails(theVersion: String) -> (Int, Int, Int, Bool, Int) {
        var major   = 0
        var minor   = 0
        var patch   = 0
        var betaVer = 0
        var isBeta  = false
        
        let versionArray = theVersion.split(separator: ".")
        if versionArray.count > 2 {

            major = Int(versionArray[0])!
            minor = Int(versionArray[1])!
            let patchArray = versionArray[2].lowercased().split(separator: "b")
            patch = Int(patchArray[0])!
            if patchArray.count > 1 {
                isBeta = true
                betaVer = Int(patchArray[1])!
            }
        }
        return (major, minor, patch, isBeta, betaVer)
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

