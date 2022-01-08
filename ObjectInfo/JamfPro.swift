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
    
    
    func getVersion(jpURL: String, basicCreds: String, completion: @escaping (_ jpversion: [Int]) -> Void) {
        var versionString  = ""
        var versionArray   = [Int]()
        let semaphore      = DispatchSemaphore(value: 0)
        
        OperationQueue().addOperation {
            let encodedURL     = NSURL(string: "\(jpURL)/JSSCheckConnection")
            let request        = NSMutableURLRequest(url: encodedURL! as URL)
            request.httpMethod = "GET"
            let configuration  = URLSessionConfiguration.default
            let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
//                if let httpResponse = response as? HTTPURLResponse {
                    versionString = String(data: data!, encoding: .utf8) ?? ""
//                    print("httpResponse: \(httpResponse)")
//                    print("raw versionString: \(versionString)")
                    if versionString != "" {
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
                        }
                    }
//                }
                print("JamfProVersion: \(JamfProServer.majorVersion).\(JamfProServer.minorVersion)")
                if ( JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34 ) {
                    getToken(serverUrl: jpURL, base64creds: basicCreds) {
                        (returnedToken: String) in
                        completion(versionArray)
                    }
                } else {
                    completion(versionArray)
                }
            })  // let task = session - end
            task.resume()
            semaphore.wait()
        }
    }
    
    func getToken(serverUrl: String, base64creds: String, completion: @escaping (_ returnedToken: String) -> Void) {
        
        if serverUrl.prefix(4) != "http" {
            completion("skipped")
            return
        }
        URLCache.shared.removeAllCachedResponses()
                
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
    //        print("\(tokenUrlString)")
        
        let tokenUrl       = URL(string: "\(tokenUrlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"
        
        WriteToLog().message(stringOfText: ["[JamfPro.getToken] Attempting to retrieve token from \(String(describing: tokenUrlString))."])
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String: Any], let _ = endpointJSON["token"], let _ = endpointJSON["expires"] {
                        
                        token.stringValue = endpointJSON["token"] as! String
                        token.expires     = "\(endpointJSON["expires"] ?? "")"
                        print("\n[JamfPro.getToken]  token string: \(token.stringValue)")
                        print("[JamfPro.getToken] token expires: \(token.expires)\n")
                        if token.stringValue != "" {
                            JamfProServer.authType = "Bearer"
                            JamfProServer.authCreds = token.stringValue
                        } else {
                            JamfProServer.authType = "Basic"
                            JamfProServer.authCreds = base64creds
                        }
                      
//                        if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Retrieved token: \(token)\n") }
//                        print("[TokenDelegate] result of token request: \(endpointJSON)")
                        self.refresh(server: serverUrl, b64Creds: base64creds)
                        completion("renewed")
                        return
                    } else {    // if let endpointJSON error
//                        if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getToken] JSON error.\n\(String(describing: json))\n") }
                        completion("failed")
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
//                    if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getToken] response error: \(httpResponse.statusCode).\n") }
                    completion("failed")
                    return
                }
            } else {
//                if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getToken] token response error.  Verify url and port.\n") }
                completion("failed")
                return
            }
        })
        task.resume()
    }
    
    func refresh(server: String, b64Creds: String) {
        renewQ.async { [self] in
//        sleep(30)
            sleep(token.refreshInterval)
            getToken(serverUrl: server, base64creds: b64Creds) {
                (result: String) in
//                print("[TokenDelegate] returned token: \(result)")
            }
        }
    }
}
