import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import Kingfisher
import CoreHaptics
import Combine
import AVFoundation

// HapticManagerクラスの追加 (ThirdViewから移植)
class HapticManager {
    var engine: CHHapticEngine?

    init() {
        createEngine()
    }

    func createEngine() {
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            // エンジンが停止した場合の再起動処理
            engine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.createEngine()
            }
            
            // エンジンのリセット処理
            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                do {
                    try self?.engine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            print("There was an error creating the haptic engine: \(error.localizedDescription)")
        }
    }

    // 心拍に合わせた振動パターンを再生
    func playHeartbeatHaptic(interval: Double) {
        // 心拍間隔に合わせて振動の強さと鋭さを調整
        // 心拍数が高いほど振動は軽く、鋭く
        let intensityLevel = min(1.0, max(0.3, 0.7 - (interval * 0.5)))
        let sharpnessLevel = min(1.0, max(0.3, 0.8 - (interval * 0.4)))
        
        // メインの振動
        let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensityLevel))
        let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpnessLevel))
        let mainEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity1, sharpness1],
            relativeTime: 0.0
        )
        
        // 2番目の振動（よりソフトで心臓の2番目の拍動を表現）
        let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensityLevel * 0.5))
        let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpnessLevel * 0.6))
        let secondEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity2, sharpness2],
            relativeTime: interval * 0.15 // 最初の振動から少し遅れて発生
        )
        
        do {
            let pattern = try CHHapticPattern(events: [mainEvent, secondEvent], parameterCurves: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play heartbeat haptic pattern: \(error.localizedDescription)")
        }
    }
}

// カラーテーマ
struct ColorManager {
    // 新しいデザインのカラー
    static let primaryColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    static let secondaryColor = Color(red: 0.98, green: 0.4, blue: 0.5)
    static let backgroundColor = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let cardColor = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let textColor = Color.white
    static let subtleTextColor = Color.white.opacity(0.7)
    static let inactiveColor = Color.gray.opacity(0.5)
    static let rippleColor = Color(red: 0.95, green: 0.2, blue: 0.3).opacity(0.8)
    
    // 元のコードで使用されていたカラー
    static let mainColor = Color.white
}

// ハートビュー：scale と opacity は値として受け取る
struct HeartView: View {
    let scale: CGFloat
    let opacity: Double
    var color: Color = ColorManager.primaryColor
    
    var body: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: 120, height: 120)
            .scaleEffect(scale)
            .opacity(opacity)
            .shadow(color: color.opacity(0.6), radius: 10, x: 0, y: 0)
    }
}

// リップル（波紋）ビューは ON状態でのみ利用
struct RippleView: View {
    @Binding var scale: CGFloat
    @Binding var opacity: Double
    
    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(ColorManager.rippleColor)
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .opacity(opacity)
                .shadow(color: ColorManager.primaryColor.opacity(0.8), radius: 15, x: 0, y: 0)
                .blur(radius: 3)
            
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(ColorManager.primaryColor.opacity(0.5))
                .frame(width: 120, height: 120)
                .scaleEffect(scale - 0.2)
                .opacity(opacity * 0.7)
                .shadow(color: ColorManager.primaryColor.opacity(0.4), radius: 8, x: 0, y: 0)
        }
    }
}

/// CenterFadeCircleView：青い円が初期状態から中央に向かって縮小し透明になり、その後再び現れるアニメーション
struct CenterFadeCircleView: View {
    let delay: Double  // 各リング毎に異なる遅延時間を設定できる
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [ColorManager.primaryColor.opacity(0.7), ColorManager.secondaryColor.opacity(0.5)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
            .frame(width: 180, height: 180)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                animateCircle()
            }
    }
    
    private func animateCircle() {
        withAnimation(
            Animation.easeOut(duration: 1.2)
                .repeatForever(autoreverses: false)
                .delay(delay)
        ) {
            scale = 0.7
            opacity = 0.0
        }
    }
}

