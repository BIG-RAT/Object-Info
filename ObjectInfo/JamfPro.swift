//
//  JamfPro.swift
//  Object Info
//
//  Created by Leslie Helou on 01/08/22.
//  Copyright © 2022 Leslie Helou. All rights reserved.
//

import Foundation

class JamfPro: NSObject, URLSessionDelegate {
    
    static let shared = JamfPro()
    private override init() { }
    
    var renewQ = DispatchQueue(label: "com.jamfpse.token_refreshQ", qos: DispatchQoS.background)   // running background process for refreshing token
    
    func getVersion(jpURL: String, token: String, completion: @escaping (_ jpversion: (Int,Int,Int)) -> Void) {
        
        if JamfProServer.version != "" {
            completion((JamfProServer.majorVersion,JamfProServer.minorVersion,JamfProServer.patchVersion))
            return
        }

//        let semaphore      = DispatchSemaphore(value: 0)
        
        OperationQueue().addOperation {
//            let encodedURL     = NSURL(string: "\(jpURL)/JSSCheckConnection")
            var urlString      = "\(jpURL)/api/v1/jamf-pro-version"
            urlString          = urlString.replacingOccurrences(of: "//api", with: "/api")
            let encodedURL     = NSURL(string: "\(urlString)")
            let request        = NSMutableURLRequest(url: encodedURL! as URL)
            request.httpMethod = "GET"
            let configuration  = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
            let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let _ = response as? HTTPURLResponse {
                    
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String:String?], let _ = endpointJSON["version"]! {
                        JamfProServer.version = endpointJSON["version"]!!
                        WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] \(jpURL) is running v\(JamfProServer.version)")
                    } else {
                        WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] unable to get version for \(jpURL)")
                        completion((0,0,0))
                        return
                    }
                    
//                    print("httpResponse: \(httpResponse)")
//                    print("raw versionString: \(JamfProServer.version)")
                    if JamfProServer.version != "" {
                        let tmpArray = JamfProServer.version.components(separatedBy: ".")
                        if tmpArray.count > 2 {
                            for i in 0...2 {
                                switch i {
                                case 0:
                                    JamfProServer.majorVersion = Int(tmpArray[i]) ?? 0
                                case 1:
                                    JamfProServer.minorVersion = Int(tmpArray[i]) ?? 0
                                case 2:
                                    let tmp = tmpArray[i].components(separatedBy: "-")
                                    JamfProServer.patchVersion = Int(tmp[0]) ?? 0
                                    if tmp.count > 1 {
                                        JamfProServer.build = tmp[1]
                                    }
                                default:
                                    break
                                }
                            }
                        }
                    }
                } else {
                    JamfProServer.version      = ""
                    JamfProServer.majorVersion = 0
                    JamfProServer.minorVersion = 0
                    JamfProServer.patchVersion = 0
                    JamfProServer.build        = ""
                }
                
                completion((JamfProServer.majorVersion,JamfProServer.minorVersion,JamfProServer.patchVersion))
               
            })  // let task = session - end
            task.resume()
//            semaphore.wait()
        }
    }
    
    func getToken(whichServer: String = "source", serverUrl: String, renew: Bool = false, completion: @escaping (_ authResult: (Int,String)) -> Void) {
        
        if !isRunning {
            completion((600, "not running"))
            return
        }
        
//        print("[JamfPro.getToken] JamfProServer.username: \(String(describing: JamfProServer.username))")
//        print("[JamfPro.getToken] JamfProServer.password: \(String(describing: JamfProServer.password.prefix(1)))*******")
//        print("[JamfPro.getToken]   JamfProServer.server: \(String(describing: JamfProServer.server))")

        JamfProServer.server = serverUrl
        
//        print("\(serverUrl.prefix(4))")
        if serverUrl.prefix(4) != "http" {
            completion((0, "skipped"))
            return
        }
        URLCache.shared.removeAllCachedResponses()
        
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"

        let apiClient = ( JamfProServer.useApiClient ?? 0 == 1 ) ? true:false
//        print("[getToken] \(whichServer) use API client: \(apiClient)")
        
        if apiClient {
            tokenUrlString = "\(serverUrl)/api/oauth/token"
        }

        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
//        print("[getToken] tokenUrlString: \(tokenUrlString)")
        
        guard let tokenUrl = URL(string: "\(tokenUrlString)") else {
//            print("problem constructing the URL from \(tokenUrlString)")
            WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] problem constructing the URL from \(tokenUrlString)")
            isRunning = false
            JamfProServer.validToken = false
            completion((500, "failed"))
            return
        }
//        print("[getToken] tokenUrl: \(tokenUrl!)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        
        let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: JamfProServer.tokenCreated ?? Date())
        print("[JamfPro.getToken] \(whichServer.localizedCapitalized) server token age in seconds: \(tokenAgeInSeconds)")
        
