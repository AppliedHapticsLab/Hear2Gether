import FirebaseAuth
import UIKit
import FirebaseDatabase
import FirebaseStorage

/// ユーザーの初回ログイン時またはアカウント作成時に必要なFirebaseデータ構造を初期化する関数
func initializeUserDataStructure(for user: User, isNewUser: Bool = true, displayName: String? = nil, profileImageURL: String? = nil) {
    // Firebaseデータベース参照を取得
    let ref = Database.database().reference()
    let uid = user.uid
    
    // 1. ユーザープロフィール情報の設定
    let usernameData: [String: Any] = [
        "UName": displayName ?? user.displayName ?? "User\(Int.random(in: 1000...9999))",
        "Uimage": profileImageURL ?? user.photoURL?.absoluteString ?? ""
    ]
    
    // 2. アプリの初期状態を設定
    let appStateData: [String: Any] = [
        "CurrentMode": 0, // デフォルトで「一人で」モード
        "LastUpdated": ServerValue.timestamp(),
        "CurrentGroup": "",
        "hostID": "",
        "SelectUser": "None"
    ]
    
    // 3. Apple Watchの接続状態の初期値を設定
    let appStatusData: [String: Any] = [
        "isActive": false, // デフォルトでは非アクティブ
        "lastConnected": ServerValue.timestamp(),
        "stateChangeReason":"isLogout"
    ]
    
    // 4. バイブレーション設定のデフォルト値
    let vibrationData: [String: Any] = [
        "Number": 2, // デフォルト強度 (0=Low, 1=Medium, 2=High)
        "RecordStart": false, // 記録開始状態のデフォルト値
        "SelectUser": "", // 選択中のユーザーID
        "SelectUserName": "", // 選択中のユーザー名
        "Toggle": false // バイブレーション機能のON/OFF
    ]
    
    // 5. 心拍データの初期構造
    let heartbeatData: [String: Any] = [
        "HeartRate": 60, // デフォルト心拍数
        "Timestamp": ServerValue.timestamp()
    ]
    
    // 6. 友達関係のための空のノード
    let acceptUserData: [String: Any] = [
        "permittedUser": [:],
        "permissions": [:]
    ]
    
    // データを一括で更新するための辞書を作成
    let updates: [String: Any] = [
        "Username/\(uid)": usernameData,
        "Userdata/\(uid)/AppState": appStateData,
        "Userdata/\(uid)/AppStatus": appStatusData,
        "Userdata/\(uid)/MyPreference/Vibration": vibrationData,
        "Userdata/\(uid)/Heartbeat/Watch1": heartbeatData,
        "AcceptUser/\(uid)": acceptUserData
    ]
    
    // 一括で更新を実行
    ref.updateChildValues(updates) { error, _ in
        if let error = error {
            print("Firebase初期データ構造の作成に失敗しました: \(error.localizedDescription)")
        } else {
            print("Firebase初期データ構造を正常に作成しました: UID=\(uid)")
            
            // 新規ユーザーかつプロフィール画像がない場合、デフォルト画像をアップロード
            if isNewUser && (profileImageURL == nil || profileImageURL?.isEmpty == true) {
                uploadDefaultProfileImage(for: uid)
            }
        }
    }
}

/// デフォルトのプロフィール画像をアップロードする関数
func uploadDefaultProfileImage(for uid: String) {
    guard let defaultImage = UIImage(named: "Default_icon") else {
        print("デフォルトアイコン画像が見つかりません")
        return
    }
    
    guard let imageData = defaultImage.jpegData(compressionQuality: 0.8) else {
        print("画像データの変換に失敗しました")
        return
    }
    
    let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
    
    storageRef.putData(imageData, metadata: nil) { metadata, error in
        if let error = error {
            print("デフォルト画像アップロード失敗: \(error.localizedDescription)")
            return
        }
        
        storageRef.downloadURL { url, error in
            if let error = error {
                print("ダウンロードURL取得失敗: \(error.localizedDescription)")
                return
            }
            
            if let downloadURL = url {
                // プロフィール画像URLを更新
                let ref = Database.database().reference()
                ref.child("Username").child(uid).updateChildValues(["Uimage": downloadURL.absoluteString])
                
                // ユーザープロファイルも更新
                if let user = Auth.auth().currentUser {
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.photoURL = downloadURL
                    changeRequest.commitChanges { error in
                        if let error = error {
                            print("ユーザープロファイル更新エラー: \(error.localizedDescription)")
                        }
                    }
                }
                
                print("デフォルトプロフィール画像が正常に設定されました: \(downloadURL.absoluteString)")
            }
        }
    }
}