/// 複数のリングを重ねて表示するビュー
struct MultiCenterFadeCircleView: View {
    let ringCount: Int = 3
    let baseDelay: Double = 0.4
    
    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { index in
                CenterFadeCircleView(delay: Double(index) * baseDelay)
            }
        }
    }
}

// 既存のOnePersonHeartRateViewに追加するプロパティ
class HeartbeatSoundManager {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var isPlaying = false
    
    // 心拍音の初期化
    init() {
        prepareAudioPlayer()
    }
    
    private func prepareAudioPlayer() {
        // サブディレクトリを指定せずに単純にパスを取得してみる
        guard let soundPath = Bundle.main.path(forResource: "BBM", ofType: "wav") else {
                print("Error: Sound file not found")
                return
            }
        
        // パスからURLを作成
            let soundURL = URL(fileURLWithPath: soundPath)
            
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
            } catch {
                print("Error initializing audio player: \(error.localizedDescription)")
            }
    }
    
    // 心拍数に応じて音を再生
    func startPlayingHeartbeat(bpm: Int) {
        guard let player = audioPlayer, !isPlaying else { return }
        
        isPlaying = true
        
        // BPMに基づく間隔を計算（秒）
        let interval = 60.0 / Double(max(bpm, 30))
        
        // 前のタイマーを停止
        timer?.invalidate()
        
        // 新しいタイマーを設定
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in

            player.currentTime = 0
            player.play()
        }
    }
    
    // 心拍音を停止
    func stopPlayingHeartbeat() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    // 心拍数の変更時に呼び出す
    func updateHeartbeatRate(bpm: Int) {
        if isPlaying {
            stopPlayingHeartbeat()
            startPlayingHeartbeat(bpm: bpm)
        }
    }
}

struct HeartRateCard: View {
    var heartRate: Int
    var recordStarted: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("心拍数")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(ColorManager.subtleTextColor)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(heartRate)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(recordStarted ? ColorManager.primaryColor : ColorManager.subtleTextColor)
                
                Text("BPM")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(recordStarted ? ColorManager.secondaryColor : ColorManager.subtleTextColor)
                    .padding(.leading, 4)
            }
            
            HStack(spacing: 12) {
                // 心拍波形アイコン
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14))
                    .foregroundColor(recordStarted ? ColorManager.primaryColor : ColorManager.inactiveColor)
                
                // 心拍数の範囲インジケータ（例：安静時など）
                Text(getHeartRateRangeText(heartRate))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(recordStarted ? ColorManager.secondaryColor : ColorManager.inactiveColor)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorManager.cardColor)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            recordStarted ? ColorManager.primaryColor.opacity(0.5) : Color.clear,
                            recordStarted ? ColorManager.secondaryColor.opacity(0.3) : Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
    
    // 心拍数に応じたテキストを取得
    private func getHeartRateRangeText(_ rate: Int) -> String {
        if rate < 60 {
            return "安静時の心拍数"
        } else if rate < 100 {
            return "通常の心拍数"
        } else if rate < 140 {
            return "運動時の心拍数"
        } else {
            return "高い心拍数"
        }
    }
}

