//
//  JamfPro.swift
//  Object Info
//
//  Created by Leslie Helou on 01/08/22.
//  Copyright © 2022 Leslie Helou. All rights reserved.
//

import Foundation

class JamfPro: NSObject, URLSessionDelegate {
    
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
            configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
            let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let _ = response as? HTTPURLResponse {
                    
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String:String?], let _ = endpointJSON["version"]! {
                        JamfProServer.version = endpointJSON["version"]!!
                        WriteToLog().message(stringOfText: ["[JamfPro.getVersion] \(jpURL) is running v\(JamfProServer.version)"])
                    } else {
                        WriteToLog().message(stringOfText: ["[JamfPro.getVersion] unable to get version for \(jpURL)"])
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
    
    func getToken(serverUrl: String, base64creds: String, completion: @escaping (_ authResult: (Int,String)) -> Void) {
       
//        print("\(serverUrl.prefix(4))")
        if serverUrl.prefix(4) != "http" {
            completion((0, "skipped"))
            return
        }
        URLCache.shared.removeAllCachedResponses()
                
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
    //        print("\(tokenUrlString)")
        
        let tokenUrl       = URL(string: "\(tokenUrlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"
        
        let (_, minutesOld, _) = timeDiff(forWhat: "tokenAge")
//        print("[JamfPro] \(whichServer) tokenAge: \(minutesOld) minutes")
        if !token.isValid || (minutesOld > token.refreshInterval) {
            WriteToLog().message(stringOfText: ["[JamfPro.getToken] Attempting to retrieve token from \(String(describing: tokenUrl!)) for version look-up"])
            
            configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
            let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json! as? [String: Any], let _ = endpointJSON["token"], let _ = endpointJSON["expires"] {
                            token.isValid  = true
                            JamfProServer.authCreds   = endpointJSON["token"] as? String ?? ""
                            token.expires             = "\(endpointJSON["expires"] ?? "")"
                            JamfProServer.authType    = "Bearer"
                            JamfProServer.base64Creds = base64creds

                            token.created = Date()
                            
    //                      if LogLevel.debug { WriteToLog().message(stringOfText: "[JamfPro.getToken] Retrieved token: \(token)") }
    //                      print("[JamfPro] result of token request: \(endpointJSON)")
                            WriteToLog().message(stringOfText: ["[JamfPro.getToken] new token created for \(serverUrl)"])
                            
                            if JamfProServer.version == "" {
                                // get Jamf Pro version - start
                                getVersion(jpURL: serverUrl, token: JamfProServer.authCreds) {
                                    (result: (Int,Int,Int)) in
                                    (JamfProServer.majorVersion,JamfProServer.minorVersion,JamfProServer.patchVersion) = result

                                    if JamfProServer.majorVersion != 0 {
                                        if ( JamfProServer.majorVersion > 10 || (JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34) ) {
                                            JamfProServer.authType = "Bearer"
                                            WriteToLog().message(stringOfText: ["[JamfPro.getVersion] \(serverUrl) set to use OAuth"])
                                            
                                        } else {
                                            JamfProServer.authType  = "Basic"
//                                            JamfProServer.accessToken = base64creds
                                            WriteToLog().message(stringOfText: ["[JamfPro.getVersion] \(serverUrl) set to use Basic"])
                                        }
                                        
                                        completion((200, "success"))
                                        return
                                        
                                        
//                                        if ( JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34 ) {
//                                            JamfProServer.authType = "Bearer"
//                                            WriteToLog().message(stringOfText: ["[JamfPro.getVersion] \(serverUrl) set to use Bearer Token"])
//                                            
//                                        } else {
//                                            JamfProServer.authType  = "Basic"
//                                            JamfProServer.authCreds = base64creds
//                                            WriteToLog().message(stringOfText: ["[JamfPro.getVersion] \(serverUrl) set to use Basic Authentication"])
//                                        }
//                                        if JamfProServer.authType == "Bearer" {
//                                            self.refresh(server: serverUrl, b64Creds: JamfProServer.base64Creds)
//                                        }
//                                        completion((200, "success"))
//                                        return
                                    } else {   // if let versionString - end
                                        WriteToLog().message(stringOfText: ["[JamfPro.getToken] failed to get version information from \(String(describing: serverUrl))"])
                                        token.isValid  = false
//                                        _ = Alert().display(header: "Attention", message: "Failed to get version information from \(String(describing: serverUrl))", secondButton: "")
                                        completion((httpResponse.statusCode, "failed"))
                                        return
                                    }
                                }
                                // get Jamf Pro version - end
                            } else {
                                
//                                if JamfProServer.authType == "Bearer" {
//                                    WriteToLog().message(stringOfText: ["[JamfPro.getVersion] call token refresh process for \(serverUrl)"])
//                                    self.refresh(server: serverUrl, b64Creds: JamfProServer.base64Creds)
//                                }
//                                completion((200, "success"))
//                                return
                            }
                            
                            // call token refresh
                            if JamfProServer.authType == "Bearer" {
                                WriteToLog().message(stringOfText: ["[JamfPro.getToken] call token refresh process after \(token.refreshInterval) minutes for \(serverUrl)"])
                                DispatchQueue.main.asyncAfter(deadline: .now() + Double(token.refreshInterval)*60) { [self] in
                                    if !isRunning {
                                        token.isValid = false
                                        WriteToLog().message(stringOfText: ["[JamfPro.getToken] terminated token refresh"])
                                        return
                                    } else {
                                        getToken(serverUrl: serverUrl, base64creds: base64creds) {
                                            (result: (Int, String)) in
                            //                print("[JamfPro.refresh] returned: \(result)")
                                        }
                                    }
                                }
//                                                    WriteToLog().message(stringOfText: "[JamfPro.getVersion] call token refresh process for \(serverUrl)")
                            }
                            
                        } else {    // if let endpointJSON error
                            WriteToLog().message(stringOfText: ["[JamfPro.getToken] JSON error.\n\(String(describing: json))"])
                            token.isValid = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        WriteToLog().message(stringOfText: ["[JamfPro.getToken] Failed to authenticate to \(serverUrl).  Response error: \(httpResponse.statusCode)."])
//                           _ = Alert().display(header: "\(serverUrl)", message: "Failed to authenticate to \(serverUrl). \nStatus Code: \(httpResponse.statusCode)", secondButton: "")
                        token.isValid = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                    }
                } else {
//                    _ = Alert().display(header: "\(serverUrl)", message: "Failed to connect. \nUnknown error, verify url and port.", secondButton: "")
                    WriteToLog().message(stringOfText: ["[JamfPro.getToken] token response error from \(serverUrl).  Verify url and port."])
                    token.isValid = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
            WriteToLog().message(stringOfText: ["[JamfPro.getToken] Use existing token from \(String(describing: tokenUrl!))"])
            completion((200, "success"))
            return
        }
    }
    
    func refresh(server: String, b64Creds: String) {
//        if controller!.go_button.title == "Stop" {
        if !isRunning {
            token.isValid = false
            WriteToLog().message(stringOfText: ["[JamfPro.refresh] terminated token refresh"])
            return
        }
        WriteToLog().message(stringOfText: ["[JamfPro.refresh] queue token refresh"])
        renewQ.async { [self] in
            sleep(token.refreshInterval)
            token.isValid = false
            getToken(serverUrl: server, base64creds: b64Creds) {
                (result: (Int, String)) in
//                print("[JamfPro.refresh] returned: \(result)")
            }
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
         WriteToLog().message(stringOfText: ["[getDetails] idUrl: \(idUrl)"])
         

             let encodedURL          = NSURL(string: idUrl)
             let request             = NSMutableURLRequest(url: encodedURL! as URL)
             
             request.httpMethod = "GET"
             let serverConf = URLSessionConfiguration.ephemeral
             serverConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.authCreds)", "User-Agent" : AppInfo.userAgentHeader, "Content-Type" : "application/json", "Accept" : "application/json"]
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
                                 WriteToLog().message(stringOfText: ["getDetails: if let endpointInfo = endpointJSON[\(apiEndpoint)], id='\(id)' error.)\n\(idUrl)"])
                             }
                         }  else {  // if let serverEndpointJSON - end
                             WriteToLog().message(stringOfText: ["getDetails - existing endpoints: error serializing JSON: \(String(describing: error))"])
                         }
 //                    }   // end do

 //                        print("returning from: \(idUrl)\n")
 //                        print("getDetails - theRecord: \(theRecord)")
                         completion(returnedRecord)
                     } else {
                         // something went wrong
                         WriteToLog().message(stringOfText: ["[getDetails] lookup failed for \(idUrl)"])
                         WriteToLog().message(stringOfText: ["[getDetails] status code: \(httpResponse.statusCode)"])
                         Log.FailedCount+=1
                         Log.lookupFailed = true
                         completion([:])
                     }   // if httpResponse.statusCode - end
                 } else {   // if let httpResponse = response - end
                     WriteToLog().message(stringOfText: ["[getDetails] lookup failed, no response for: \(idUrl)"])
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
    
    func jpapiGET(endpoint: String, apiData: [String:Any], id: String, token: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        
        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "buildings", "csa/token", "icon", "jamf-pro-version":
            path = "v1/\(endpoint)"
        default:
            path = "v2/\(endpoint)"
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
        
        WriteToLog().message(stringOfText: ["[Jpapi.action] Attempting \(String(describing: request.httpMethod)) on \(urlString)"])
    //        print("[Jpapi.action] Attempting \(method) on \(urlString).")
        
//        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
        
        configuration.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.authCreds)", "User-Agent" : AppInfo.userAgentHeader, "Content-Type" : "application/json", "Accept" : "application/json"]
        
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    
    //                    print("[jpapi] endpoint: \(endpoint)")
                    
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String:Any] {
                        WriteToLog().message(stringOfText: ["[Jpapi.action] Data retrieved from \(urlString)"])
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        WriteToLog().message(stringOfText: ["[Jpapi.action] JSON error.  Returned data: \(String(describing: json))"])
                        completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                WriteToLog().message(stringOfText: ["[Jpapi.action] Response error: \(httpResponse.statusCode)"])
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? "undefined", "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                WriteToLog().message(stringOfText: ["[Jpapi.action] GET response error.  Verify url and port"])
                completion([:])
                return
            }
        })
        task.resume()
        
    }   // func action - end

    
}