//        print("[getToken] JamfProServer.validToken[\(whichServer)]: \(String(describing: JamfProServer.validToken[whichServer]))")
//        print("[getToken] \(whichServer) tokenAgeInSeconds: \(tokenAgeInSeconds)")
        print("[JamfPro.getToken] token renews in: \(JamfProServer.authExpires) seconds")
//        print("[getToken] JamfProServer.currentCred[\(whichServer)]: \(String(describing: JamfProServer.currentCred[whichServer]))")
        let user        = JamfProServer.username
        let password    = JamfProServer.password
        let theCreds    = "\(user):\(password)"
        let base64creds = theCreds.data(using: .utf8)!.base64EncodedString()
        
//        print("[getToken] \(whichServer) serverUrl: \(serverUrl)")
//        print("[getToken] \(whichServer)  username: \(user)")
//        print("[getToken] \(whichServer)  password: \(password)")
//        WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] JamfProServer.validToken[\(whichServer)] \(String(describing: JamfProServer.validToken[whichServer]))")
//        WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] tokenAgeInSeconds \(tokenAgeInSeconds)")
//        WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] JamfProServer.validToken[\(whichServer)] \(String(describing: JamfProServer.authExpires[whichServer]))")


        if !( JamfProServer.validToken && tokenAgeInSeconds < (JamfProServer.authExpires) ) {
            
            let authType = ( JamfProServer.useApiClient == 0 ) ? "username / password":"API client / secret"
            WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] \(whichServer.localizedCapitalized) is using \(authType) for authenication")
            WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] Attempting to retrieve token from \(String(describing: tokenUrl))")
            
            if apiClient {
                let clientString = "grant_type=client_credentials&client_id=\(String(describing: user))&client_secret=\(String(describing: password))"
//                print("[getToken] \(whichServer) clientString: \(clientString)")

                let requestData = clientString.data(using: .utf8)
                request.httpBody = requestData
                configuration.httpAdditionalHeaders = ["Content-Type" : "application/x-www-form-urlencoded", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                JamfProServer.currentCred = clientString
            } else {
//                print("[getToken] theCreds: \(theCreds)")
                JamfProServer.currentCred = base64creds
                
                configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(JamfProServer.currentCred)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
            }
            
            print("[getToken] generating token, tokenUrlString: \(tokenUrlString)")
//            print("[getToken]    \(whichServer) base64creds: \(base64creds)")
            
            let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) {
                            if let endpointJSON = json as? [String: Any] {
                                JamfProServer.accessToken   = apiClient ? (endpointJSON["access_token"] as? String ?? "")!:(endpointJSON["token"] as? String ?? "")!
//                                print("[getToken] \(whichServer) token: \(String(describing: JamfProServer.accessToken[whichServer]))")
                                
                                if apiClient {
                                    JamfProServer.authExpires = (endpointJSON["expires_in"] as? Double ?? 60.0)!
                                } else {
                                    JamfProServer.authExpires = (endpointJSON["expires"] as? Double ?? 20.0)!*60
                                }
                                JamfProServer.authExpires  = JamfProServer.authExpires*0.75
                                JamfProServer.tokenCreated = Date()
                                JamfProServer.validToken   = true
                                JamfProServer.authType     = "Bearer"
                                
                                //                      print("[JamfPro] result of token request: \(endpointJSON)")
                                WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] new token created for \(serverUrl)")
                                WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] token will be renewed: \(renew)")
                                
                                if JamfProServer.version == "" {
                                    // get Jamf Pro version - start
                                    ApiAction.shared.action(serverUrl: serverUrl, endpoint: "jamf-pro-version", token: JamfProServer.accessToken, method: "GET") {
                                        (result: [String:Any]) in
                                        let versionString = result["version"] as! String
                                        
                                        if versionString != "" {
                                            WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] Jamf Pro Version: \(versionString)")
                                            JamfProServer.version = versionString
                                            let tmpArray = versionString.components(separatedBy: ".")
                                            if tmpArray.count > 2 {
                                                for i in 0...2 {
                                                    switch i {
                                                    case 0:
                                                        JamfProServer.majorVersion = Int(tmpArray[i]) ?? 0
                                                    case 1:
                                                        JamfProServer.minorVersion = Int(tmpArray[i]) ?? 0
                                                    case 2:
                                                        let tmp = tmpArray[i].components(separatedBy: "-")
                                                        JamfProServer.patchVersion = Int(tmp[0]) ?? 0
                                                        if tmp.count > 1 {
                                                            JamfProServer.build = tmp[1]
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                                if ( JamfProServer.majorVersion > 10 || (JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34) ) {
                                                    JamfProServer.authType = "Bearer"
                                                    WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] \(serverUrl) set to use OAuth")
                                                    
                                                } else {
                                                    JamfProServer.authType    = "Basic"
                                                    JamfProServer.accessToken = base64creds
                                                    WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] \(serverUrl) set to use Basic")
                                                }
                                                if JamfProServer.authType == "Bearer" {
//                                                    WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] call token refresh process for \(serverUrl)")
                                                }
                                                completion((200, "success"))
                                                
                                                if renew {
                                                    WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] server token renews in \(JamfProServer.authExpires) seconds")
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + JamfProServer.authExpires) { [self] in
                                                        WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] renewing token")
                                                        getToken(whichServer: whichServer, serverUrl: serverUrl, renew: true) {
                                                            (result: (Int, String)) in
                                                        }
                                                    }
                                                }
                                                return
                                            }
                                        }
                                    }
                                    // get Jamf Pro version - end
                                } else {
                                    if renew {
                                        WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] server token renews in \(JamfProServer.authExpires) seconds")
                                        DispatchQueue.main.asyncAfter(deadline: .now() + JamfProServer.authExpires) { [self] in
                                            WriteToLog.shared.message(stringOfText: "[JamfPro.getVersion] renewing token")
                                            getToken(whichServer: whichServer, serverUrl: serverUrl, renew: true) {
                                                (result: (Int, String)) in
                                            }
                                        }
                                    }
                                    completion((200, "success"))
                                    return
                                }
                            } else {    // if let endpointJSON error
                                WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] JSON error.\n\(String(describing: json))")
                                JamfProServer.validToken = false
                                isRunning = false
                                completion((httpResponse.statusCode, "failed"))
                                return
                            }
                        } else {
                            // server down?
                            _ = Alert.shared.display(header: "", message: "Failed to get an expected response from \(String(describing: serverUrl)).", secondButton: "")
                            WriteToLog.shared.message(stringOfText: "[TokenDelegate.getToken] Failed to get an expected response from \(String(describing: serverUrl)). Status Code: \(httpResponse.statusCode)")
                            JamfProServer.validToken = false
                            isRunning = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        isRunning = false
                        _ = Alert.shared.display(header: "\(serverUrl)", message: "Failed to authenticate to \(serverUrl). \nStatus Code: \(httpResponse.statusCode)", secondButton: "")
                        WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] Failed to authenticate to \(serverUrl). Response error: \(httpResponse.statusCode)")
                        JamfProServer.validToken  = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                        
                    }
                } else {
                    isRunning = false
                    _ = Alert.shared.display(header: "\(serverUrl)", message: "Failed to connect. \nUnknown error, verify url and port.", secondButton: "")
                    WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] token response error from \(serverUrl). Verify url and port")
                    JamfProServer.validToken = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
