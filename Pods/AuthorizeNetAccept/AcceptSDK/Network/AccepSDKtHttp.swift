
//
//  IAPHttp.swift
//  AcceptSDK
//
//  Created by Ramamurthy, Rakesh Ramamurthy on 7/11/16.
//  Copyright © 2016 Ramamurthy, Rakesh Ramamurthy. All rights reserved.
//

import Foundation

let HTTP_TIMEOUT = TimeInterval(30)

private struct HTTPStatusCode {
    static let kHTTPSuccessCode         = 200
    static let kHTTPCreationSuccessCode = 201
}

class HttpRequest {
    var method : String?
    var url : String?
    var httpHeaders : Dictionary <String, AnyObject>?
    var bodyParameters: String?
    
    init(httMethod : String, url : String, httpHeaders : Dictionary <String, AnyObject>?, bodyParameters : String?){
        self.method = httMethod
        self.url = url
        
        if let parameters = httpHeaders {
            self.httpHeaders = parameters
        }
        
        if let parameters = bodyParameters {
            self.bodyParameters = parameters
        }
    }
    
    internal func urlRequest () -> NSMutableURLRequest {
        let result = NSMutableURLRequest(url: URL(string: self.url!)!)
//        result.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        result.setValue("application/json", forHTTPHeaderField: "Accept")
        result.timeoutInterval = HTTP_TIMEOUT
        result.httpMethod = self.method!
        
        if let parameters = self.bodyParameters {
            result.setBodyContent(parameters)
        }

        if let parameters = self.httpHeaders {
            for (headerField, value) in parameters {
                result.setValue(value as? String, forHTTPHeaderField: headerField)
            }
        }
        
        return result
    }
}

private struct HTTPErrorKeys {
    static let kErrorsKey = "errors"
    static let kErrorTypeKey = "type"
    static let kErrorMessageKey = "message"
}

struct HTTPErrorResponseCode {
    static let apiErrorResponseCode = 4000
    static let kErrorDictionaryKey  = "Error_Info_Dict"
}

class HTTPResponse {
    var code : Int?
    var body : Dictionary <String, AnyObject>?
    var error : NSError?
    
    init () {
    }
}

class HTTP: NSObject, URLSessionDelegate {
    
    func request(_ request : HttpRequest) -> HTTPResponse {
        
        let urlRequest : NSMutableURLRequest = request.urlRequest()
                
        return self.requestSynchronousData(urlRequest as URLRequest)
        
    }
    
    fileprivate func requestSynchronousData(_ request: URLRequest) -> HTTPResponse {
        let httpResponse = HTTPResponse()
        
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        
        let task = session.dataTask(with: request, completionHandler: {
            taskData, response, error -> () in
            if (error != nil) {
                httpResponse.error = error as NSError?
            }
            else if let castedResponse = response as? HTTPURLResponse {
                // SECURITY (AISAST-10660): Guard server-controlled inputs to
                // prevent app crash on MitM-injected or malformed responses.
                // taskData can be nil on legitimate empty responses; treat that
                // as a transport failure rather than crashing the host app.
                guard let safeData = taskData else {
                    httpResponse.error = NSError(domain: "EmptyResponseBody",
                        code: castedResponse.statusCode, userInfo: nil)
                    semaphore.signal()
                    return
                }
                let bodyDict = self.deserializeData(safeData)
                
                if HTTPStatusCode.kHTTPSuccessCode == castedResponse.statusCode || HTTPStatusCode.kHTTPCreationSuccessCode == castedResponse.statusCode {
                    httpResponse.body = bodyDict
                } else {
                    // SECURITY (AISAST-10660): Use optional binding instead of
                    // force-unwrap. deserializeData() can legitimately return nil
                    // on malformed/non-dictionary JSON; force-unwrapping that
                    // would crash the host app under MitM preconditions.
                    if let safeBodyDict = bodyDict {
                        let (errorMessage) = self.getErrorResponse(safeBodyDict)
                        if let message = errorMessage {
                            httpResponse.error = NSError(domain: message, code: castedResponse.statusCode, userInfo:[NSLocalizedDescriptionKey:message,HTTPErrorResponseCode.kErrorDictionaryKey:safeBodyDict])
                        } else {
                            httpResponse.error = NSError(domain: "BadResponse", code: castedResponse.statusCode, userInfo:nil)
                        }
                    } else {
                        httpResponse.error = NSError(domain: "BadResponse", code: castedResponse.statusCode, userInfo:nil)
                    }
                }
            }
            
            semaphore.signal();
        })
        task.resume()
        semaphore.wait(timeout: DispatchTime.distantFuture)
        return httpResponse
    }

    fileprivate func getErrorResponse(_ responseDict:Dictionary<String, AnyObject>)->String? {
        var errorMessage:String?
        if  let errorArray = responseDict[HTTPErrorKeys.kErrorsKey] as? [[String:String]] {
            if let error = errorArray.first {
                errorMessage = error[HTTPErrorKeys.kErrorMessageKey]
            }
        }
        return errorMessage
    }

    fileprivate func serializeJson (_ json : Dictionary <String, AnyObject>) -> Data? {
        let result : Data? = try! JSONSerialization.data(withJSONObject: json, options: [])
        
        return result;
    }
    
    fileprivate func deserializeData (_ data : Data) -> Dictionary<String, AnyObject>? {
        // SECURITY (AISAST-10660): Use conditional cast (as?) instead of forced
        // downcast (as!). A forced downcast is a Swift runtime trap (NOT a
        // throw), so the surrounding catch block CANNOT catch it — a
        // MitM-injected response containing a valid top-level JSON array,
        // scalar, or null would crash the host app before any other handler
        // runs. Returning nil on type mismatch lets callers handle the
        // malformed-response case gracefully.
        do {
            let parsed = try JSONSerialization.jsonObject(with: data,
                options: JSONSerialization.ReadingOptions.mutableContainers)
            return parsed as? Dictionary<String, AnyObject>
        } catch _ as NSError {
            return nil
        }
    }
}

extension NSMutableURLRequest {
    @objc func setBodyContent(_ contentStr: String?) {
        self.httpBody = contentStr!.data(using: String.Encoding.utf8)
    }
}
