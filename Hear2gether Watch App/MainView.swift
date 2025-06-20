import SwiftUI
import HealthKit
import WatchKit
import WatchConnectivity
import Combine
import Foundation
import AVFoundation
import Kingfisher

// MARK: - グローバル定数
let defaultTimeInterval = 0.25
let defaultMode = 2
let numberOfWatches = 10
let numberOfModes = 3

// FirebaseのURL
let myURL = "https://test-dff46-default-rtdb.firebaseio.com"

// MARK: - モデル定義
struct HeartRateData: Codable {
    let heartRate: Int
    enum CodingKeys: String, CodingKey {
        case heartRate = "HeartRate"
    }
}

struct VibrationSettings: Codable {
    let toggle: Bool
    let recordStart: Bool
    let selectUser: String
    let selectUserName: String
    let number: Int
    
    enum CodingKeys: String, CodingKey {
        case toggle = "Toggle"
        case recordStart = "RecordStart"
        case selectUser = "SelectUser"
        case selectUserName = "SelectUserName"
        case number = "Number"
    }
}

struct Permission: Codable, Identifiable {
    let id: String
    let value: Bool
}

struct UserData: Identifiable, Decodable {
    let id = UUID()
    let uName: String
    let uImage: String
    
    enum CodingKeys: String, CodingKey {
        case uName = "UName"
        case uImage = "Uimage"
    }
}

struct CombinedData: Identifiable, Hashable {
    let id: String
    let permissionValue: Bool
    let userName: String
    let userImage: String
    var number: Int
}

// デフォルト値
let defaultHeartRateData = HeartRateData(heartRate: 60)
let defaultUserData = UserData(uName: "Unknown", uImage: "defaultUserImage")
let defaultVibrationSettings = VibrationSettings(toggle: false,
                                                 recordStart: false,
                                                 selectUser: "",
                                                 selectUserName: "Mine",
                                                 number: defaultMode)

// MARK: - APIリクエストのキャッシュやレート制限のサンプル構造体
struct APIRequestThrottle {
    var dataCache: [String: Any] = [:]
    var lastUpdatedTimestamps: [String: TimeInterval] = [:]
    var apiCallCounters: [String: Int] = [:]
    var counterResetTimes: [String: TimeInterval] = [:]
    
    func getCachedData<T>(for key: String, cacheTime: TimeInterval) -> T? {
        let now = Date().timeIntervalSince1970
        if let lastUpdate = lastUpdatedTimestamps[key],
           now - lastUpdate < cacheTime,
           let cachedData = dataCache[key] as? T {
            return cachedData
        }
        return nil
    }
    
    mutating func shouldThrottleRequest(for key: String, maxCallsPerMinute: Int) -> Bool {
        let now = Date().timeIntervalSince1970
        let minuteInterval: TimeInterval = 60.0
        
        if let resetTime = counterResetTimes[key], now > resetTime {
            apiCallCounters[key] = 0
            counterResetTimes[key] = now + minuteInterval
        }
        
        if counterResetTimes[key] == nil {
            counterResetTimes[key] = now + minuteInterval
            apiCallCounters[key] = 0
        }
        
        var currentCount = apiCallCounters[key] ?? 0
        if currentCount >= maxCallsPerMinute {
            return true
        }
        
        currentCount += 1
        apiCallCounters[key] = currentCount
        return false
    }
    
    mutating func setCachedData(for key: String, data: Any) {
        dataCache[key] = data
        lastUpdatedTimestamps[key] = Date().timeIntervalSince1970
    }
}

// MARK: - AppModeManager (モード管理)
class AppModeManager: ObservableObject {
    @Published var currentMode: Int = 0            // 0=一人, 1=二人, 2=みんな, 3=設定
    @Published var modeTransitionActive: Bool = false
    @Published var lastUpdated: Double = 0
    @Published var selectUser: String = "None"
    
    // グループ関連 (みんなモード用)
    @Published var currentGroupID: String = ""
    @Published var hostUserID: String = ""
    @Published var isHostUser: Bool = false
    @Published var isBroadcasting: Bool = false
    
    func getModeName() -> String {
        switch currentMode {
        case 0: return "一人で"
        case 1: return "二人で"
        case 2: return "みんなと"
        case 3: return "設定"
        default: return "未設定"
        }
    }
    
    func getModeIcon() -> String {
        switch currentMode {
        case 0: return "person.fill"
        case 1: return "person.2.fill"
        case 2: return "shareplay"
        case 3: return "gearshape.fill"
        default: return "questionmark.circle"
        }
    }
    
    func getModeColor() -> Color {
        switch currentMode {
        case 0: return .blue
        case 1: return .purple
        case 2: return .orange
        case 3: return .gray
        default: return .red
        }
    }
    
    func triggerModeTransition() {
        withAnimation {
            modeTransitionActive = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                self.modeTransitionActive = false
            }
        }
    }
    
    func getUserDisplayText(userName: String) -> String {
        switch currentMode {
        case 0:
            return "You"
        case 1:
            return (selectUser == "None") ? "待機中..." : "By \(userName)"
        case 2:
            return "By \(userName)"
        case 3:
            return "設定モード"
        default:
            return "By \(userName)"
        }
    }
    
    func getStatusMessage() -> String? {
        switch currentMode {
        case 0:
            return "一人モード"
        case 1:
            return (selectUser == "None") ? "ユーザーを選択してください"
                                          : "二人モード：相手の心拍を確認中"
        case 2:
            return "みんなモード"
        case 3:
            return "設定モード"
        default:
            return nil
        }
    }
    
    func setHostStatus(groupID: String, hostID: String, currentUserID: String, isActive: Bool) {
        self.currentGroupID = groupID
        self.hostUserID = hostID
        self.isHostUser = (hostID == currentUserID)
        self.isBroadcasting = isActive
    }
    
    func getGroupModeStatusMessage() -> String {
        if currentMode != 2 { return getStatusMessage() ?? "" }
        if isHostUser {
            return isBroadcasting ? "ライブ配信中" : "配信停止中 (タップで開始)"
        } else {
            return isBroadcasting ? "ホストの心拍を受信中" : "ホストの配信待機中"
        }
    }
    
    func getGroupUserDisplayText(hostName: String, userName: String) -> String {
        if currentMode != 2 { return getUserDisplayText(userName: userName) }
        if isHostUser {
            return "あなた (ホスト)"
        } else {
            return "By \(hostName)"
        }
    }
    
    // 二人モードでまだ相手を選んでいない時は待機画面を出す
    var shouldShowWaitingView: Bool {
        return currentMode == 1 && selectUser == "None"
    }
}