//            WriteToLog.shared.message(stringOfText: "[JamfPro.getToken] Use existing token from \(String(describing: tokenUrl))")
            completion((200, "success"))
            return
        }
    }
    
    func objectByName(endpoint: String, endpointData: [Int:String], completion: @escaping (_ result: String) -> Void) {
        if endpointData.count == 0 {
            completion("nothing to build")
            return
        }
        // get all objects
//        print("[objectByName] endpoint: \(endpoint)")
//        print("[objectByName] endpointData: \(endpointData)")
        var counter          = 0
        for (objectID, objectName) in endpointData {
            // get individual object
            capiGetObject(id: "\(objectID)", objectType: endpoint) {
                (result: [String:AnyObject]) in
                objectByNameDict[objectName] = result
                counter+=1
                if counter == endpointData.count {
                    completion("built")
                }
            }
        }
    }
    
    func capiGetObject(id: String, objectType: String, completion: @escaping (_ result: [String:AnyObject]) -> Void) {
        
        if stopScan {
            completion([:])
            return
        }

        let apiEndpoint      = endpointDict[objectType]![0]
        var returnedRecord   = [String:AnyObject]()
         URLCache.shared.removeAllCachedResponses()
 //        let semaphore = DispatchSemaphore(value: 1)
         detailQ.maxConcurrentOperationCount = 4
         let semaphore = DispatchSemaphore(value: 0)
         
         detailQ.addOperation { [self] in
 //        let idUrl = self.endpointUrl+"/id/\(id)"
             var idUrl = "\(JamfProServer.server)/JSSResource/\(apiEndpoint)/id/\(id)"
             idUrl = idUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
         WriteToLog.shared.message(stringOfText: "[getDetails] idUrl: \(idUrl)")
         

             let encodedURL          = NSURL(string: idUrl)
             let request             = NSMutableURLRequest(url: encodedURL! as URL)
             
             request.httpMethod = "GET"
             let serverConf = URLSessionConfiguration.ephemeral
             serverConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.accessToken)", "User-Agent" : AppInfo.userAgentHeader, "Content-Type" : "application/json", "Accept" : "application/json"]
             let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
             let task = serverSession.dataTask(with: request as URLRequest, completionHandler: {
                 (data, response, error) -> Void in
                 serverSession.finishTasksAndInvalidate()
                 if let httpResponse = response as? HTTPURLResponse {
                     if httpResponse.statusCode > 199 && httpResponse.statusCode <= 299 {
                        
                         let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                         if let endpointJSON = json as? [String: Any] {
//                             print("[ViewController.getDetails] endpoint: \(apiEndpoint)")
//                             print("[ViewController.getDetails] endpointJSON: \(endpointJSON)")
//                             print("[ViewController.getDetails] endpointDict[objectType]![2]: \(endpointDict[objectType]![2])")
                             
                             if let endpointInfo = endpointJSON["\(endpointDict[objectType]![2])"] as? [String : AnyObject] {
                                 returnedRecord = endpointInfo
 //                                print("[ViewController.getDetails] endpointInfo: \(endpointInfo)")
 //                                print("[getDetails] self.singleEndpointXmlTag: \(self.singleEndpointXmlTag)")
                             } else {
                                 WriteToLog.shared.message(stringOfText: "getDetails: if let endpointInfo = endpointJSON[\(apiEndpoint)], id='\(id)' error.)\n\(idUrl)")
                             }
                         }  else {  // if let serverEndpointJSON - end
                             WriteToLog.shared.message(stringOfText: "getDetails - existing endpoints: error serializing JSON: \(String(describing: error))")
                         }
 //                    }   // end do

 //                        print("returning from: \(idUrl)\n")
 //                        print("getDetails - theRecord: \(theRecord)")
                         completion(returnedRecord)
                     } else {
                         // something went wrong
                         WriteToLog.shared.message(stringOfText: "[getDetails] lookup failed for \(idUrl)")
                         WriteToLog.shared.message(stringOfText: "[getDetails] status code: \(httpResponse.statusCode)")
                         Log.FailedCount+=1
                         Log.lookupFailed = true
                         completion([:])
                     }   // if httpResponse.statusCode - end
                 } else {   // if let httpResponse = response - end
                     WriteToLog.shared.message(stringOfText: "[getDetails] lookup failed, no response for: \(idUrl)")
                     Log.FailedCount+=1
                     Log.lookupFailed = true
                     completion([:])
                 }
                 semaphore.signal()
             })   // let task = serverSession.dataTask - end
             task.resume()
             semaphore.wait()
         }   // detailQ - end
     }
    
    func jpapiGET(endpoint: String, page: String = "", pageSize: String = "", apiData: [String:Any], id: String, token: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        
        if stopScan {
            completion([:])
            return
        }
        
        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "buildings", "csa/token", "icon", "jamf-pro-version":
            path = "v1/\(endpoint)"
        case  "computer-prestages":
            path = "v3/\(endpoint)"
        default:
            path = "v2/\(endpoint)"
        }
        
        if page != "" && pageSize != "" {
            path = path + "?page=\(page)&page-size=\(pageSize)&sort=id%3Adesc"
        }

        var urlString = "\(JamfProServer.server)/api/\(path)"
        urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
        if id != "" && id != "0" {
            urlString = urlString + "/\(id)"
        }
    //        print("[Jpapi] urlString: \(urlString)")
        
        let url            = URL(string: "\(urlString)")
        let configuration  = URLSessionConfiguration.default
        var request        = URLRequest(url: url!)
        request.httpMethod = "GET"
        
        if apiData.count > 0 {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: apiData, options: .prettyPrinted)
            } catch let error {
                print(error.localizedDescription)
            }
        }
        
        WriteToLog.shared.message(stringOfText: "[Jpapi.action] Attempting \(String(describing: request.httpMethod)) on \(urlString)")
    //        print("[Jpapi.action] Attempting \(method) on \(urlString).")
                
        configuration.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.accessToken)", "User-Agent" : AppInfo.userAgentHeader, "Content-Type" : "application/json", "Accept" : "application/json"]
        
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    
    //                    print("[jpapi] endpoint: \(endpoint)")
                    
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String:Any] {
                        WriteToLog.shared.message(stringOfText: "[Jpapi.action] Data retrieved from \(urlString)")
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        WriteToLog.shared.message(stringOfText: "[Jpapi.action] JSON error.  Returned data: \(String(describing: json))")
                        completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                WriteToLog.shared.message(stringOfText: "[Jpapi.action] Response error: \(httpResponse.statusCode)")
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? "undefined", "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                WriteToLog.shared.message(stringOfText: "[Jpapi.action] GET response error.  Verify url and port")
                completion([:])
                return
            }
        })
        task.resume()
        
    }   // func action - end
}
