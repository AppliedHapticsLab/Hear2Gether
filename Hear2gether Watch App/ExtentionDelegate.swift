//
//  ExtensionDelegate.swift
//  HeartRate4 WatchKit Extension
//

import WatchKit
import Foundation
import HealthKit

// MARK: - Extended Runtime Session

final class ExtendedRuntimeSession: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession!
    var sessionEndCompletion: (() -> Void)?

    func startSession() {
        if session == nil {
            session = WKExtendedRuntimeSession()
            session.delegate = self
        }
        
        if session?.state == .notStarted {
            session?.start()
            print("Extended runtime session started")
        } else {
            print("Extended runtime session is already started or invalid")
        }
    }
    
    func endSession() {
        guard let session = session else {
            print("No session to end")
            return
        }
        
        switch session.state {
        case .running:
            session.invalidate()
            print("Extended runtime session invalidated")
        case .notStarted:
            print("Session not in running state: \(session.state.rawValue)")
        case .scheduled:
            print("Extended runtime session scheduled")
        case .invalid:
            print("Extended runtime session already invalid")
        @unknown default:
            print("Unknown session state: \(session.state.rawValue)")
        }
    }
    
    // MARK: WKExtendedRuntimeSessionDelegate
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        session = nil
        sessionEndCompletion?()
        print("Extended runtime session invalidated with reason: \(reason)")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session will expire")
    }
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session did start")
    }
}

// MARK: - WorkoutManager（HKWorkoutSession の活用）

final class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate {
    private var workoutSession: HKWorkoutSession?
    private let healthStore = HKHealthStore()
    
    /// workoutSession が存在すれば運動中とみなす
    var isActive: Bool {
        return workoutSession != nil
    }
    
    func startWorkout() {
        // すでに運動中なら何もしない
        if isActive { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .unknown
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            workoutSession?.startActivity(with: Date())
            print("Workout session started")
        } catch {
            print("Workout session start error: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        if let session = workoutSession {
            session.end()
            workoutSession = nil
            print("Workout session ended")
        }
    }
    
    // MARK: HKWorkoutSessionDelegate
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("Workout session changed from \(fromState) to \(toState)")
        if toState == .ended || toState == .notStarted {
            self.workoutSession = nil
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session error: \(error.localizedDescription)")
        self.workoutSession = nil
    }
}

// MARK: - iPhoneStateMonitor (REST API Version)
final class IPhoneStateMonitor {
    private var pollingTimer: Timer?
    private var heartbeatCheckTimer: Timer?
    private var lastHeartbeatTime: Date?
    private let heartbeatTimeoutInterval: TimeInterval = 60 // 60秒以上更新がなければタスクキルと判断
    private let pollingInterval: TimeInterval = 15 // 15秒ごとにポーリング
    private var userID: String?
    private var baseURL: String?
    private var lastKnownState: String?
    
    // 監視開始
    func startMonitoring(userID: String, baseURL: String, stateChangedHandler: @escaping (String) -> Void) {
        stopMonitoring()
        
        self.userID = userID
        self.baseURL = baseURL
        
        // 最初の状態を取得
        fetchCurrentState { [weak self] state in
            if let state = state {
                self?.lastKnownState = state
                stateChangedHandler(state)
                
                // タイムスタンプがあれば最終ハートビート時間を更新
                if state == "active", let timestamp = self?.fetchTimestamp() {
                    self?.lastHeartbeatTime = Date(timeIntervalSince1970: timestamp)
                } else {
                    self?.lastHeartbeatTime = Date() // 初期値として現在時刻を設定
                }
            }
        }
        
        // ポーリングタイマーを開始
        startPolling(stateChangedHandler: stateChangedHandler)
        
        // ハートビートの監視タイマーを開始
        startHeartbeatMonitoring(stateChangedHandler: stateChangedHandler)
    }
    
    // 現在のiPhone状態を取得
    private func fetchCurrentState(completion: @escaping (String?) -> Void) {
        guard let userID = userID, let baseURL = baseURL else {
            completion(nil)
            return
        }
        
        let urlString = "\(baseURL)/Userdata/\(userID)/iphoneState.json"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let state = json["state"] as? String else {
                completion(nil)
                return
            }
            
            completion(state)
        }.resume()
    }
    
