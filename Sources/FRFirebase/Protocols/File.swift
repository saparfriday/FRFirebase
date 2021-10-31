//
//  File.swift
//  
//
//  Created by user on 31.10.2021.
//

import Foundation

public enum FRFirebaseSignError {
    case isCancelled
    case dismiss
    case with(Error)
    case authResult
    case googleClientId
    case googleToken
}

public enum FRFirebaseSignSuccess {
    case success(FRFirebaseSignUser)
    case loading
}

protocol FRFirebaseSignDelegate: AnyObject {
    
    func signFailure(_ error: FRFirebaseSignError)
    
    func signSuccess(_ success: FRFirebaseSignSuccess)
    
}