// MARK: - HealthKitManager (心拍数取得)
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    let heartRateUnit = HKUnit(from: "count/min")
    
    @Published var currentHeartRate: Int = 60   // UI表示用の値
    
    private var query: HKQuery?
    
    // モード判定用
    weak var appModeManager: AppModeManager? = nil
    var currentUserID: String = ""
    
    func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            let err = NSError(domain: "HealthKit",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Heart rate type unavailable"])
            completion(false, err)
            return
        }
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        // すでに認証済みの場合
        if healthStore.authorizationStatus(for: heartRateType) == .sharingAuthorized {
            completion(true, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            completion(success, error)
        }
    }
    
    func startHeartRateQuery() {
        if let existingQuery = query {
            healthStore.stop(existingQuery)
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600),
                                                    end: nil,
                                                    options: .strictEndDate)
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let initialQuery = HKSampleQuery(sampleType: heartRateType,
                                         predicate: predicate,
                                         limit: 1,
                                         sortDescriptors: [sortDesc])
        { [weak self] (_, samples, error) in
            if let error = error {
                print("初期心拍クエリエラー: \(error)")
                return
            }
            self?.process(samples: samples)
        }
        healthStore.execute(initialQuery)
        
        let devicePred = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let anchoredQuery = HKAnchoredObjectQuery(type: heartRateType,
                                                  predicate: devicePred,
                                                  anchor: nil,
                                                  limit: HKObjectQueryNoLimit)
        { [weak self] (_, samples, _, _, error) in
            if let error = error {
                print("心拍数更新クエリエラー: \(error)")
                return
            }
            self?.process(samples: samples)
        }
        
        anchoredQuery.updateHandler = { [weak self] (_, samples, _, _, error) in
            if let error = error {
                print("心拍数updateHandlerエラー: \(error)")
                return
            }
            self?.process(samples: samples)
        }
        
        query = anchoredQuery
        healthStore.execute(anchoredQuery)
    }
    
    private func process(samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
            return
        }
        for sample in samples {
            let hrValue = sample.quantity.doubleValue(for: heartRateUnit)
            if hrValue > 0 && hrValue < 220 {
                DispatchQueue.main.async {
                    self.currentHeartRate = Int(hrValue)
                }
            }
        }
    }
    
    func stopHeartRateQuery() {
        if let existingQuery = query {
            healthStore.stop(existingQuery)
            query = nil
        }
    }
}

// MARK: - FirebaseService
final class FirebaseService: ObservableObject {
    @Published var permissions: [Permission] = []
    @Published var combinedData: [CombinedData] = []
    
    private var permissionsCache: [String: [Permission]] = [:]
    private var userDataCache: [String: UserData] = [:]
    private var lastPermissionsFetch: [String: Date] = [:]
    private var minFetchInterval: TimeInterval = 5.0
    
    func adjustCacheTimeForMode(_ mode: Int) {
        switch mode {
        case 0: minFetchInterval = 10.0
        case 1: minFetchInterval = 5.0
        case 2: minFetchInterval = 3.0
        case 3: minFetchInterval = 15.0
        default: minFetchInterval = 5.0
        }
    }
    
    func fetchPermissions(uuid: String, mode: String, key: String, completion: @escaping () -> Void) {
        let cacheKey = "\(uuid)_\(mode)"
        let now = Date()
        if let lastFetch = lastPermissionsFetch[cacheKey],
           now.timeIntervalSince(lastFetch) < minFetchInterval,
           let cachedPerms = permissionsCache[cacheKey] {
            DispatchQueue.main.async {
                self.permissions = cachedPerms
                completion()
            }
            return
        }
        
        guard let url = URL(string: "\(myURL)/AcceptUser/\(uuid)/\(mode).json?auth=\(key)") else {
            self.permissions = []
            completion()
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { data, _, error in
            defer { completion() }
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.permissions = []
                }
                return
            }
            do {
                let permDict = try JSONDecoder().decode([String: Bool].self, from: data)
                let perms = permDict.map { Permission(id: $0.key, value: $0.value) }
                self.permissionsCache[cacheKey] = perms
                self.lastPermissionsFetch[cacheKey] = now
                DispatchQueue.main.async {
                    self.permissions = perms
                }
            } catch {
                DispatchQueue.main.async {
                    self.permissions = []
                }
            }
        }.resume()
    }
    
    func decodeUUIDtoUser(uuid: String, key: String, completion: @escaping (UserData) -> Void) {
        if let cached = userDataCache[uuid] {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        guard let url = URL(string: "\(myURL)/Username/\(uuid).json?auth=\(key)") else {
            DispatchQueue.main.async { completion(defaultUserData) }
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(defaultUserData) }
                return
            }
            do {
                let userDict = try JSONDecoder().decode([String: String].self, from: data)
                if let name = userDict["UName"], let img = userDict["Uimage"] {
                    let userData = UserData(uName: name, uImage: img)
                    self.userDataCache[uuid] = userData
                    DispatchQueue.main.async { completion(userData) }
                } else {
                    DispatchQueue.main.async { completion(defaultUserData) }
                }
            } catch {
                DispatchQueue.main.async { completion(defaultUserData) }
            }
        }.resume()
    }
    
    func fetchCombinedData(uuid: String, mode: String, key: String, completion: @escaping () -> Void) {
        if !combinedData.isEmpty {
            let cacheKey = "\(uuid)_\(mode)_combined"
            let now = Date()
            if let lastFetch = lastPermissionsFetch[cacheKey],
               now.timeIntervalSince(lastFetch) < 10.0 {
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            lastPermissionsFetch[cacheKey] = now
        }
        
        fetchPermissions(uuid: uuid, mode: mode, key: key) {
            let group = DispatchGroup()
            var newCombinedData: [CombinedData] = []
            
            let permsToProcess = self.permissions.filter { p in
                let ex = self.combinedData.first { $0.id == p.id }
                return ex == nil || ex!.permissionValue != p.value
            }
            
            for p in permsToProcess {
                group.enter()
                self.decodeUUIDtoUser(uuid: p.id, key: key) { uData in
                    let data = CombinedData(id: p.id,
                                            permissionValue: p.value,
                                            userName: uData.uName,
                                            userImage: uData.uImage,
                                            number: 0)
                    newCombinedData.append(data)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if !newCombinedData.isEmpty {
                    var updated = self.combinedData
                    for newData in newCombinedData {
                        if let idx = updated.firstIndex(where: { $0.id == newData.id }) {
                            updated[idx] = newData
                        } else {
                            updated.append(newData)
                        }
                    }
                    updated.sort { $0.userName < $1.userName }
                    for i in 0..<updated.count {
                        updated[i].number = i
                    }
                    self.combinedData = updated
                }
                completion()
            }
        }
    }
}

// MARK: - VibrationManager
final class VibrationManager: ObservableObject {
    @Published var settings: VibrationSettings = defaultVibrationSettings
    var userID: String = ""
    private var timer: Timer?
    
    func startUpdating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.fetchVibrationSettings()
        }
        timer?.fire()
    }
    
    func stopUpdating() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchVibrationSettings() {
        guard !userID.isEmpty, let url = URL(string: "\(myURL)/Userdata/\(userID)/MyPreference/Vibration.json") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let settings = try JSONDecoder().decode(VibrationSettings.self, from: data)
                DispatchQueue.main.async {
                    self.settings = settings
                }
            } catch {
                print("Failed to decode VibrationSettings in VibrationManager: \(error)")
            }
        }.resume()
    }
}

