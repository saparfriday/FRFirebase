//
//  FRFirebaseSignType.swift
//  
//
//  Created by user on 31.10.2021.
//

import Foundation

public enum FRFirebaseSignType {
    case google
    case facebook
    case apple
    case phone(_ smsCode: String, _ verificationID: String)
    case customPhone(_ token: String, _ phoneNumber: String)
}