struct OnePersonHeartRateView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var displayName: String = "Loading..."
    @State private var profileImageURL: String? = nil
    @State private var heartRate: Int = 60
    
    // Timestampの状態変数を追加
    @State private var lastTimestamp: Double = 0
    
    // ON状態用（記録中）のアニメーション変数
    @State private var heartScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.5
    @State private var heartOpacity: Double = 1.0
    @State private var rippleOpacity: Double = 0.0
    
    // パルスアニメーション用
    @State private var pulseAnimation = false
    
    // Firebase の observer 用ハンドル
    @State private var usernameHandle: DatabaseHandle?
    @State private var heartRateHandle: DatabaseHandle?
    @State private var timestampHandle: DatabaseHandle?
    @State private var recordStartHandle: DatabaseHandle?
    
    // RecordStart の状態（true: 記録中 / ON, false: 記録停止中 / OFF）
    @State private var recordStarted: Bool = false
    
    // 心拍数が変化したときの祝福メッセージ表示用
    @State private var showHeartRateChange: Bool = false
    @State private var previousHeartRate: Int = 0
    
    // アニメーション制御用の追加状態変数
    @State private var lastBeatTime: Date = Date()
    @State private var isAnimating: Bool = false
    @State private var heartbeatTimer: Timer? = nil
    
    // 追加: HapticManagerのインスタンス
    private let hapticManager = HapticManager()
    
    // 追加: 振動フィードバック設定
    @AppStorage("iphoneVibrationEnabled") private var hapticFeedbackEnabled: Bool = false
    
    // WatchConnectivity用
    @EnvironmentObject var watchConnectivity: iPhoneWatchConnectivityService
    @State private var heartRateSubscription: AnyCancellable?
    @State private var watchActiveSubscription: AnyCancellable?
    
    // OnePersonHeartRateView内に追加
    @State private var heartbeatSoundManager = HeartbeatSoundManager()
    @State private var isHeartbeatSoundEnabled: Bool = true // 音を有効/無効にするトグル
    
    /// 心拍数に応じた1拍あたりの間隔（秒）
    var beatInterval: Double {
        60.0 / Double(max(heartRate, 1))
    }
    
    var body: some View {
        ZStack {
            // 背景
            ColorManager.backgroundColor
                .ignoresSafeArea()
            
            // メインコンテンツ
            VStack(spacing: 0) {
                
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("心拍モニタリング")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(ColorManager.subtleTextColor)
                            
                            Text(displayName)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(ColorManager.textColor)
                        }
                        
                        Spacer()
                        
                        // プロフィール画像
                        if let urlStr = profileImageURL, let url = URL(string: urlStr) {
                            KFImage(url)
                                .placeholder {
                                    Circle()
                                        .fill(ColorManager.cardColor)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: ColorManager.subtleTextColor))
                                        )
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    ColorManager.primaryColor.opacity(0.8),
                                                    ColorManager.secondaryColor.opacity(0.8)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: ColorManager.primaryColor.opacity(0.3), radius: 8, x: 0, y: 0)
                        } else {
                            Circle()
                                .fill(ColorManager.cardColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: ColorManager.subtleTextColor))
                                )
                        }
                    }
                    .padding(.horizontal, 25)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // メインコンテンツ - ハートのアニメーション
                ZStack {
                    // 状態に応じたアニメーション
                    if recordStarted {
                        // ON状態：リップルと赤いハートのアニメーション
                        RippleView(scale: $rippleScale, opacity: $rippleOpacity)
                        HeartView(scale: heartScale, opacity: heartOpacity, color: ColorManager.primaryColor)
                    } else {
                        // OFF状態：背景に中央に向かって消える円、前面に固定の灰色ハート
                        MultiCenterFadeCircleView()
                        HeartView(scale: 1.0, opacity: 1.0, color: ColorManager.inactiveColor)
                        
                        // タップ促進テキスト - 位置を調整
                        VStack {
                            Spacer()
                            Text("タップして開始")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(ColorManager.subtleTextColor)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    Capsule()
                                        .fill(ColorManager.cardColor.opacity(0.7))
                                )
                                .opacity(pulseAnimation ? 0.7 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: pulseAnimation
                                )
                        }
                        .frame(height: 200)
                        .onAppear {
                            pulseAnimation = true
                        }
                    }
                }
                .onAppear {
                    // タイマーの初期化
                    startHeartbeatTimer()
                }
                .frame(height: 250) // 高さを固定して重なりを防止
                // ジェスチャー設定：ON状態ではダブルタップで停止、OFF状態ではシングルタップで開始
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            if recordStarted {
                                toggleRecordStart() // ダブルタップで停止
                                
                                // 触覚フィードバック
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.warning)
                            }
                        }
                )
                .onTapGesture {
                    if !recordStarted {
                        toggleRecordStart() // シングルタップで開始
                        
                        // 触覚フィードバック
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
                
                Spacer()
                    .frame(height: 40)
                
                // 心拍数表示カード
                HeartRateCard(heartRate: heartRate, recordStarted: recordStarted)
                    .padding(.horizontal, 25)
                
                // 状態表示およびヘルプテキスト
                Text(recordStarted ? "記録中" : "タップして心拍数の記録を開始します")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(recordStarted ? ColorManager.secondaryColor : ColorManager.subtleTextColor)
                    .padding(.top, 15)
                
                // 心拍数変化時の祝福メッセージ（条件付きで表示）
                if showHeartRateChange, recordStarted {
                    let change = heartRate - previousHeartRate
                    let isIncrease = change > 0
                    
                    HStack {
                        Image(systemName: isIncrease ? "arrow.up.heart.fill" : "arrow.down.heart.fill")
                            .foregroundColor(isIncrease ? ColorManager.secondaryColor : ColorManager.primaryColor.opacity(0.7))
                        
                        Text("\(abs(change)) BPM \(isIncrease ? "上昇" : "低下")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorManager.subtleTextColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(ColorManager.cardColor)
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    )
                    .padding(.top, 10)
                    .transition(.opacity)
                }
                
                // 最終更新情報とステータス表示
                if recordStarted {
                    VStack(spacing: 4) {
                        Text("最終更新: \(formatTimestamp(lastTimestamp))")
                            .font(.system(size: 12))
                            .foregroundColor(ColorManager.subtleTextColor.opacity(0.7))
                        
                        // 最終更新からの経過時間に基づくステータス表示
                        let currentTimeMs = Date().timeIntervalSince1970 * 1000
                        let timeSinceLastUpdate = (currentTimeMs - lastTimestamp) / 1000 // 秒に変換
                        
                        if timeSinceLastUpdate > 300 {
                            Text("心拍データが5分以上更新されていません")
                                .font(.system(size: 12))
                                .foregroundColor(Color.orange)
                        } else {
                            Text("心拍データは最新です")
                                .font(.system(size: 12))
                                .foregroundColor(ColorManager.secondaryColor)
                        }
                    }
                    .padding(.top, 8)
                }
                
                // タブバー用の余白
                Spacer()
                    .frame(height: 100)
            }
            .foregroundColor(ColorManager.textColor)
        }
        .onAppear {
            // ユーザー情報の読み込み
            loadUserData()
            
            // WatchConnectivityからのデータ購読を設定
            setupWatchConnectivitySubscriptions()
            
            // Firebase上のバイブレーション設定を取得
            loadRecordStartState()
            
            // 追加: Firebase心拍データを監視
            setupFirebaseHeartRateObserver()
            
            // ユーザーIDをWatchConnectivityServiceに設定
            if let user = authViewModel.currentUser {
                watchConnectivity.setUserID(user.uid)
            }
        }
        .onDisappear {
            // 購読を解除
            heartRateSubscription?.cancel()
            watchActiveSubscription?.cancel()
            
            // Firebase監視も解除
            removeFirebaseObservers()
            
            // タイマーを停止
            heartbeatTimer?.invalidate()
        }
    }
    
    // 追加: Firebase心拍データ監視のセットアップ
    private func setupFirebaseHeartRateObserver() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        print("Firebase心拍データ監視を開始しました: \(uid)")
        
        // 心拍データの監視（変更のみを監視）
        heartRateHandle = ref.child("Userdata").child(uid).child("Heartbeat").child("Watch1")
            .observe(.value) { snapshot in
                print("Firebase心拍データ更新を検出: \(snapshot.value ?? "nil")")
                
                // スナップショットに値がない場合
                guard snapshot.exists() else {
                    print("Firebase心拍データが存在しません")
                    return
                }
                
                if let dict = snapshot.value as? [String: Any] {
                    print("Firebase心拍データ: \(dict)")
                    
                    // HeartRateの取得 - より柔軟な型変換
                    let newHeartRate: Int
                    if let hrInt = dict["HeartRate"] as? Int {
                        newHeartRate = hrInt
                    } else if let hrNumber = dict["HeartRate"] as? NSNumber {
                        newHeartRate = hrNumber.intValue
                    } else if let hrString = dict["HeartRate"] as? String, let hr = Int(hrString) {
                        newHeartRate = hr
                    } else {
                        print("Firebase心拍データの形式が不正: \(dict["HeartRate"] ?? "nil")")
                        return
                    }
                    
                    print("新しい心拍数: \(newHeartRate)、現在の心拍数: \(self.heartRate)")
                    
                    // タイムスタンプの取得 - より柔軟な型変換
                    var timestamp: Double = 0
                    if let tsDouble = dict["Timestamp"] as? Double {
                        timestamp = tsDouble
                    } else if let tsInt = dict["Timestamp"] as? Int {
                        timestamp = Double(tsInt)
                    } else if let tsNumber = dict["Timestamp"] as? NSNumber {
                        timestamp = tsNumber.doubleValue
                    } else if let tsString = dict["Timestamp"] as? String, let ts = Double(tsString) {
                        timestamp = ts
                    } else {
                        print("Firebaseタイムスタンプの形式が不正: \(dict["Timestamp"] ?? "nil")")
                        // タイムスタンプがなくても心拍数の更新は続行
                        timestamp = Date().timeIntervalSince1970 * 1000
                    }
                    
                    // UIの更新は常にメインスレッドで
                    DispatchQueue.main.async {
                        // 条件チェックを緩和 - 常に最新の値に更新
                        let oldHeartRate = self.heartRate
                        self.heartRate = newHeartRate
                        self.lastTimestamp = timestamp
                        self.heartbeatSoundManager.updateHeartbeatRate(bpm: newHeartRate)
                        
                        print("心拍数をUIに反映: \(newHeartRate)")
                        
                        // 前回の心拍数と比較して変化があれば表示
                        if oldHeartRate > 0 && abs(oldHeartRate - newHeartRate) >= 5 {
                            self.previousHeartRate = oldHeartRate
                            
                            // 視覚的なフィードバック
                            withAnimation {
                                self.showHeartRateChange = true
                            }
                            
                            // 3秒後に非表示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    self.showHeartRateChange = false
                                }
                            }
                        }
                        
                        // 記録中かつ心拍数が有効な場合、最後の鼓動時間をリセット
                        if self.recordStarted && newHeartRate > 0 {
                            // 最後の鼓動時間をリセットして次の鼓動をすぐに表示
                            self.lastBeatTime = Date().addingTimeInterval(-self.beatInterval)
                        }
                    }
                } else {
                    print("Firebase心拍データをディクショナリに変換できません: \(snapshot.value ?? "nil")")
                }
            }
    }
    
    // WatchConnectivityからのデータ購読設定
    private func setupWatchConnectivitySubscriptions() {
        // 心拍数データの購読
        heartRateSubscription = watchConnectivity.$lastHeartRate
            .sink { newHeartRate in
                let oldHeartRate = self.heartRate
                
                // 心拍数が変わった場合のみ処理
                if newHeartRate != oldHeartRate {
                    DispatchQueue.main.async {
                        self.heartRate = newHeartRate
                        self.heartbeatSoundManager.updateHeartbeatRate(bpm: newHeartRate)
                        
                        // Firebaseにも反映
                        if self.recordStarted {
                            self.uploadHeartRateToFirebase(heartRate: newHeartRate)
                        }
                        
                        if self.recordStarted && self.isHeartbeatSoundEnabled {
                            self.heartbeatSoundManager.updateHeartbeatRate(bpm: newHeartRate)
                        }
                        
                        // タイムスタンプも更新
                        self.lastTimestamp = watchConnectivity.lastHeartRateTimestamp * 1000 // ミリ秒単位に変換
                        
                        // 前回の心拍数と比較して変化があれば表示
                        if oldHeartRate > 0 && abs(oldHeartRate - newHeartRate) >= 5 {
                            self.previousHeartRate = oldHeartRate
                            
                            // 視覚的なフィードバック
                            withAnimation {
                                self.showHeartRateChange = true
                            }
                            
                            // 3秒後に非表示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    self.showHeartRateChange = false
                                }
                            }
                        }
                        
                        // 記録中かつ心拍数が有効な場合、最後の鼓動時間をリセット
                        if self.recordStarted && newHeartRate > 0 {
                            // 最後の鼓動時間をリセットして次の鼓動をすぐに表示
                            self.lastBeatTime = Date().addingTimeInterval(-self.beatInterval)
                        }
                    }
                }
            }
        
        // Watch接続状態の購読
        watchActiveSubscription = watchConnectivity.$isWatchActive
            .sink { isActive in
                DispatchQueue.main.async {
                    // Watch非アクティブ時は記録も自動停止
                    if !isActive && self.recordStarted {
                        self.toggleRecordStart()
                    }
                }
            }
    }
    
    // タイムスタンプを表示用に整形するヘルパー関数
    private func formatTimestamp(_ timestamp: Double) -> String {
        guard timestamp > 0 else { return "まだ更新なし" }
        
        let date = Date(timeIntervalSince1970: timestamp/1000) // ミリ秒から秒に変換
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    // ユーザーデータの読み込み
    private func loadUserData() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        // ユーザー情報の監視
        usernameHandle = ref.child("Username").child(uid)
            .observe(.value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    self.displayName = dict["UName"] as? String ?? "不明なユーザー"
                    self.profileImageURL = dict["Uimage"] as? String
                }
            }
    }
    
    // RecordStart状態の読み込み
    private func loadRecordStartState() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        // RecordStart の監視
        recordStartHandle = ref.child("Userdata").child(uid)
            .child("MyPreference").child("Vibration").child("RecordStart")
            .observe(.value) { snapshot in
                if let value = snapshot.value as? Bool {
                    self.recordStarted = value
                }
            }
    }
    
    // FirebaseのWatchデータを更新
    private func uploadHeartRateToFirebase(heartRate: Int) {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        let dataDict: [String: Any] = [
            "HeartRate": heartRate,
            "Timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        
        // 現在の心拍を更新
        ref.child("Userdata").child(uid).child("Heartbeat").child("Watch1").setValue(dataDict) { error, _ in
            if let error = error {
                print("Error uploading heart rate: \(error.localizedDescription)")
            }
        }
    }
    
    // Firebase オブザーバーの削除
    private func removeFirebaseObservers() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        if let handle = usernameHandle {
            ref.child("Username").child(uid).removeObserver(withHandle: handle)
        }
        
        if let handle = recordStartHandle {
            ref.child("Userdata").child(uid)
                .child("MyPreference").child("Vibration").child("RecordStart")
                .removeObserver(withHandle: handle)
        }
        
        // 追加: 心拍データObserverの解除
        if let handle = heartRateHandle {
            ref.child("Userdata").child(uid).child("Heartbeat").child("Watch1")
                .removeObserver(withHandle: handle)
        }
    }
    
    // ハートタップによる RecordStart の切替処理
    private func toggleRecordStart() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        let newValue = !recordStarted
        
        // Firebaseの更新
        ref.child("Userdata").child(uid)
            .child("MyPreference").child("Vibration").child("RecordStart")
            .setValue(newValue) { error, _ in
                if let error = error {
                    print("RecordStart 更新エラー: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        // WatchConnectivityを通じて設定をApple Watchに送信
                        self.watchConnectivity.sendVibrationSettingsToWatch(
                            toggle: self.hapticFeedbackEnabled,
                            recordStart: newValue,
                            selectUser: "None",  // 一人モードでは選択ユーザーなし
                            selectUserName: "Mine",
                            number: 2  // デフォルトモード
                        )
                        
                        // 状態が変更されたときの処理
                        if newValue {
                            // ON状態に切り替えたとき
                            self.recordStarted = true
                            self.lastBeatTime = Date() // 最初の鼓動の基準時間をリセット
                            // 初期状態を設定
                            self.heartScale = 1.0
                            self.rippleScale = 0.5
                            self.rippleOpacity = 0.0
                            self.isAnimating = false // アニメーション状態をリセット
                            
                            if isHeartbeatSoundEnabled {
                                        heartbeatSoundManager.startPlayingHeartbeat(bpm: heartRate)
                                    }
                            
                            // タイマーを再初期化
                            self.startHeartbeatTimer()
                        } else {
                            // OFF状態に切り替えたとき
                            self.recordStarted = false
                            // タイマーを一時停止
                            self.heartbeatTimer?.invalidate()
                            self.heartbeatTimer = nil
                            // アニメーション状態をリセット
                            self.heartScale = 1.0
                            self.rippleScale = 0.5
                            self.heartOpacity = 1.0
                            self.rippleOpacity = 0.0
                            self.isAnimating = false
                            
                            heartbeatSoundManager.stopPlayingHeartbeat()
                        }
                    }
                    print("RecordStart 更新完了: \(newValue)")
                }
            }
    }
    
    // プライベート関数としてタイマーを定義
    private func startHeartbeatTimer() {
        // 既存のタイマーがあれば無効化
        heartbeatTimer?.invalidate()
        
        // 新しいタイマーを作成（より短い間隔に設定してより正確に）
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // 記録中かつ心拍数が有効な場合のみ処理
            if self.recordStarted && self.heartRate > 0 && !self.isAnimating {
                let now = Date()
                // 現在の心拍間隔を使用（コンピューテッドプロパティと同じ計算）
                let currentBeatInterval = self.beatInterval
                let timeSinceLastBeat = now.timeIntervalSince(self.lastBeatTime)
                
                // 前回の鼓動から適切な時間が経過しているか確認
                if timeSinceLastBeat >= currentBeatInterval {
                    // 最終更新からの経過時間をチェック
                    let currentTimeMs = Date().timeIntervalSince1970 * 1000
                    let timeSinceLastUpdate = (currentTimeMs - self.lastTimestamp) / 1000 // 秒に変換
                    
                    // 5分 = 300秒より長く更新がない場合はアニメーション停止
                    if timeSinceLastUpdate > 300 {
                        return
                    }
                    
                    // 次の鼓動の基準時間を設定（より正確な間隔を維持するため）
                    self.lastBeatTime = self.lastBeatTime.addingTimeInterval(currentBeatInterval)
                    // 時間のずれが大きすぎる場合は現在時刻にリセット
                    if abs(self.lastBeatTime.timeIntervalSince(now)) > currentBeatInterval {
                        self.lastBeatTime = now
                    }
                    
                    // 心拍数に基づいたアニメーションを実行
                    self.animateHeartbeat(interval: currentBeatInterval)
                }
            }
        }
    }

    // 心拍アニメーションの実行
    private func animateHeartbeat(interval: Double) {
        // アニメーション中なら処理しない
        guard !isAnimating else { return }
        
        // アニメーション中フラグをセット
        isAnimating = true
        
        // バイブレーション機能が有効で、記録中かつ心拍数が有効な場合のみ実行
        if hapticFeedbackEnabled && recordStarted && heartRate > 0 {
            // 心拍数に応じたバイブレーションを再生
            hapticManager.playHeartbeatHaptic(interval: interval)
            
            // 補助的な軽いバイブレーションを提供
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred(intensity: 0.4)
        }
        
        // 心拍数に基づくアニメーション時間を計算
        let animationDuration = interval * 0.8
        
        // 初期アニメーション状態をセット
        rippleScale = 0.9
        rippleOpacity = 0.7
        
        // ステップ1: ハートを膨らませる
        withAnimation(.easeInOut(duration: animationDuration * 0.3)) {
            heartScale = 1.25
            rippleScale = 1.2
        }
        
        // ステップ2: リップルを広げる
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.2) {
            withAnimation(.easeOut(duration: animationDuration * 0.5)) {
                self.rippleScale = 1.7
                self.rippleOpacity = 0.0
            }
        }
        
        // ステップ3: ハートを元のサイズに戻す
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.3) {
            withAnimation(.easeOut(duration: animationDuration * 0.4)) {
                self.heartScale = 1.0
            }
        }
        
        // アニメーション完了のスケジュール
        DispatchQueue.main.asyncAfter(deadline: .now() + (animationDuration * 0.95)) {
            self.isAnimating = false
        }
    }
}