// MARK: - HeartView / RippleView (UIアニメ)
struct HeartView: View {
    let scale: CGFloat
    let opacity: Double
    let color: Color
    
    var body: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: 50, height: 50)
            .scaleEffect(scale)
            .opacity(opacity)
            .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
    }
}

struct RippleView: View {
    @Binding var scale: CGFloat
    @Binding var opacity: Double
    
    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.red)
                .frame(width: 50, height: 50)
                .scaleEffect(scale)
                .opacity(opacity * 0.8)
            
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.red.opacity(0.7))
                .frame(width: 50, height: 50)
                .scaleEffect(scale - 0.2)
                .opacity(opacity * 0.6)
        }
    }
}

// MARK: - CustomImageView
struct CustomImageView: View {
    let imageURL: URL?
    let nowTime: Int
    @State private var isLoading = false
    
    private var imageOpacity: Double {
        switch nowTime {
        case 0: return 0.5
        case 1: return 1.0
        case 2: return 1.0
        default: return 1.0
        }
    }
    
    private var lineWidth: CGFloat { 3 }
    
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 70, height: 70)
                .overlay(
                    KFImage(imageURL)
                        .onSuccess { _ in isLoading = false }
                        .onFailure { _ in isLoading = false }
                        .onProgress { _, _ in isLoading = true }
                        .placeholder {
                            Image(systemName: "person.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.gray)
                                .frame(width: 60, height: 60)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 70)
                        .opacity(imageOpacity)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(borderGradient(for: nowTime), lineWidth: lineWidth)
                        )
                )
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(nowTime == 2 ? Color.yellow :
                              (nowTime == 1 ? Color.green : Color.gray))
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
                        .padding(4)
                }
            }
            .frame(width: 70, height: 70)
        }
        .shadow(radius: 2)
    }
}