    // タイムスタンプを取得
    private func fetchTimestamp() -> TimeInterval? {
        guard let userID = userID, let baseURL = baseURL else {
            return nil
        }
        
        var timestampValue: TimeInterval?
        let semaphore = DispatchSemaphore(value: 0)
        
        let urlString = "\(baseURL)/Userdata/\(userID)/iphoneState.json"
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestamp = json["timestamp"] as? TimeInterval else {
                return
            }
            
            timestampValue = timestamp
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5) // 最大5秒待機
        
        return timestampValue
    }
    
    // ポーリングを開始
    private func startPolling(stateChangedHandler: @escaping (String) -> Void) {
        pollingTimer?.invalidate()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.fetchCurrentState { state in
                guard let state = state, state != self.lastKnownState else {
                    return
                }
                
                // 状態が変わった場合のみハンドラを呼び出す
                self.lastKnownState = state
                print("iPhone state changed to: \(state) (via polling)")
                stateChangedHandler(state)
                
                // アクティブ状態の場合は最終ハートビート時間を更新
                if state == "active", let timestamp = self.fetchTimestamp() {
                    self.lastHeartbeatTime = Date(timeIntervalSince1970: timestamp)
                }
            }
        }
    }
    
    // ハートビート監視タイマーの開始
    private func startHeartbeatMonitoring(stateChangedHandler: @escaping (String) -> Void) {
        heartbeatCheckTimer?.invalidate()
        
        // 最初のハートビート時間を現在に設定
        if lastHeartbeatTime == nil {
            lastHeartbeatTime = Date()
        }
        
        // 15秒ごとにハートビートをチェック
        heartbeatCheckTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self = self,
                  let lastHeartbeat = self.lastHeartbeatTime else { return }
            
            let currentTime = Date()
            let timeSinceLastHeartbeat = currentTime.timeIntervalSince(lastHeartbeat)
            
            // ハートビートタイムアウトを検出
            if timeSinceLastHeartbeat > self.heartbeatTimeoutInterval {
                print("iPhone heartbeat timeout detected - likely task killed")
                if self.lastKnownState != "terminated" {
                    self.lastKnownState = "terminated"
                    stateChangedHandler("terminated")
                }
                
                // タイムアウト検出後、最終ハートビート時間をリセット
                self.lastHeartbeatTime = currentTime
            }
        }
    }
    
    // 監視停止
    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        heartbeatCheckTimer?.invalidate()
        heartbeatCheckTimer = nil
        
        userID = nil
        baseURL = nil
        lastKnownState = nil
        lastHeartbeatTime = nil
    }
}

// MARK: - ExtensionDelegate の更新

class ExtensionDelegate: NSObject, ObservableObject, WKApplicationDelegate {
    let extendedRuntimeSession = ExtendedRuntimeSession()
    let workoutManager = WorkoutManager()
    let iphoneStateMonitor = IPhoneStateMonitor()
    
    @Published var isAppActive = false
    // バックグラウンド状態を追跡するフラグを追加
    private var wasInBackground = false
    
    var myURL: String {
        return "https://test-dff46-default-rtdb.firebaseio.com"
    }
    
    func applicationDidFinishLaunching() {
        // アプリ起動時の初期化
        isAppActive = true
        
        // ExtendedRuntimeSession と WorkoutManager を開始して、バックグラウンドになってもフィットネス機能を維持
        extendedRuntimeSession.startSession()
        workoutManager.startWorkout()
        
        // Firebase へアプリ状態を更新（運動中は実際は接続維持中とみなす）
        updateAppStatusToFirebase(isActive: true, reason: "appLaunched")
        
        // iPhoneの状態監視を開始
        startMonitoringIPhoneState()
    }
    
    func applicationDidBecomeActive() {
        // アプリがアクティブになった時
        isAppActive = true
        updateAppStatusToFirebase(isActive: true, reason: "becameActive")
        
        // バックグラウンドから復帰した場合、ワークアウトを再開
        if wasInBackground {
            print("バックグラウンドから復帰 - ワークアウトセッションを再開")
            startSession()
            wasInBackground = false
        }
    }
    
