//
//  File.swift
//  
//
//  Created by user on 31.10.2021.
//

import Foundation
import FirebaseAuth

public enum FRFirebaseSignPhoneVerifyResult {
    case success(_ verificationID: String)
    case with(_ error: Error)
    case verificationIdNotFound
}

public class FRFirebaseSignPhoneVerify {
    
    public func verify(phoneNumber: String, completion: @escaping (FRFirebaseSignPhoneVerifyResult) -> Void) {
        Auth.auth().languageCode = Locale.current.languageCode
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (verificationID, error) in
            if let error = error {
                completion(.with(error))
            }
            
            guard let verificationID = verificationID else {
                completion(.verificationIdNotFound)
                return
            }
            
            completion(.success(verificationID))
        }
    }
    
}