private func borderGradient(for time: Int) -> LinearGradient {
    switch time {
    case 0:
        return LinearGradient(gradient: Gradient(colors: [.gray]),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
    case 1:
        return LinearGradient(gradient: Gradient(colors: [.brown, .black]),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
    case 2:
        return LinearGradient(gradient: Gradient(colors: [.purple, .red, .yellow]),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
    default:
        return LinearGradient(gradient: Gradient(colors: [.gray]),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
    }
}

// MARK: - 待機画面
struct WaitingForSelectionView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
                .opacity(0.8)
            
            Text("ユーザー選択待ち")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("ユーザーを選択してください")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ログアウトボタン
struct LogoutView: View {
    var onLogoutPressed: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: onLogoutPressed) {
                Text("Logout")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 36)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("左にスワイプで戻る")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ページインジケータ
struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<pageCount, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(6)
    }
}

// MARK: - QRCodeView
struct QRCodeView: View {
    var onQRCodePressed: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: onQRCodePressed) {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    
                    Text("QRコードを表示")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 140, height: 100)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("スワイプでメイン画面に戻る")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .padding(.top, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SettingsModeView
struct SettingsModeView: View {
    @EnvironmentObject var sharedData: LoginConnector
    @EnvironmentObject var vibrationManager: VibrationManager
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .opacity(0.8)
            
            Text("設定モード")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            if isLoading {
                ProgressView("読み込み中...")
            } else {
                VStack(spacing: 8) {
                    Text("振動: \(vibrationManager.settings.toggle ? "ON" : "OFF")")
                    Text("強度: \(vibrationManager.settings.number) (0=弱, 1=中, 2=強)")
                }
            }
            
            Text("iPhoneアプリで設定を変更できます")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .onAppear {
            vibrationManager.startUpdating()
        }
        .onDisappear {
            vibrationManager.stopUpdating()
        }
    }
}

// MARK: - HeartBeatView (メインのUIパネル)
// ※ホストの心拍は外部（HelloView側）の@Stateとして管理するため、ここではBindingとして受け取る
struct HeartBeatView: View {
    @Binding var heartRate: Int
    @Binding var userName: String
    
    @Binding var heartScale: CGFloat
    @Binding var rippleScale: CGFloat
    @Binding var rippleOpacity: Double
    @Binding var heartOpacity: Double
    
    @ObservedObject var modeManager: AppModeManager
    @EnvironmentObject var sharedData: LoginConnector
    
    @Binding var isViewingLive: Bool
    // ホストの心拍をバインディングで受け取る
    @Binding var hostHeartRate: Int
    @Binding var partnerHeartRate: Int  // 追加：相手の心拍数を受け取るためのバインディング
    // 以下、グループ／二人モード用の内部状態
    @State private var hostName: String = ""
    @State private var hostRippleScale: CGFloat = 0.5
    @State private var hostRippleOpacity: Double = 1.0
    @State private var hostHeartScale: CGFloat = 1.0
    @State private var hostBeatInterval: Double = 1.0
    @State private var hostDataTimer: Timer? = nil
    
    @State private var isPartnerActive: Bool = true
    @State private var partnerStatusTimer: Timer? = nil
    @State private var groupDataTimer: Timer? = nil
    @State private var broadcastTimer: Timer? = nil
    @State private var hostHeartRateTimer: Timer? = nil
    
    @Binding var heartTimerPublisher: Publishers.Autoconnect<Timer.TimerPublisher>
    
    @EnvironmentObject var vibrationManager: VibrationManager
    
    var body: some View {
        VStack {
            // 二人モードで相手未選択
            if modeManager.shouldShowWaitingView {
                WaitingForSelectionView()
            }
            // 設定モード
            else if modeManager.currentMode == 3 {
                SettingsModeView()
                    .environmentObject(sharedData)
                        
            }
            // みんなモード + 視聴者モード
            else if modeManager.currentMode == 2 && isViewingLive {
                viewerModeContent
            }
            // みんなモード
            else if modeManager.currentMode == 2 {
                groupModeContent
            }
            // 二人モード
            else if modeManager.currentMode == 1 && !modeManager.shouldShowWaitingView {
                twoPeopleModeContent
            }
            // 一人モード / その他
            else {
                ZStack {
                    RippleView(scale: $rippleScale, opacity: $rippleOpacity)
                    HeartView(scale: heartScale, opacity: heartOpacity, color: .red)
                }
                .frame(height: 60)
                
                HStack(spacing: 2) {
                    Text("\(heartRate)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.red)
                    Text("BPM")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .alignmentGuide(.bottom) { d in d[.bottom] - 6 }
                }
                .padding(.top, 5)
                
                Text(modeManager.getUserDisplayText(userName: userName))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let statusMessage = modeManager.getStatusMessage() {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .onAppear {
            // みんなモード
            if modeManager.currentMode == 2 {
                fetchCurrentGroupInfo()
                if isViewingLive { startViewerMode() }
            }
            // 二人モード
            else if modeManager.currentMode == 1 && !modeManager.shouldShowWaitingView {
                startPartnerStatusMonitoring()
            }
        }
        .onChange(of: modeManager.currentMode) { _, newMode in
            if newMode == 2 {
                fetchCurrentGroupInfo()
                stopPartnerStatusMonitoring()
                if isViewingLive { startViewerMode() }
            }
            else if newMode == 1 && !modeManager.shouldShowWaitingView {
                startPartnerStatusMonitoring()
            } else {
                stopAllTimers()
                stopPartnerStatusMonitoring()
                stopViewerMode()
                if modeManager.isBroadcasting {
                    modeManager.isBroadcasting = false
                }
            }
        }
        .onChange(of: isViewingLive) { _, newValue in
            if modeManager.currentMode == 2 {
                newValue ? startViewerMode() : stopViewerMode()
            }
        }
        .onChange(of: modeManager.selectUser) { _, newSelectUser in
            if modeManager.currentMode == 1 && newSelectUser != "None" {
                startPartnerStatusMonitoring()
            } else if modeManager.currentMode == 1 && newSelectUser == "None" {
                stopPartnerStatusMonitoring()
                isPartnerActive = true
            }
        }
        .onDisappear {
            stopAllTimers()
            stopPartnerStatusMonitoring()
            stopViewerMode()
        }
    }
    
    // みんなモードの表示
    private var groupModeContent: some View {
        VStack(spacing: 15) {
            HStack(spacing: 6) {
                Circle()
                    .fill(modeManager.isBroadcasting ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(modeManager.getGroupModeStatusMessage())
                    .font(.system(size: 12))
                    .foregroundColor(modeManager.isBroadcasting ? .green : .gray)
            }
            .padding(.bottom, 5)
            
            if modeManager.isHostUser && modeManager.isBroadcasting {
                ZStack {
                    RippleView(scale: $rippleScale, opacity: $rippleOpacity)
                    HeartView(scale: heartScale, opacity: heartOpacity, color: .red)
                }
                .frame(height: 60)
                
                HStack(spacing: 2) {
                    Text("\(heartRate)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.red)
                    Text("BPM")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .alignmentGuide(.bottom) { d in d[.bottom] - 6 }
                }
                .padding(.top, 5)
            }
            else {
                if modeManager.isBroadcasting {
                    ZStack {
                        RippleView(scale: $rippleScale, opacity: $rippleOpacity)
                        HeartView(scale: heartScale, opacity: heartOpacity, color: .red)
                    }
                    .frame(height: 60)
                    
                    HStack(spacing: 2) {
                        Text("\(hostHeartRate)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.red)
                        Text("BPM")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .alignmentGuide(.bottom) { d in d[.bottom] - 6 }
                    }
                    .padding(.top, 5)
                }
                else {
                    VStack(spacing: 10) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                        
                        Text("配信停止中")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("ホストが配信を開始するまでお待ちください")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 180)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }
    
    // 二人モードの表示
    private var twoPeopleModeContent: some View {
        VStack {
            if isPartnerActive {
                ZStack {
                    RippleView(scale: $rippleScale, opacity: $rippleOpacity)
                    HeartView(scale: heartScale, opacity: heartOpacity, color: .red)
                }
                .frame(height: 60)
                
                // 相手の心拍数を表示するように変更 (heartRateではなくpartnerHeartRateを使用)
                HStack(spacing: 2) {
                    Text("\(partnerHeartRate)")  // 相手の心拍数を表示
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.red)
                    Text("BPM")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .alignmentGuide(.bottom) { d in d[.bottom] - 6 }
                }
                .padding(.top, 5)
                
                Text(modeManager.getUserDisplayText(userName: userName))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let statusMessage = modeManager.getStatusMessage() {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            else {
                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.gray)
                        .frame(width: 50, height: 50)
                        .opacity(0.7)
                        .frame(height: 60)
                    
                    Text("相手が閲覧者モードです")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.vertical, 5)
                    
                    Text(modeManager.getUserDisplayText(userName: userName))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 5)
                }
            }
        }
    }
    
    // みんなモード + 視聴者モード表示
    private var viewerModeContent: some View {
        VStack(spacing: 15) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("ライブ視聴中")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.bottom, 10)
            
            ZStack {
                ZStack {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.red)
                        .frame(width: 50, height: 50)
                        .scaleEffect(hostRippleScale)
                        .opacity(hostRippleOpacity * 0.8)
                    
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.red.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .scaleEffect(hostRippleScale - 0.2)
                        .opacity(hostRippleOpacity * 0.6)
                }
                
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.red)
                    .frame(width: 50, height: 50)
                    .scaleEffect(hostHeartScale)
                    .shadow(color: .red.opacity(0.6), radius: 4, x: 0, y: 0)
            }
            .frame(height: 60)
            
            HStack(spacing: 2) {
                Text("\(hostHeartRate)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
                Text("BPM")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .alignmentGuide(.bottom) { d in d[.bottom] - 6 }
            }
            .padding(.top, 5)
            
            Text(hostName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    // --- グループ・二人モード用の補助メソッド ---
    private func stopAllTimers() {
        groupDataTimer?.invalidate()
        broadcastTimer?.invalidate()
        hostHeartRateTimer?.invalidate()
        
        groupDataTimer = nil
        broadcastTimer = nil
        hostHeartRateTimer = nil
    }
    
    private func startViewerMode() {
        stopViewerMode()
        fetchHostName()
        fetchHostHeartRate()
        hostDataTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.fetchHostHeartRate()
        }
        startHostHeartAnimation()
    }
    
    private func stopViewerMode() {
        hostDataTimer?.invalidate()
        hostDataTimer = nil
    }
    
    private func fetchHostName() {
        _ = "hostName"
        guard let url = URL(string: "\(myURL)/Userdata/\(sharedData.receivedData)/AppState.json") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let appState = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let hostID = appState["hostID"] as? String,
                   hostID != "None"
                {
                    self.getHostName(hostID: hostID)
                }
            } catch {
                print("Error parsing host ID: \(error)")
            }
        }.resume()
    }
    
    private func getHostName(hostID: String) {
        guard !hostID.isEmpty, hostID != "None" else { return }
        guard let url = URL(string: "\(myURL)/Username/\(hostID).json") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let userDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let name = userDict["UName"] as? String
                {
                    DispatchQueue.main.async {
                        self.hostName = name
                    }
                }
            } catch {
                print("Error fetching host name: \(error)")
            }
        }.resume()
    }
    
    private func fetchHostHeartRate() {
        guard let url = URL(string: "\(myURL)/Userdata/\(sharedData.receivedData)/AppState.json") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let appState = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let hostID = appState["hostID"] as? String,
                   hostID != "None"
                {
                    self.getHostHeartRate(hostID: hostID)
                }
            } catch {
                print("Error parsing host ID: \(error)")
            }
        }.resume()
    }
    
    private func getHostHeartRate(hostID: String) {
        guard let url = URL(string: "\(myURL)/Userdata/\(hostID)/Heartbeat/Watch1/HeartRate.json") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            
            if let respString = String(data: data, encoding: .utf8),
               respString.isEmpty || respString == "null"
            {
                return
            }
            do {
                if let hrValue = try JSONSerialization.jsonObject(with: data) as? Int {
                    DispatchQueue.main.async {
                        if self.hostHeartRate != hrValue {
                            self.hostHeartRate = hrValue
                            self.updateHostBeatInterval()
                        }
                    }
                }
            } catch {
                print("Error decoding host heart rate: \(error)")
            }
        }.resume()
    }
    
    private func startHostHeartAnimation() {
        updateHostBeatInterval()
        animateHostHeart()
    }
    
    private func updateHostBeatInterval() {
        hostBeatInterval = 60.0 / Double(max(hostHeartRate, 1))
    }
    
    private func animateHostHeart() {
        hostRippleScale = 1.0
        hostRippleOpacity = 1.0
        
        withAnimation(.easeInOut(duration: hostBeatInterval / 4)) {
            hostHeartScale = 1.3
            hostRippleScale = 1.3
        }
        withAnimation(.easeInOut(duration: hostBeatInterval + 0.1)) {
            hostRippleScale = 1.8
            hostRippleOpacity = 0.0
        }
        withAnimation(Animation.easeInOut(duration: hostBeatInterval * 3 / 4)
                        .delay(hostBeatInterval / 4)) {
            hostHeartScale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + hostBeatInterval) {
            self.animateHostHeart()
        }
    }
    
    private func startPartnerStatusMonitoring() {
        guard !modeManager.selectUser.isEmpty, modeManager.selectUser != "None" else { return }
        checkPartnerStatus()
        partnerStatusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkPartnerStatus()
        }
        // 二人モードの場合、パートナーの心拍も更新する
        startPartnerHeartRateMonitoring()
    }
    
    private func stopPartnerStatusMonitoring() {
        partnerStatusTimer?.invalidate()
        partnerStatusTimer = nil
        stopPartnerHeartRateMonitoring()
    }
    
    private func checkPartnerStatus() {
        guard !modeManager.selectUser.isEmpty, modeManager.selectUser != "None" else {
            DispatchQueue.main.async {
                self.isPartnerActive = true
            }
            return
        }
        
        let path = "\(myURL)/Userdata/\(modeManager.selectUser)/AppStatus/isActive.json"
        guard let url = URL(string: path) else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            
            if let respString = String(data: data, encoding: .utf8) {
                if respString == "true" {
                    DispatchQueue.main.async {
                        let old = self.isPartnerActive
                        self.isPartnerActive = true
                        if !old {
                            WKInterfaceDevice.current().play(.notification)
                        }
                    }
                    return
                }
                else if respString == "false" {
                    DispatchQueue.main.async {
                        let old = self.isPartnerActive
                        self.isPartnerActive = false
                        if old {
                            WKInterfaceDevice.current().play(.directionDown)
                        }
                    }
                    return
                }
            }
            do {
                if let active = try JSONSerialization.jsonObject(with: data) as? Bool {
                    DispatchQueue.main.async {
                        let old = self.isPartnerActive
                        self.isPartnerActive = active
                        if old != active {
                            WKInterfaceDevice.current().play(active ? .notification : .directionDown)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isPartnerActive = false
                }
            }
        }.resume()
    }
    
    // パートナーの心拍取得（2人モード用）
    @State private var partnerHeartRateTimer: Timer? = nil
    
    private func startPartnerHeartRateMonitoring() {
        partnerHeartRateTimer?.invalidate()
        fetchPartnerHeartRate()
        partnerHeartRateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.fetchPartnerHeartRate()
        }
    }
    
    private func stopPartnerHeartRateMonitoring() {
        partnerHeartRateTimer?.invalidate()
        partnerHeartRateTimer = nil
    }
    
    private func fetchPartnerHeartRate() {
        guard !modeManager.selectUser.isEmpty, modeManager.selectUser != "None" else { return }
        let urlStr = "\(myURL)/Userdata/\(modeManager.selectUser)/Heartbeat/Watch1/HeartRate.json"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            if let respString = String(data: data, encoding: .utf8),
               respString.isEmpty || respString == "null" {
                return
            }
            do {
                if let hrValue = try JSONSerialization.jsonObject(with: data) as? Int {
                    DispatchQueue.main.async {
                        // ここが重要：HelloViewから渡された値を更新するのでnot setterが必要
                        if self.partnerHeartRate != hrValue {
                            self.partnerHeartRate = hrValue
                        }
                    }
                }
            } catch {
                print("Error decoding partner heart rate: \(error)")
            }
        }.resume()
    }
    
    private func fetchCurrentGroupInfo() {
        stopAllTimers()
        fetchGroupDataFromFirebase()
        groupDataTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.fetchGroupDataFromFirebase()
        }
    }
    
    private func fetchGroupDataFromFirebase() {
        guard !sharedData.receivedData.isEmpty else { return }
        
        guard let url = URL(string: "\(myURL)/Userdata/\(sharedData.receivedData)/CurrentGroup.json") else {
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            if let respStr = String(data: data, encoding: .utf8), respStr == "null" {
                return
            }
            do {
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let groupID = dict["groupID"] as? String,
                   let hostID = dict["hostID"] as? String,
                   let isActive = dict["isActive"] as? Bool
                {
                    DispatchQueue.main.async {
                        self.modeManager.setHostStatus(groupID: groupID,
                                                       hostID: hostID,
                                                       currentUserID: self.sharedData.receivedData,
                                                       isActive: isActive)
                        self.startMonitoringBroadcastStatus()
                        self.getHostName(hostID: hostID)
                        
                        if !self.modeManager.isHostUser {
                            self.startMonitoringHostHeartRate()
                        }
                    }
                }
            } catch {
                print("Error parsing group info: \(error)")
            }
        }.resume()
    }
    
    private func startMonitoringBroadcastStatus() {
        broadcastTimer?.invalidate()
        fetchBroadcastStatus()
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.fetchBroadcastStatus()
        }
    }
    
    private func fetchBroadcastStatus() {
        guard !modeManager.hostUserID.isEmpty,
              !modeManager.currentGroupID.isEmpty else { return }
        
        let path = "\(myURL)/Userdata/\(modeManager.hostUserID)/Groups/\(modeManager.currentGroupID)/broadcasting.json"
        guard let url = URL(string: path) else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            
            if let respString = String(data: data, encoding: .utf8) {
                if respString == "null" || respString.isEmpty {
                    return
                }
                if respString == "true" {
                    DispatchQueue.main.async {
                        let oldStatus = self.modeManager.isBroadcasting
                        if !oldStatus {
                            self.modeManager.isBroadcasting = true
                            WKInterfaceDevice.current().play(.notification)
                        }
                    }
                    return
                }
                else if respString == "false" {
                    DispatchQueue.main.async {
                        let oldStatus = self.modeManager.isBroadcasting
                        if oldStatus {
                            self.modeManager.isBroadcasting = false
                            WKInterfaceDevice.current().play(.directionDown)
                        }
                    }
                    return
                }
            }
            do {
                if let jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = jsonObj["status"] as? Bool
                {
                    DispatchQueue.main.async {
                        let old = self.modeManager.isBroadcasting
                        if old != status {
                            self.modeManager.isBroadcasting = status
                            WKInterfaceDevice.current().play(status ? .notification : .directionDown)
                        }
                    }
                }
                else if let status = try JSONSerialization.jsonObject(with: data) as? Bool {
                    DispatchQueue.main.async {
                        let old = self.modeManager.isBroadcasting
                        if old != status {
                            self.modeManager.isBroadcasting = status
                            WKInterfaceDevice.current().play(status ? .notification : .directionDown)
                        }
                    }
                }
            } catch {
                print("Error parsing broadcasting status: \(error)")
            }
        }.resume()
    }
    
    private func startMonitoringHostHeartRate() {
        hostHeartRateTimer?.invalidate()
        fetchHostHeartRate()
        hostHeartRateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.fetchHostHeartRate()
        }
    }
}