    func applicationWillResignActive() {
        // アプリが非アクティブになる時
        // ※ただし、WorkoutManager が運動中なら、単なる画面オフ（省電力）として扱い Firebase への更新は抑制する
        if workoutManager.isActive {
            print("Workout session active, ignoring resign active update")
            return
        }
        isAppActive = false
        updateAppStatusToFirebase(isActive: false, reason: "resignedActive")
    }
    
    func applicationWillTerminate() {
        // アプリが終了する時
        isAppActive = false
        updateAppStatusToFirebase(isActive: false, reason: "terminated")
        
        // セッション終了
        extendedRuntimeSession.endSession()
        workoutManager.stopWorkout()
        
        // 監視停止
        iphoneStateMonitor.stopMonitoring()
    }
    
    func applicationDidEnterBackground() {
        // アプリがバックグラウンドに入った時
        isAppActive = false
        updateAppStatusToFirebase(isActive: false, reason: "enteredBackground")
        // セッション終了
        extendedRuntimeSession.endSession()
        workoutManager.stopWorkout()
        
        // バックグラウンドフラグを設定
        wasInBackground = true
        
        // 監視停止
        iphoneStateMonitor.stopMonitoring()
    }
    
    // 外部から ExtendedRuntimeSession / WorkoutManager の開始／停止を呼び出す
    func startSession() {
        extendedRuntimeSession.startSession()
        workoutManager.startWorkout()
    }
    
    func stopSession() {
        extendedRuntimeSession.endSession()
        workoutManager.stopWorkout()
    }
    
    // iPhoneの状態監視を開始
    func startMonitoringIPhoneState() {
        guard let userID = UserDefaults.standard.string(forKey: "UUID"),
              !userID.isEmpty, userID != "No data" else {
            print("iPhoneの状態監視: 有効なユーザーIDが見つかりません")
            return
        }
        
        iphoneStateMonitor.startMonitoring(userID: userID, baseURL: myURL) { [weak self] state in
            guard let self = self else { return }
            
            // iPhoneがバックグラウンドまたは終了状態の場合
            if state == "background" || state == "terminated" {
                print("iPhone状態変更検知: \(state) - フィットネス機能を終了します")
                self.stopSession()
                
                // アプリの状態も更新
                self.isAppActive = false
                self.updateAppStatusToFirebase(isActive: false, reason: "iphoneStateChanged:\(state)")
            } else if state == "active" {
                // iPhoneがアクティブになった場合、必要に応じてセッションを再開
                if !self.workoutManager.isActive {
                    print("iPhone状態変更検知: \(state) - フィットネス機能を再開します")
                    self.startSession()
                }
            }
        }
    }
    
    // Firebaseにアプリ状態を送信する関数
    func updateAppStatusToFirebase(isActive: Bool, reason: String) {
        // UserDefaultsからユーザーIDを取得
        guard let userID = UserDefaults.standard.string(forKey: "UUID"),
              !userID.isEmpty, userID != "No data" else {
            print("アプリ状態更新: 有効なユーザーIDが見つかりません")
            return
        }
        
        // FirebaseのURL作成
        guard let url = URL(string: "\(myURL)/Userdata/\(userID)/AppStatus.json") else {
            print("アプリ状態更新: 無効なURL")
            return
        }
        
        // リクエスト作成
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        let statusData: [String: Any] = [
            "isActive": isActive,
            "lastUpdated": Int64(Date().timeIntervalSince1970 * 1000),
            "stateChangeReason": reason
        ]
        
        // JSONに変換
        guard let jsonData = try? JSONSerialization.data(withJSONObject: statusData) else {
            print("アプリ状態更新: JSONシリアライズに失敗")
            return
        }
        
        request.httpBody = jsonData
        
        // リクエスト送信
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("アプリ状態更新: エラー発生 \(error.localizedDescription)")
                return
            }
            print("アプリ状態を正常にFirebaseに更新しました: \(isActive ? "アクティブ" : "非アクティブ") (理由: \(reason))")
        }.resume()
    }
}
