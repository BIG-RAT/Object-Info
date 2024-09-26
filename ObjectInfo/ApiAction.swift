//
//  ApiAction.swift
//  Object Info
//
//  Created by Leslie Helou on 6/25/19.
//  Copyright © 2019 jamf. All rights reserved.
//

import Cocoa
import Foundation

class ApiAction: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    
    static let shared = ApiAction()
    private override init() { }
    
    var theApiQ = OperationQueue() // create operation queue for API calls
    init(theApiQ: OperationQueue = OperationQueue()) {
        self.theApiQ = theApiQ
    }
    
    func action(serverUrl: String, endpoint: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String:Any]) -> Void) {
        
        if stopScan {
            completion([:])
            return
        }
        
        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "jamf-pro-version":
            path = "v1/\(endpoint)"
        default:
            path = "v2/\(endpoint)"
        }

        var urlString = "\(serverUrl)/uapi/\(path)"
        urlString     = urlString.replacingOccurrences(of: "//uapi", with: "/uapi")
//        print("[ApiAction] urlString: \(urlString)")
        
        let url            = URL(string: "\(urlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: url!)
        request.httpMethod = method

//        print("[ApiAction.action] Attempting \(method) on \(urlString).")
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String:Any] {
                        WriteToLog.shared.message(stringOfText: "[ApiAction.action] Token retrieved from \(urlString).")
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        WriteToLog.shared.message(stringOfText: "[ApiAction.action] JSON error.")
                        completion([:])
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    WriteToLog.shared.message(stringOfText: "[ApiAction.action] Response error: \(httpResponse.statusCode).")
                    completion([:])
                    return
                }
            } else {
                WriteToLog.shared.message(stringOfText: "[ApiAction.action] GET response error. Verify url and port.")
                completion([:])
                return
            }
        })
        task.resume()
            
    }   // func action - end
    
    func classic(whichServer: String, serverUrl: String, endpoint: String, method: String, completion: @escaping (_ returnedJSON: [String:Any]) -> Void) {
        
        if stopScan {
            completion([:])
            return
        }
        var urlString = "\(serverUrl)/JSSResource/\(endpoint)"
        urlString     = urlString.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
//        print("[classic] urlString: \(urlString)")
        
        let url            = URL(string: "\(urlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: url!)
        request.httpMethod = method

        print("[classic] Attempting \(method) on \(urlString)")
        print("[classic] Bearer \(JamfProServer.accessToken)")

        URLCache.shared.removeAllCachedResponses()
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                print("[classic] httpResponse: \(httpResponse)")
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String:Any] {
                        WriteToLog.shared.message(stringOfText: "[classic] Retrieved information from \(urlString).")
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        WriteToLog.shared.message(stringOfText: "[classic] JSON error.")
                        completion([:])
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    WriteToLog.shared.message(stringOfText: "[classic] Response error: \(httpResponse.statusCode).")
                    completion([:])
                    return
                }
            } else {
                WriteToLog.shared.message(stringOfText: "[classic] GET response error. Verify url and port.")
                completion([:])
                return
            }
        })
        task.resume()
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