// MARK: - ModeTransitionOverlay
struct ModeTransitionOverlay: View {
    @ObservedObject var modeManager: AppModeManager
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        if modeManager.modeTransitionActive {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 8) {
                    Image(systemName: modeManager.getModeIcon())
                        .font(.system(size: 30))
                        .foregroundColor(modeManager.getModeColor())
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                        .overlay(
                            Circle()
                                .stroke(modeManager.getModeColor(), lineWidth: 2)
                        )
                    
                    Text(modeManager.getModeName())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 5)
                    
                    Text(modeManager.currentMode == 2
                         ? "グループ心拍共有モード"
                         : "モードが変更されました")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(15)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(modeManager.getModeColor().opacity(0.6), lineWidth: 1)
                        )
                )
                .opacity(opacity)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        opacity = 1
                        scale = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            opacity = 0
                            scale = 1.1
                        }
                    }
                }
            }
        }
    }
}

// MARK: - HelloView (メイン画面)
struct HelloView: View {
    @EnvironmentObject var sharedData: LoginConnector
    @EnvironmentObject var extensionDelegate: ExtensionDelegate
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appModeManager = AppModeManager()
    @StateObject private var vibrationManager = VibrationManager()
    
    
    @State private var currentPage = 0
    @State private var isViewingLive: Bool = false
    @State private var lastRemoteHeartRate: Int = 60
    
