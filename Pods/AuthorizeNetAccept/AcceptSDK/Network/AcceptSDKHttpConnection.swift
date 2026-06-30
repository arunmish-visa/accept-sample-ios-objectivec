//
//  HttpConnection.swift
//  AcceptSDK
//
//  Created by Ramamurthy, Rakesh Ramamurthy on 7/11/16.
//  Copyright © 2016 Ramamurthy, Rakesh Ramamurthy. All rights reserved.
//

import Foundation

class HttpConnection{
    var http : HTTP?
    
    fileprivate let requestQueue : DispatchQueue
    fileprivate let responseQueue : DispatchQueue
    
    init () {
        self.requestQueue = DispatchQueue(label: "AcceptSDKRequestQueue", attributes: [])
        self.responseQueue = DispatchQueue.main
        self.http = HTTP()
    }
    
    func performPostRequest(_ url : String, httpHeaders : Dictionary<String, AnyObject>?, bodyParameters:String?, success : @escaping (Dictionary<String, AnyObject>) -> (), failure : @escaping (NSError) -> ()) {
        self.performRequestAsynchronously(url, method: "POST", httpHeaders: httpHeaders, bodyParameters: bodyParameters, success: success, failure: failure)
    }

    func performRequestAsynchronously (_ url : String, method : String, httpHeaders : Dictionary<String, AnyObject>?, bodyParameters:String?, success : @escaping (Dictionary<String, AnyObject>) -> (), failure : @escaping (NSError) -> ()) {
        
        self.requestQueue.async(execute: {
            
            let request = HttpRequest(httMethod: method, url: url, httpHeaders: httpHeaders, bodyParameters:bodyParameters)

            let response : HTTPResponse = self.http!.request(request)
            
            self.responseQueue.async(execute: {
                // SECURITY (AISAST-10660): Use optional binding for both
                // response.error and response.body. Both are server-controlled
                // (error is constructed from server HTTP status; body is the
                // parsed response dictionary). Force-unwrapping either would
                // crash the host app under MitM preconditions:
                //   - response.error! traps if the success path forgot to set
                //     error before invoking failure
                //   - response.body! traps when deserializeData() returned nil
                //     (e.g. MitM-injected top-level JSON array, scalar, or
                //     non-dictionary response)
                if let err = response.error {
                    failure(err)
                } else if let body = response.body {
                    success(body)
                } else {
                    failure(NSError(
                        domain: "MalformedResponseBody",
                        code: HTTPErrorResponseCode.apiErrorResponseCode,
                        userInfo: [NSLocalizedDescriptionKey:
                            "Response body was nil or not a JSON object."]))
                }
            })
        })
    }
}

