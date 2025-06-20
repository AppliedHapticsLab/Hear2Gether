//
//  iPhoneWatchConnectivityService.swift
//  Hear2gether
//
//  Created by Applied Haptics Laboratory on 2025/03/17.
//


import Foundation
import WatchConnectivity
import Firebase
import FirebaseDatabase
import Combine

/// iPhone側のWatchConnectivity機能を管理するクラス
class iPhoneWatchConnectivityService: NSObject, ObservableObject, WCSessionDelegate {
    // セッション状態
    @Published var isSessionActive = false
    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false
    
    // Watch状態
    @Published var isWatchActive = false
    @Published var lastHeartRate: Int = 60
    @Published var lastHeartRateTimestamp: Double = 0
    
    // グループ配信状態
    @Published var isBroadcasting: Bool = false
    
    // 現在のユーザーID
    private var currentUserID: String = ""
    
    // Firebase参照
    private var databaseRef: DatabaseReference?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("WatchConnectivity: セッション初期化")
        } else {
            print("WatchConnectivity: このデバイスでは対応していません")
        }
    }
    
    // MARK: - ユーザーIDの設定
    func setUserID(_ userID: String) {
        self.currentUserID = userID
        self.databaseRef = Database.database().reference()
        
        // ユーザーIDが設定されたら、Watchのアクティブ状態を確認
        checkWatchActiveStatus()
    }
    
    // MARK: - WCSessionDelegate Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isSessionActive = (activationState == .activated)
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
            
            if let error = error {
                print("WatchConnectivity: 活性化エラー: \(error.localizedDescription)")
            } else {
                print("WatchConnectivity: セッション活性化完了")
            }
        }
    }
    
    // 必須メソッド（iOS専用）
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchConnectivity: セッションが非アクティブになりました")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WatchConnectivity: セッションが非アクティブ化されました")
        // 新しいセッションを再アクティベート
        WCSession.default.activate()
    }
    
    // アプリがフォアグラウンドの時のメッセージ受信
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }
    
    // レスポンスハンドラーつきのメッセージ受信
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // レスポンスが必要なメッセージを処理
        var response: [String: Any] = [:]
        
        if let messageType = message["type"] as? String {
            switch messageType {
            case "requestInitialState":
                // 初期状態リクエストへの応答
                if let userID = message["userID"] as? String, !userID.isEmpty {
                    fetchAppState(for: userID) { appState in
                        response["appState"] = appState
                        replyHandler(response)
                    }
                    return
                }
                
            case "requestHostInfo":
                // ホスト情報リクエストへの応答
                if let userID = message["userID"] as? String {
                    fetchHostInfo(for: userID) { hostName in
                        response["hostName"] = hostName
                        replyHandler(response)
                    }
                    return
                }
                
            case "requestHostHeartRate":
                // ホスト心拍数リクエストへの応答
                if let userID = message["userID"] as? String {
                    fetchHostHeartRate(for: userID) { heartRate in
                        response["heartRate"] = heartRate
                        replyHandler(response)
                    }
                    return
                }
                
            case "requestGroupInfo":
                // グループ情報リクエストへの応答
                fetchCurrentGroupInfo { groupInfo in
                    response = groupInfo
                    replyHandler(response)
                }
                return
                
            default:
                break
            }
        }
        
        // デフォルトのレスポンス
        response["status"] = "received"
        replyHandler(response)
        
        // 通常のメッセージとして処理
        handleReceivedMessage(message)
    }
    
    // バックグラウンドでも受信できるコンテキスト更新
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(applicationContext)
        }
    }
    
    // UserInfo転送の完了通知
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(userInfo)
        }
    }
    
    // MARK: - メッセージの処理
    private func handleReceivedMessage(_ message: [String: Any]) {
        print("Received message from Watch: \(message)")
        
        DispatchQueue.main.async {
            // メッセージタイプ付きの場合
            if let messageType = message["type"] as? String {
                print("Processing message of type: \(messageType)")
                switch messageType {
                case "heartRate":
                    self.handleHeartRateUpdate(message)
                    
                case "watchStatus":
                    self.handleWatchStatusUpdate(message)
                    
                case "watchInitialized":
                    print("Watch app initialized with userID: \(message["userID"] ?? "unknown")")
                    if let userID = message["userID"] as? String, !userID.isEmpty {
                        self.setUserID(userID)
                    }
                    
                // 他のケース...
                
                default:
                    print("Unknown message type: \(messageType)")
                }
            }
            // タイプなしで直接heartRateを含む古い形式のメッセージにも対応
            else if let heartRate = message["heartRate"] as? Int {
                print("Received legacy heart rate message: \(heartRate)")
                self.lastHeartRate = heartRate
                if let timestamp = message["timestamp"] as? Double {
                    self.lastHeartRateTimestamp = timestamp
                }
                NotificationCenter.default.post(
                    name: Notification.Name("HeartRateUpdated"),
                    object: nil,
                    userInfo: ["heartRate": heartRate]
                )
            }
        }
    }
    
    
    // MARK: - 個別メッセージハンドラー
    
    private func handleHeartRateUpdate(_ message: [String: Any]) {
        if let heartRate = message["heartRate"] as? Int {
            self.lastHeartRate = heartRate
            if let timestamp = message["timestamp"] as? Double {
                self.lastHeartRateTimestamp = timestamp
            }
            
            // 通知を送信して他のビューを更新
            NotificationCenter.default.post(
                name: Notification.Name("HeartRateUpdated"),
                object: nil,
                userInfo: ["heartRate": heartRate]
            )
        }
    }
    
    private func handleWatchStatusUpdate(_ message: [String: Any]) {
        if let isActive = message["isActive"] as? Bool,
           let userID = message["userID"] as? String {
            updateWatchActiveStatus(isActive: isActive, userID: userID)
        }
    }
    
    private func handleBroadcastToggle(_ message: [String: Any]) {
        if let isActive = message["isActive"] as? Bool {
            self.isBroadcasting = isActive
            
            // Firebaseにも状態を更新
            updateBroadcastStatus(isActive: isActive)
            
            // 通知を送信
            NotificationCenter.default.post(
                name: Notification.Name("BroadcastStatusChanged"),
                object: nil,
                userInfo: ["isActive": isActive]
            )
        }
    }
    
    private func handleViewerStopped(_ message: [String: Any]) {
        if let userID = message["userID"] as? String {
            // 視聴者モード終了処理
            // 必要な処理を追加
            
            // 通知を送信
            NotificationCenter.default.post(
                name: Notification.Name("ViewerModeStopped"),
                object: nil,
                userInfo: ["userID": userID]
            )
        }
    }
    
    private func handleBroadcastStatusUpdate(_ message: [String: Any]) {
        if let isActive = message["isActive"] as? Bool,
           let userID = message["userID"] as? String,
           let groupID = message["groupID"] as? String {
            
            // グループの配信状態を更新
            updateGroupBroadcastStatus(userID: userID, groupID: groupID, isActive: isActive)
            
            // 通知を送信
            NotificationCenter.default.post(
                name: Notification.Name("GroupBroadcastStatusChanged"),
                object: nil,
                userInfo: [
                    "userID": userID,
                    "groupID": groupID,
                    "isActive": isActive
                ]
            )
        }
    }
    
    // MARK: - Watchへのデータ送信メソッド
    
    /// アプリの状態をWatchに送信
    func sendAppStateToWatch(currentMode: Int, selectUser: String = "None") {
        guard WCSession.default.activationState == .activated else {
            print("WatchConnectivity: セッションがアクティブではありません")
            return
        }
        
        let appState: [String: Any] = [
            "CurrentMode": currentMode,
            "SelectUser": selectUser,
            "LastUpdated": Date().timeIntervalSince1970
        ]
        
        let message: [String: Any] = [
            "type": "appStateUpdate",
            "data": appState
        ]
        
        // リアルタイム通信（Apple Watchアプリが起動時のみ）
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("WatchConnectivity: メッセージ送信エラー: \(error.localizedDescription)")
            }
        }
        
        // バックグラウンド対応の通信
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            print("WatchConnectivity: コンテキスト更新エラー: \(error)")
        }
    }
    
    /// バイブレーション設定をWatchに送信
    func sendVibrationSettingsToWatch(toggle: Bool, recordStart: Bool, selectUser: String, selectUserName: String, number: Int) {
        guard WCSession.default.activationState == .activated else { return }
        
        let settings: [String: Any] = [
            "Toggle": toggle,
            "RecordStart": recordStart,
            "SelectUser": selectUser,
            "SelectUserName": selectUserName,
            "Number": number
        ]
        
        let message: [String: Any] = [
            "type": "vibrationSettings",
            "data": settings
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
        
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            print("WatchConnectivity: バイブレーション設定送信エラー: \(error)")
        }
    }
    
    /// グループ情報をWatchに送信
    func sendGroupInfoToWatch(groupID: String, hostID: String, isActive: Bool) {
        guard WCSession.default.activationState == .activated else { return }
        
        let groupInfo: [String: Any] = [
            "groupID": groupID,
            "hostID": hostID,
            "isActive": isActive
        ]
        
        let message: [String: Any] = [
            "type": "groupInfo",
            "data": groupInfo
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
        
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            print("WatchConnectivity: グループ情報送信エラー: \(error)")
        }
    }
    
    /// パートナーの状態をWatchに送信
    func sendPartnerStatusToWatch(userID: String, isActive: Bool) {
        guard WCSession.default.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "type": "partnerStatus",
            "userID": userID,
            "isActive": isActive
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
        
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            print("WatchConnectivity: パートナー状態送信エラー: \(error)")
        }
    }
    
    // MARK: - Firebase関連のヘルパーメソッド
    
    /// Watchのアクティブ状態を更新
    private func updateWatchActiveStatus(isActive: Bool, userID: String) {
        guard !userID.isEmpty, userID != "None", !userID.isEmpty else { return }
        
        self.isWatchActive = isActive
        
        // Firebaseにも状態を更新
        let ref = Database.database().reference()
        ref.child("Userdata").child(userID).child("AppStatus").child("isActive").setValue(isActive) { error, _ in
            if let error = error {
                print("Firebase: Watchアクティブ状態更新エラー: \(error.localizedDescription)")
            }
        }
        
        // 通知を送信
        NotificationCenter.default.post(
            name: Notification.Name("WatchActiveStatusChanged"),
            object: nil,
            userInfo: ["isActive": isActive, "userID": userID]
        )
    }
    
    /// Watchのアクティブ状態を確認
    private func checkWatchActiveStatus() {
        guard !currentUserID.isEmpty, let ref = databaseRef else { return }
        
        ref.child("Userdata").child(currentUserID).child("AppStatus").child("isActive")
            .observeSingleEvent(of: .value) { snapshot in
                if let isActive = snapshot.value as? Bool {
                    DispatchQueue.main.async {
                        self.isWatchActive = isActive
                    }
                }
            }
    }
    
    /// 配信状態を更新
    private func updateBroadcastStatus(isActive: Bool) {
        guard !currentUserID.isEmpty, let ref = databaseRef else { return }
        
        // 現在のグループIDを取得
        ref.child("Userdata").child(currentUserID).child("AppState").child("CurrentGroup")
            .observeSingleEvent(of: .value) { snapshot in
                if let groupID = snapshot.value as? String, !groupID.isEmpty {
                    // グループIDが存在する場合、配信状態を更新
                    ref.child("Userdata").child(self.currentUserID).child("Groups").child(groupID).child("broadcasting")
                        .setValue(isActive) { error, _ in
                            if let error = error {
                                print("Firebase: 配信状態更新エラー: \(error.localizedDescription)")
                            } else {
                                print("Firebase: 配信状態更新成功: \(isActive)")
                            }
                        }
                }
            }
    }
    
    /// グループの配信状態を更新
    private func updateGroupBroadcastStatus(userID: String, groupID: String, isActive: Bool) {
        guard let ref = databaseRef, !userID.isEmpty, !groupID.isEmpty else { return }
        
        ref.child("Userdata").child(userID).child("Groups").child(groupID).child("broadcasting")
            .setValue(isActive) { error, _ in
                if let error = error {
                    print("Firebase: グループ配信状態更新エラー: \(error.localizedDescription)")
                }
            }
    }
    
    /// アプリ状態を取得
    private func fetchAppState(for userID: String, completion: @escaping ([String: Any]) -> Void) {
        guard let ref = databaseRef, !userID.isEmpty else {
            completion([:])
            return
        }
        
        ref.child("Userdata").child(userID).child("AppState")
            .observeSingleEvent(of: .value) { snapshot in
                if let appState = snapshot.value as? [String: Any] {
                    completion(appState)
                } else {
                    completion([:])
                }
            }
    }
    
    /// ホスト情報を取得
    private func fetchHostInfo(for userID: String, completion: @escaping (String) -> Void) {
        guard let ref = databaseRef, !userID.isEmpty else {
            completion("Unknown Host")
            return
        }
        
        // ホストIDを取得
        ref.child("Userdata").child(userID).child("AppState").child("hostID")
            .observeSingleEvent(of: .value) { snapshot in
                if let hostID = snapshot.value as? String, !hostID.isEmpty, hostID != "None" {
                    // ホスト名を取得
                    ref.child("Username").child(hostID).child("UName")
                        .observeSingleEvent(of: .value) { nameSnapshot in
                            if let hostName = nameSnapshot.value as? String {
                                completion(hostName)
                            } else {
                                completion("Unknown Host")
                            }
                        }
                } else {
                    completion("No Host")
                }
            }
    }
    
    /// ホストの心拍数を取得
    private func fetchHostHeartRate(for userID: String, completion: @escaping (Int) -> Void) {
        guard let ref = databaseRef, !userID.isEmpty else {
            completion(60) // デフォルト値
            return
        }
        
        // ホストIDを取得
        ref.child("Userdata").child(userID).child("AppState").child("hostID")
            .observeSingleEvent(of: .value) { snapshot in
                if let hostID = snapshot.value as? String, !hostID.isEmpty, hostID != "None" {
                    // ホストの心拍数を取得
                    ref.child("Userdata").child(hostID).child("Heartbeat").child("Watch1")
                        .observeSingleEvent(of: .value) { heartRateSnapshot in
                            if let heartRateData = heartRateSnapshot.value as? [String: Any],
                               let heartRate = heartRateData["HeartRate"] as? Int {
                                completion(heartRate)
                            } else {
                                completion(60) // デフォルト値
                            }
                        }
                } else {
                    completion(60) // デフォルト値
                }
            }
    }
    
    /// 現在のグループ情報を取得
    private func fetchCurrentGroupInfo(completion: @escaping ([String: Any]) -> Void) {
        guard !currentUserID.isEmpty, let ref = databaseRef else {
            completion([:])
            return
        }
        
        // 現在のグループIDを取得
        ref.child("Userdata").child(currentUserID).child("AppState")
            .observeSingleEvent(of: .value) { snapshot in
                if let appState = snapshot.value as? [String: Any],
                   let groupID = appState["CurrentGroup"] as? String,
                   let hostID = appState["hostID"] as? String,
                   !groupID.isEmpty {
                    
                    // グループの配信状態を取得
                    ref.child("Userdata").child(hostID).child("Groups").child(groupID).child("broadcasting")
                        .observeSingleEvent(of: .value) { broadcastSnapshot in
                            let isActive = broadcastSnapshot.value as? Bool ?? false
                            
                            let groupInfo: [String: Any] = [
                                "groupID": groupID,
                                "hostID": hostID,
                                "isActive": isActive
                            ]
                            
                            completion(groupInfo)
                        }
                } else {
                    completion([:])
                }
            }
    }
}