    // ハートアニメ用状態
    @State private var heartIsActive: Bool = false
    @State private var heartScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 1.0
    @State private var heartOpacity: Double = 1.0
    
    // ユーザー名表示 (二人モードなど)
    @AppStorage("UserName") private var scrollUname: String?
    
    // ホストの心拍をHelloView側で管理（HeartBeatViewへBindingで渡す）
    @State private var hostHeartRate: Int = 60
    // 二人モード用：パートナーの心拍
    @State private var partnerHeartRate: Int = 60
    
    // ハートアニメ用の定期タイマー
    @State private var heartTimerPublisher = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // 3秒おきにアップロード
    @State private var uploadTimer: Timer? = nil
    @State private var lastUploadedHeartRate: Int = -1
    
    @State private var isPartnerActive: Bool = true
    
    // モード監視用タイマー
    @State private var modeCheckTimer: Timer? = nil
    
    // Add these missing properties
        @State private var showAlert = false
        @State private var heartTimer: Timer? = nil
        @State private var viewerModeTimer: Timer? = nil
        
        // Data cache properties
        @State private var dataCache: [String: Any] = [:]
        @State private var lastUpdatedTimestamps: [String: Date] = [:]
        @State private var heartRateBatchData: [[String: Any]] = []
    
    var body: some View {
        ZStack {
            // ページ切り替え (TabView)
            TabView(selection: $currentPage) {
                HeartBeatView(
                    heartRate: $lastRemoteHeartRate,
                    userName: .init(get: { scrollUname ?? "Mine" },
                                    set: { scrollUname = $0 }),
                    heartScale: $heartScale,
                    rippleScale: $rippleScale,
                    rippleOpacity: $rippleOpacity,
                    heartOpacity: $heartOpacity,
                    modeManager: appModeManager,
                    isViewingLive: $isViewingLive,
                    hostHeartRate: $hostHeartRate,
                    partnerHeartRate: $partnerHeartRate,  // 追加：パートナーの心拍数をバインド
                    heartTimerPublisher: $heartTimerPublisher
                )
                .tag(0)
                .environmentObject(vibrationManager)
                
                QRCodeView(onQRCodePressed: {
                    showAlert = true
                })
                .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // ページインジケータ
            VStack {
                Spacer()
                PageIndicator(currentPage: currentPage,
                              pageCount: isViewingLive ? 3 : 2)
                .padding(.bottom, 5)
            }
        }
        .overlay(
            ModeTransitionOverlay(modeManager: appModeManager)
        )
        .alert("QRコード表示", isPresented: $showAlert) {
            Button("表示する") {
                reset()
            }
            Button("キャンセル", role: .cancel) {
                showAlert = false
            }
        } message: {
            Text("iPhoneアプリでQRコードを読み取りますか？")
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            print(sharedData.receivedData)
            setupOnAppear()
            // vibrationManager.userID を設定
            vibrationManager.userID = sharedData.receivedData
        }
        // ハートタイマーにより心拍アニメ更新＆振動パターン発動
        .onReceive(heartTimerPublisher) { _ in
            updateHeartAnimation()
            triggerVibrationPattern(vibrationManager.settings)
        }
        .onChange(of: healthKitManager.currentHeartRate) { newValue,_ in
            self.lastRemoteHeartRate = newValue
        }
        // effectiveHeartRateに基づきタイマーを更新
        .onChange(of: lastRemoteHeartRate) { updateTimer() }
        .onChange(of: partnerHeartRate) { updateTimer() }
        .onChange(of: hostHeartRate) { updateTimer() }
        .onChange(of: appModeManager.currentMode) { newMode,_ in
            updateTimer()
            if newMode == 1 {
                // 二人モードの場合はパートナーの心拍取得開始
                // ※HeartBeatView内でも監視している場合は重複に注意
            }
        }
        .onChange(of: isViewingLive) { updateTimer() }
    }
    
    // Fixed reset function
        private func reset() {
            // Stop all timers
            stopAllTimers()
            
            // Update Firebase app status
            updateAppStatus(isActive: false, stateChangeReason: "isLogout")
            
            // Upload any remaining heart rate data
            uploadHeartRateBatch()
            
            // Reset all state
            heartTimer?.invalidate()
            uploadTimer?.invalidate()
            modeCheckTimer?.invalidate()
            viewerModeTimer?.invalidate()
            
            heartTimer = nil
            uploadTimer = nil
            modeCheckTimer = nil
            viewerModeTimer = nil
            
            // Reset shared data
            sharedData.shouldNavigate = false
            sharedData.receivedData = ""
            sharedData.count = ""
            
            // Stop WatchConnectivity session
            extensionDelegate.stopSession()
            
            // Reset animation state
            heartIsActive = false
            
            // Clear cache data
            dataCache.removeAll()
            lastUpdatedTimestamps.removeAll()
            heartRateBatchData.removeAll()
        }
        
        // Missing methods that need to be implemented
        
        // Method to stop all timers
        private func stopAllTimers() {
            heartTimer?.invalidate()
            uploadTimer?.invalidate()
            modeCheckTimer?.invalidate()
            viewerModeTimer?.invalidate()
        }
        
        // Update app status in Firebase
        private func updateAppStatus(isActive: Bool, stateChangeReason: String) {
            guard !sharedData.receivedData.isEmpty else { return }
            
            let path = "\(myURL)/Userdata/\(sharedData.receivedData)/AppStatus.json"
            guard let url = URL(string: path) else { return }
            
            let dataPoint: [String: Any] = [
                "isActive": isActive,
                "lastStatus": Int64(Date().timeIntervalSince1970 * 1000),
                "stateChangeReason": stateChangeReason
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dataPoint)
                request.httpBody = jsonData
                
                URLSession.shared.dataTask(with: request) { _, _, error in
                    if let error = error {
                        print("Error updating app status: \(error)")
                    }
                }.resume()
            } catch {
                print("Error serializing app status data: \(error)")
            }
        }
        
