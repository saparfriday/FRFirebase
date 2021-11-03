//
//  File.swift
//  
//
//  Created by user on 03.11.2021.
//

import Foundation

public enum FRFirebaseSignPhoneVerifyResult {
    case success(_ verificationID: String)
    case with(_ error: Error)
    case verificationIdNotFound
}
