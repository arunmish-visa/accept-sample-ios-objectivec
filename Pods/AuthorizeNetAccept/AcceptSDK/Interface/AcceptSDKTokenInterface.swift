//
//  AcceptSDKTokenInterface.swift
//  AcceptSDK
//
//  Created by Ramamurthy, Rakesh Ramamurthy on 7/11/16.
//  Copyright © 2016 Ramamurthy, Rakesh Ramamurthy. All rights reserved.
//

import Foundation

class AcceptSDKTokenInterface: AcceptSDKBaseInterface {
    
    func getToken(_ paymentRequest: AcceptSDKRequest, success:@escaping AcceptSDKCompletionHandlers.AcceptSDKSuccessHandler, failure:@escaping (AcceptSDKErrorResponse)->()) {
        let tokenAPIBuilder = AcceptSDKTokenAPIBuilder()
        let urlString = tokenAPIBuilder.getTokenAPIUrl()
        
        let interfaceBuilder     = AcceptSDKTokenInterfaceBuilder()

        let bodyParameterDictionary = interfaceBuilder.getRequestJSONString(paymentRequest)

        let httpConnection = HttpConnection()
        httpConnection.performPostRequest(urlString, httpHeaders: nil, bodyParameters: bodyParameterDictionary,
                        success: { (inDict:Dictionary<String, AnyObject>) -> () in
                                self.handleResponse(inDict,
                                    successHandler: { (isSuccess) -> () in
                                                    success(AcceptSDKTokenResponse(inDict:inDict))
                                                    },
                                    failureHandler: { (isSuccess) -> () in
                                                    failure(AcceptSDKErrorResponse(inMappingErrorDict: inDict))
                                                    })},
                        failure: { (inError:NSError) -> () in
                                failure(AcceptSDKErrorResponse(inError: inError))
        })
    }
    
    fileprivate func handleResponse(_ response:Dictionary<String, AnyObject>,successHandler:(_ isSuccess:Bool)->(),failureHandler:(_ isSuccess:Bool)->()) {
        // SECURITY (AISAST-c786c978): Use optional binding instead of force-unwrap
        // to prevent app crash when a (potentially MitM-injected) response omits
        // the 'messages' key. Force-unwrap of nil is a Swift runtime trap.
        guard let messagesDict = response[AcceptSDKResponse.kMessagesKey] as? Dictionary<String, AnyObject> else {
            failureHandler(false)
            return
        }
        let statusCode = messagesDict[AcceptSDKResponse.kResultCodeKey] as? String
        if  statusCode == AcceptSDKResponse.kResultCodeOkValueKey {
            successHandler(true)
        } else if statusCode == AcceptSDKResponse.kResultCodeErrorValueKey {
            failureHandler(false)
        } else {
            //some thing is missing!
            print("error handling missing!!!")
        }
    }

}
