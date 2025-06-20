//
//  AuthViewModel.swift
//  Hear2gether
//
//  Created by Applied Haptics Laboratory on 2025/02/06.
//


// AuthViewModel.swift - 修正版
// 元の実装に isLoggedIn プロパティを追加

import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import Combine

class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    // RootView で使用される isLoggedIn プロパティを追加
    @Published var isLoggedIn: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        currentUser = Auth.auth().currentUser
        // 初期状態を設定
        isLoggedIn = currentUser != nil
        
        // ユーザーの認証状態を監視
        _ =  Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            self.currentUser = user
            // ログイン状態も更新
            self.isLoggedIn = user != nil
            
            // UserDefaultsにUUIDを保存（AppDelegateで使用）
            if let uid = user?.uid {
                UserDefaults.standard.set(uid, forKey: "UUID")
            } else {
                UserDefaults.standard.removeObject(forKey: "UUID")
            }
        }
    }
    
    // 以下、元のコードはそのまま
    
    // MARK: - Google Sign In
    func signInWithGoogle(idToken: String, accessToken: String) {
        isLoading = true
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                guard let authResult = authResult else { return }
                
                // 新規ユーザーの場合はFirebaseデータ構造を初期化
                let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false
                if isNewUser {
                    initializeUserDataStructure(for: authResult.user, isNewUser: true)
                } else {
                    // 既存ユーザーの場合は、必要に応じてデータ構造の整合性を確認・修正
                    self?.validateUserDataStructure(for: authResult.user)
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents? = nil) {
        isLoading = true
        
        let credential = OAuthProvider.credential(providerID: .apple, idToken: idToken, rawNonce: nonce, accessToken: nil)
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                guard let authResult = authResult else { return }
                
                // 名前を設定
                var displayName: String?
                if let firstName = fullName?.givenName, let lastName = fullName?.familyName {
                    displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                } else if let firstName = fullName?.givenName {
                    displayName = firstName
                } else if let lastName = fullName?.familyName {
                    displayName = lastName
                }
                
                // ユーザー名が提供された場合はユーザープロフィールを更新
                if let displayName = displayName, !displayName.isEmpty {
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    changeRequest.commitChanges { _ in }
                }
                
                // 新規ユーザーの場合はFirebaseデータ構造を初期化
                let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false
                if isNewUser {
                    initializeUserDataStructure(for: authResult.user, isNewUser: true, displayName: displayName)
                } else {
                    // 既存ユーザーの場合は、必要に応じてデータ構造の整合性を確認・修正
                    self?.validateUserDataStructure(for: authResult.user)
                }
            }
        }
    }
    
    // MARK: - Email Sign In
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                guard let user = authResult?.user else { return }
                
                // 既存ユーザーの場合は、必要に応じてデータ構造の整合性を確認・修正
                self?.validateUserDataStructure(for: user)
            }
        }
    }
    
    // MARK: - Email Registration
    func registerWithEmail(email: String, password: String, displayName: String) {
        isLoading = true
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                guard let user = authResult?.user else { return }
                
                // ユーザープロフィールを更新
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                changeRequest.commitChanges { _ in }
                
                // Firebaseデータ構造を初期化
                initializeUserDataStructure(for: user, isNewUser: true, displayName: displayName)
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Utility Functions
    
    /// 既存ユーザーのデータ構造の整合性を確認・修正
    private func validateUserDataStructure(for user: User) {
        let ref = Database.database().reference()
        let uid = user.uid
        
        // 必要なノードの存在チェック
        ref.child("Username").child(uid).observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                // Usernameノードがない場合は作成
                let usernameData: [String: Any] = [
                    "UName": user.displayName ?? "User\(Int.random(in: 1000...9999))",
                    "Uimage": user.photoURL?.absoluteString ?? ""
                ]
                ref.child("Username").child(uid).setValue(usernameData)
            }
        }
        
        ref.child("Userdata").child(uid).child("AppState").observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                // AppStateノードがない場合は作成
                let appStateData: [String: Any] = [
                    "CurrentMode": 0,
                    "LastUpdated": ServerValue.timestamp(),
                    "CurrentGroup": "",
                    "hostID": "",
                    "SelectUser": "None"
                ]
                ref.child("Userdata").child(uid).child("AppState").setValue(appStateData)
            }
        }
        
        ref.child("Userdata").child(uid).child("AppStatus").observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                // AppStatusノードがない場合は作成
                let appStatusData: [String: Any] = [
                    "isActive": false,
                    "lastConnected": ServerValue.timestamp()
                ]
                ref.child("Userdata").child(uid).child("AppStatus").setValue(appStatusData)
            }
        }
        
        ref.child("Userdata").child(uid).child("MyPreference").child("Vibration").observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                // Vibrationノードがない場合は作成
                let vibrationData: [String: Any] = [
                    "Number": 2,
                    "RecordStart": false,
                    "SelectUser": "",
                    "SelectUserName": "",
                    "Toggle": false
                ]
                ref.child("Userdata").child(uid).child("MyPreference").child("Vibration").setValue(vibrationData)
            }
        }
        
        // その他必要に応じてチェック
    }
}