        // Upload heart rate batch data
        private func uploadHeartRateBatch() {
            guard !heartRateBatchData.isEmpty, !sharedData.receivedData.isEmpty else { return }
            
            let path = "\(myURL)/Userdata/\(sharedData.receivedData)/Heartbeat/Batch.json"
            guard let url = URL(string: path) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: heartRateBatchData)
                request.httpBody = jsonData
                
                URLSession.shared.dataTask(with: request) { _, _, error in
                    if let error = error {
                        print("Error uploading heart rate batch: \(error)")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.heartRateBatchData.removeAll()
                    }
                }.resume()
            } catch {
                print("Error serializing heart rate batch data: \(error)")
            }
        }
    
    // effectiveHeartRate：各モードで振動に用いる心拍値（修正版）
    private var effectiveHeartRate: Int {
        switch appModeManager.currentMode {
        case 0: // 一人モード
            return lastRemoteHeartRate
        case 1: // 二人モード
            if appModeManager.selectUser != "None" && isPartnerActive {
                // 相手が選択されていて接続中なら相手の心拍
                return partnerHeartRate > 0 ? partnerHeartRate : lastRemoteHeartRate
            } else {
                // それ以外は自分の心拍
                return lastRemoteHeartRate
            }
        case 2: // みんなモード
            if isViewingLive {
                // 視聴者モードでは配信者の心拍
                return hostHeartRate > 0 ? hostHeartRate : lastRemoteHeartRate
            } else if !appModeManager.isHostUser && appModeManager.isBroadcasting {
                // 非ホスト（視聴者）かつブロードキャスト中の場合はホストの心拍
                return hostHeartRate > 0 ? hostHeartRate : lastRemoteHeartRate
            } else if appModeManager.isHostUser {
                // ホスト自身は自分の心拍
                return lastRemoteHeartRate
            } else {
                // その他の場合（待機中など）は自分の心拍
                return lastRemoteHeartRate
            }
        default:
            return lastRemoteHeartRate
        }
    }

    
    private func updateTimer() {
        let interval = 60.0 / Double(max(effectiveHeartRate, 1))
        heartTimerPublisher = Timer.publish(every: interval, on: .main, in: .common).autoconnect()
    }
    
    private func setupOnAppear() {
        // HealthKit開始
        healthKitManager.appModeManager = appModeManager
        healthKitManager.currentUserID = sharedData.receivedData
        
        healthKitManager.authorizeHealthKit { success, _ in
            if success {
                healthKitManager.startHeartRateQuery()
            }
        }
        
        // 3秒おきアップロード開始
        startHeartRateUploadTimer()
        
        // モード監視開始
        startModeCheckTimer()
        
        heartIsActive = true
    }
    
    // 3秒おきにアップロード
    private func startHeartRateUploadTimer() {
        uploadTimer?.invalidate()
        uploadTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            uploadCurrentHeartRate()
        }
    }
    
    private func uploadCurrentHeartRate() {
        let hr = healthKitManager.currentHeartRate
        
        switch appModeManager.currentMode {
        case 0: // 一人モード
            putHeartRateToFirebase(heartRate: hr)
        case 1: // 二人モード
            if appModeManager.selectUser != "None" {
                putHeartRateToFirebase(heartRate: hr)
            }
        case 2: // みんなモード
            if appModeManager.isHostUser {
                putHeartRateToFirebase(heartRate: hr)
            }
        default:
            break
        }
    }
    
    private func putHeartRateToFirebase(heartRate: Int) {
        if lastUploadedHeartRate == heartRate { return }
        guard !sharedData.receivedData.isEmpty else { return }
        
        let path = "\(myURL)/Userdata/\(sharedData.receivedData)/Heartbeat/Watch1.json"
        guard let url = URL(string: path) else { return }
        
        let dataPoint: [String: Any] = [
            "HeartRate": heartRate,
            "Timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dataPoint)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("Error uploading heart rate: \(error)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("Heart rate uploaded with code: \(httpResponse.statusCode) [\(heartRate) BPM]")
                    DispatchQueue.main.async {
                        self.lastRemoteHeartRate = heartRate
                        self.lastUploadedHeartRate = heartRate
                    }
                }
            }.resume()
        } catch {
            print("Error serializing heart rate data: \(error)")
        }
    }
    
    private func startModeCheckTimer() {
        modeCheckTimer?.invalidate()
        modeCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.fetchCurrentModeFromFirebase()
        }
    }
    
    private func fetchCurrentModeFromFirebase() {
        guard !sharedData.receivedData.isEmpty else { return }
        
        let path = "\(myURL)/Userdata/\(sharedData.receivedData)/AppState.json"
        guard let url = URL(string: path) else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let mode = dict["CurrentMode"] as? Int
                {
                    let selectUser = dict["SelectUser"] as? String ?? "None"
                    let lastUpdated = dict["LastUpdated"] as? Double ?? 0
                    
                    DispatchQueue.main.async {
                        let oldMode = self.appModeManager.currentMode
                        let oldSelectUser = self.appModeManager.selectUser
                        
                        self.appModeManager.currentMode = mode
                        self.appModeManager.selectUser = selectUser
                        self.appModeManager.lastUpdated = lastUpdated
                        
                        if oldMode != mode {
                            self.appModeManager.triggerModeTransition()
                        }
                        if oldSelectUser != selectUser && mode == 1 && selectUser != "None" {
                            WKInterfaceDevice.current().play(.success)
                        }
                    }
                }
            } catch {
                print("Error parsing AppState: \(error)")
            }
        }.resume()
    }
    
    
    private func updateHeartAnimation() {
        guard heartIsActive else { return }
        
        // モードに応じてアニメーションを更新するかどうか判断
        let shouldAnimate: Bool
        
        switch appModeManager.currentMode {
        case 0: // 一人モード
            shouldAnimate = true
        case 1: // 二人モード
            // 相手が選択されていて、接続中の場合のみアニメーション
            shouldAnimate = !appModeManager.shouldShowWaitingView && appModeManager.selectUser != "None" && isPartnerActive
        case 2: // みんなモード
            if isViewingLive {
                // 視聴者モードでは常にアニメーション
                shouldAnimate = true
            } else if appModeManager.isHostUser {
                // ホスト自身はブロードキャスト中のみアニメーション
                shouldAnimate = appModeManager.isBroadcasting
            } else {
                // 非ホスト（視聴者）はホストが配信中のみアニメーション
                shouldAnimate = appModeManager.isBroadcasting
            }
        default:
            shouldAnimate = false
        }
        
        // アニメーションの実行
        if shouldAnimate {
            let beatInterval = 60.0 / Double(max(effectiveHeartRate, 1))
            
            rippleScale = 1.0
            rippleOpacity = 1.0
            
            withAnimation(.easeInOut(duration: beatInterval / 4)) {
                heartScale = 1.3
                rippleScale = 1.3
            }
            withAnimation(.easeInOut(duration: beatInterval + 0.1)) {
                rippleScale = 1.8
                rippleOpacity = 0.0
            }
            withAnimation(Animation.easeInOut(duration: beatInterval * 3 / 4)
                            .delay(beatInterval / 4)) {
                heartScale = 1.0
            }
            
            // 振動を発生させるかどうかチェック
            if shouldUseVibration {
                triggerVibrationPattern(vibrationManager.settings)
            }
        }
    }

    
    // 振動パターン：心臓の鼓動を模倣した二段階の振動（ドックン）
    private func triggerVibrationPattern(_ settings: VibrationSettings) {
        guard settings.toggle else { return }
        
        // 振動強度の設定 (0=弱, 1=中, 2=強)
        let firstBeat: WKHapticType  // 第一振動（ドッ）
        let secondBeat: WKHapticType // 第二振動（クン）
        
        switch settings.number {
        case 0: // 弱い振動
            firstBeat = .click
            secondBeat = .directionDown
        case 1: // 中程度の振動
            firstBeat = .directionUp
            secondBeat = .click
        case 2: // 強い振動
            firstBeat = .notification
            secondBeat = .success
        default:
            firstBeat = .click
            secondBeat = .directionDown
        }
        
        // 第一振動（ドッ）
        WKInterfaceDevice.current().play(firstBeat)
        
        // 第二振動（クン）- 実際の心拍を模倣して約0.1秒後に第二振動
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WKInterfaceDevice.current().play(secondBeat)
        }
    }
    
    // モードに応じた振動タイミングの設定
    private var shouldUseVibration: Bool {
        // 基本条件：設定で振動がOFFの場合は常に振動しない
        guard vibrationManager.settings.toggle else { return false }
        
        switch appModeManager.currentMode {
        case 0: // 一人モード
            return true // 自分の心拍に合わせて振動
            
        case 1: // 二人モード
            // 初期画面（相手未選択時）は振動しない
            if appModeManager.shouldShowWaitingView || appModeManager.selectUser == "None" {
                return false
            }
            // 相手が選択されていて、相手が接続状態の時のみ振動
            return isPartnerActive
            
        case 2: // みんなモード
            if isViewingLive {
                // 視聴者モードでは配信者の心拍に合わせて振動（ホストが配信中の場合のみ）
                return true
            } else if appModeManager.isHostUser {
                // ホスト自身の場合は、ブロードキャスト中のみ振動
                return appModeManager.isBroadcasting
            } else {
                // 非ホスト（視聴者）の場合、配信中のみ振動
                // 配信が開始されていない初期画面では振動しない
                return appModeManager.isBroadcasting
            }
            
        case 3: // 設定モード
            return false // 設定モードでは振動しない
            
        default:
            return false
        }
    }
    
}

// MARK: - プレビュー
struct HelloView_Previews: PreviewProvider {
    static var previews: some View {
        HelloView()
            .environmentObject(LoginConnector())
            .environmentObject(ExtensionDelegate())
    }
}
