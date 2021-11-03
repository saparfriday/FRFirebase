//
//  File.swift
//  
//
//  Created by user on 31.10.2021.
//

import UIKit
import Firebase
import FirebaseAuth
import CryptoKit
import AuthenticationServices
import FacebookLogin
import GoogleSignIn

public class FRFirebaseSign: NSObject {
    
    // MARK: - Data
    
    private let viewController: UIViewController
    
    private weak var delegate: FRFirebaseSignDelegate?
    
    private var currentNonce: String?
    
    public var phoneNumber: String?
    
    // MARK: - Init
    
    public required init(viewController: UIViewController, delegate: FRFirebaseSignDelegate) {
        self.viewController = viewController
        self.delegate = delegate
    }
    
    // MARK: - Public
    
    public func sign(type: FRFirebaseSignType) {
        switch type {
        case .google:
            
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                delegate?.signFailure(.googleClientId)
                return
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.signIn(with: config, presenting: viewController) { [unowned self] user, error in
                if let error = error {
                    delegate?.signFailure(.with(error))
                    return
                }
                guard let authentication = user?.authentication, let idToken = authentication.idToken else {
                    delegate?.signFailure(.googleToken)
                    return
                }
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authentication.accessToken)
                sign(with: credential, type: type)
            }
            
        case .facebook:
            
            LoginManager().logIn(permissions: [], from: nil) { [weak self] (result, error) in
                if let error = error {
                    self?.delegate?.signFailure(.with(error))
                    return
                }
                if let result = result, result.isCancelled {
                    self?.delegate?.signFailure(.isCancelled)
                    return
                }
                let credential = FacebookAuthProvider.credential(withAccessToken: AccessToken.current!.tokenString)
                self?.sign(with: credential, type: type)
            }
            
        case .apple:
            
            let nonce = randomNonceString()
            currentNonce = nonce
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        
        case .phone(let smsCode, let verificationID):
            
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: smsCode)
            sign(with: credential, type: type)
            
        case .customPhone(let token, let phoneNumber):
            
            sign(with: token, type: type, phoneNumber: phoneNumber)
        }
    }
    
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
    
    // MARK: - Private
    
    private func sign(with credentials: AuthCredential, type: FRFirebaseSignType) {
        delegate?.signSuccess(.loading)
        Auth.auth().signIn(with: credentials) { [weak self] (authResult, error) in
            
            if let error = error {
                self?.delegate?.signFailure(.with(error))
                return
            }
            
            guard let authData = authResult else {
                self?.delegate?.signFailure(.authResult)
                return
            }
            
            self?.prepareUser(type: type, authData: authData) { user in
                self?.delegate?.signSuccess(.success(user))
            }
        }
    }
    
    private func sign(with token: String, type: FRFirebaseSignType, phoneNumber: String?) {
        delegate?.signSuccess(.loading)
        Auth.auth().signIn(withCustomToken: token) { [weak self] (authResult, error) in
            
            if let error = error {
                self?.delegate?.signFailure(.with(error))
                return
            }
            
            guard let authData = authResult else {
                self?.delegate?.signFailure(.authResult)
                return
            }
            
            self?.prepareUser(type: type, authData: authData) { user in
                
                var mutableUser = user
                if let phoneNumber = phoneNumber {
                    mutableUser.phone = phoneNumber
                }
                
                self?.delegate?.signSuccess(.success(mutableUser))
            }
        }
    }
    
    private func prepareUser(type: FRFirebaseSignType, authData: AuthDataResult, completion: @escaping (FRFirebaseSignUser) -> Void) {
        var user = FRFirebaseSignUser(uid: authData.user.uid, type: type)
        
        switch type {
        case .facebook:
            print("facebook")
        case .google:
            if let googleUser = GIDSignIn.sharedInstance.currentUser,
               let profile = googleUser.profile {
                user.name = profile.name
                user.email = profile.email
            }
        case .apple:
            if let name = authData.user.displayName {
                user.name = name
            }
            if let email = authData.user.email {
                user.email = email
            }
        case .phone:
            if let phoneNumber = authData.user.phoneNumber {
                user.phone = phoneNumber
            }
        case .customPhone(_, _):
            print("nothing")
        }
        completion(user)
    }
    
}

// MARK: - Apple

extension FRFirebaseSign: ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    
    // ASAuthorizationControllerPresentationContextProviding
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        viewController.view.window ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    }
    
    // ASAuthorizationControllerDelegate
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            let credentials = OAuthProvider.credential(withProviderID: "apple.com",
                                                       idToken: idTokenString,
                                                       rawNonce: nonce)
            
            sign(with: credentials, type: .apple)
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        delegate?.signFailure(.with(error))
    }
    
    // Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            randoms.forEach { random in
                if length == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
}
