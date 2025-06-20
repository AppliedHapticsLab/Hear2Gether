import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct HeartRateOnlyView: View {
    var roomID: String            // ルームID
    var selectedUser: String      // 表示用のユーザー名
    var userUID: String           // Firebase 上のユーザーID（uid）
    
    @State private var myHeartRate: Int = 0      // 自分の心拍数
    @State private var opponentHeartRate: Int = 0 // 相手の心拍数
    @State private var isOpponentActive: Bool = false // 相手のApple Watchのアクティブ状態
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var viewModeManager: ViewModeManager
    
    // ハート・リップルアニメーション用の状態変数
    @State private var heartScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.5
    @State private var heartOpacity: Double = 1.0
    @State private var rippleOpacity: Double = 1.0
    @State private var isAnimating: Bool = false
    
    // Firebase observer 用ハンドル（解除用）
    @State private var myHeartRateHandle: DatabaseHandle?
    @State private var opponentHeartRateHandle: DatabaseHandle?
    @State private var connectionStatusHandle: DatabaseHandle?
    @State private var opponentActiveStatusHandle: DatabaseHandle? // 相手のアクティブ状態監視用ハンドル
    
    // 接続状態アラート用の状態変数
    @State private var showDisconnectionAlert: Bool = false
    @State private var roomStatus: String = "Connected"
    
    // ビューが自分で更新したフラグ
    @State private var selfUpdatedStatus: Bool = false
    
    // Add this property to HeartRateOnlyView
    private let hapticManager = HapticManager()
    
    /// 心拍数に応じた1拍あたりの間隔（秒）
    var beatInterval: Double {
        60.0 / Double(max(opponentHeartRate, 1))
    }
    
    // 心拍数の差を計算
    private var heartRateDifference: Int {
        abs(myHeartRate - opponentHeartRate)
    }
    
    var body: some View {
        ZStack {
            // 黒い背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            // コンテンツ
            VStack(spacing: 30) {
                
                // ユーザー名の表示
                Text(selectedUser)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 10)
                
                // ハートとリップルのアニメーション表示
                ZStack {
                    // 外側の円形グロー効果
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.red.opacity(0.5),
                                    Color.red.opacity(0.0)
                                ]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 150
                            )
                        )
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0.6 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: beatInterval)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    RippleView(scale: $rippleScale, opacity: $rippleOpacity)
                    
                    HeartView(scale: heartScale, opacity: heartOpacity, color: isOpponentActive ? .red : .gray)
                }
                .frame(width: 240, height: 240)
                .padding(.vertical, 30)
                // 心拍数に合わせたタイマーでアニメーションを実行
                .onReceive(
                    Timer.publish(every: beatInterval, on: .main, in: .common).autoconnect()
                ) { _ in
                    // 相手がアクティブな場合のみアニメーションを実行
                    if isOpponentActive {
                        // 初期状態にリセット
                        rippleScale = 1.0
                        rippleOpacity = 1.0
                        
                        // 拡大アニメーション（1拍の1/4の間隔）
                        withAnimation(.easeInOut(duration: beatInterval / 4)) {
                            heartScale = 1.3
                            rippleScale = 1.3
                        }
                        // リップルが徐々に消えるアニメーション（全体の間隔を利用）
                        withAnimation(.easeInOut(duration: beatInterval + 0.1)) {
                            rippleScale = 2.0
                            rippleOpacity = 0.0
                        }
                        // ハートが元に戻るアニメーション（タイミング調整のため遅延を設定）
                        withAnimation(Animation.easeInOut(duration: beatInterval * 3 / 4)
                                        .delay(beatInterval / 4)) {
                            heartScale = 1.0
                        }
                    } else {
                        // 非アクティブの場合はアニメーションを停止
                        heartScale = 1.0
                        rippleScale = 0.0
                        rippleOpacity = 0.0
                    }
                }
                
                // 心拍数表示
                VStack(spacing: 8) {
                    // "心拍数" テキスト
                    Text("心拍数")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.7))
                    
                    // BPM表示 - 相手がアクティブでない場合は"閲覧モード中"と表示
                    if isOpponentActive {
                        HStack(alignment: .bottom, spacing: 5) {
                            Text("\(opponentHeartRate)")
                                .font(.system(size: 70, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("BPM")
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.8))
                                .padding(.bottom, 12)
                        }
                    } else {
                        VStack(spacing: 5) {
                            Text("閲覧モード中")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Apple Watchが非アクティブです")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }
                }
                .padding(25)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color("222222"),
                                    Color("111111")
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 0)
                )
                
                // 心拍数比較表示
                HStack(spacing: 20) {
                    // 自分の心拍数
                    VStack(spacing: 4) {
                        Text("あなた")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // 閲覧モードの場合は異なる表示をする
                        if viewModeManager.isViewOnlyMode {
                            Text("閲覧モード")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("--- BPM")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(myHeartRate) BPM")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("222222"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // 差分表示 - 相手がアクティブかつ自分が閲覧モードでない場合のみ表示
                    if isOpponentActive && !viewModeManager.isViewOnlyMode {
                        VStack(spacing: 4) {
                            Text("差")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("\(heartRateDifference)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(heartRateDifference > 10 ? .orange : .green)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("1A1A1A"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            heartRateDifference > 10 ?
                                            Color.orange.opacity(0.5) : Color.green.opacity(0.5),
                                            lineWidth: 1
                                        )
                                )
                        )
                    } else {
                        // 相手が非アクティブまたは自分が閲覧モードの場合の表示
                        VStack(spacing: 4) {
                            Text("状態")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("非アクティブ")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("1A1A1A"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 戻るボタンが押されたときにFirebaseの状態を更新
                        selfUpdatedStatus = true  // 自分で更新したフラグを立てる
                        updateConnectionStatus(to: "cancelled") {
                            dismiss()
                        }
                    }) {
                        Text("戻る")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // 相手がアクティブな場合のみアニメーション開始
            isAnimating = isOpponentActive
            
            // 心拍数の監視を設定
            setupHeartRateObservers()
            
            // 相手のアクティブ状態監視を設定
            setupOpponentActiveStatusObserver()
            
            // ルームのステータス監視を設定
            setupConnectionStatusObserver()
            
            // 接続状態を「Connected」に更新
            updateConnectionStatus(to: "Connected")
            
            updateSelectedUser(userUID: userUID)
        }
        .onDisappear {
            // アニメーション停止
            isAnimating = false
            
            // 監視を解除
            removeAllObservers()
            
            // 自分で更新フラグが立っていなければ更新する
            if !selfUpdatedStatus {
                updateConnectionStatus(to: "cancelled")
            }
            
            updateSelectedUser(userUID: "None")
        }
        .onReceive(
            Timer.publish(every: beatInterval, on: .main, in: .common).autoconnect()
        ) { _ in
            // 相手がアクティブな場合のみアニメーションを実行
            if isOpponentActive {
                // Initial state reset
                rippleScale = 1.0
                rippleOpacity = 1.0
                
                // Expansion animation (1/4 of the interval)
                withAnimation(.easeInOut(duration: beatInterval / 4)) {
                    heartScale = 1.3
                    rippleScale = 1.3
                }
                // Ripple gradually disappears (whole interval plus a bit)
                withAnimation(.easeInOut(duration: beatInterval + 0.1)) {
                    rippleScale = 2.0
                    rippleOpacity = 0.0
                }
                // Heart returns to normal (timing adjusted with delay)
                withAnimation(Animation.easeInOut(duration: beatInterval * 3 / 4)
                                .delay(beatInterval / 4)) {
                    heartScale = 1.0
                }
            }
        }
        // 切断アラートの表示
        .alert("接続が切れました", isPresented: $showDisconnectionAlert) {
            Button("OK", role: .cancel) {
                dismiss() // ビューを閉じる
            }
        } message: {
            Text("相手との接続が切れました。ホーム画面に戻ります。")
        }
    }
    
    // 相手のアクティブ状態を監視する関数
    private func setupOpponentActiveStatusObserver() {
        let ref = Database.database().reference()
        
        opponentActiveStatusHandle = ref.child("Userdata").child(userUID)
            .child("AppStatus").child("isActive")
            .observe(.value) { snapshot in
                guard let isActive = snapshot.value as? Bool else {
                    // Boolでない場合は文字列"true"かどうかをチェック
                    if let strValue = snapshot.value as? String {
                        DispatchQueue.main.async {
                            self.isOpponentActive = strValue.lowercased() == "true"
                        }
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.isOpponentActive = isActive
                    // アクティブ状態が変わったらアニメーション状態も更新
                    self.isAnimating = isActive
                    print("相手のアクティブ状態が更新されました: \(isActive)")
                }
            }
    }
    
    // New function to implement in HeartRateOnlyView for haptic feedback
    private func provideHeartbeatHapticFeedback() {
        // No need to check if vibration is enabled as that's handled in the manager
        
        // Use the heart rate interval for timing
        let interval = beatInterval
        
        // Use our updated function that incorporates user settings
        hapticManager.playHeartbeatHapticWithSettings(interval: interval)
        
        // Also provide a light standard vibration as a fallback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.4)
    }
    
    // 接続状態を監視する関数
    private func setupConnectionStatusObserver() {
        let ref = Database.database().reference()
        
        connectionStatusHandle = ref.child("GameRooms").child(roomID).child("status")
            .observe(.value) { snapshot in
                guard let status = snapshot.value as? String else { return }
                
                DispatchQueue.main.async {
                    // 前のステータスを保存
                    let oldStatus = self.roomStatus
                    self.roomStatus = status
                    
                    print("接続ステータスが更新されました: \(status)")
                    
                    // ステータスが「cancelled」または「waiting」の場合にアラートを表示
                    if (status == "cancelled" || status == "waiting") &&
                       oldStatus == "Connected" &&
                       !self.selfUpdatedStatus {
                        print("アラート表示条件を満たしています")
                        self.showDisconnectionAlert = true
                    }
                }
            }
    }
    
    // 接続状態を更新する関数
    private func updateConnectionStatus(to status: String, completion: (() -> Void)? = nil) {
        guard Auth.auth().currentUser != nil else {
            completion?()
            return
        }
        
        let ref = Database.database().reference()
        let statusData = [
            "status": status
        ] as [String : Any]
        
        // ルームの接続状態を更新
        ref.child("GameRooms").child(roomID).updateChildValues(statusData) { (error, _) in
            if let error = error {
                print("Error updating connection status: \(error.localizedDescription)")
            } else {
                print("Connection status updated to: \(status)")
            }
            completion?()
        }
    }
    
    // 選択したユーザー更新関数
    private func updateSelectedUser(userUID: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUser = Auth.auth().currentUser else {
            completion?(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }
        
        let ref = Database.database().reference()
        let currentUID = currentUser.uid
        
        // AppState の更新データ
        let appStateData = [
            "SelectUser": userUID
        ] as [String: Any]
        
        // MyPreference/Vibration の更新データ
        let vibrationData = [
            "SelectUser": userUID,
            "SelectUserName": selectedUser  // selectedUser パラメータを使用
        ] as [String: Any]
        
        // ユーザーの選択状態を AppState で更新
        ref.child("Userdata").child(currentUID).child("AppState").updateChildValues(appStateData) { (error, _) in
            if let error = error {
                print("Error updating AppState: \(error.localizedDescription)")
                completion?(error)
                return
            }
            
            // ユーザーの選択状態を MyPreference/Vibration でも更新
            ref.child("Userdata").child(currentUID).child("MyPreference").child("Vibration").updateChildValues(vibrationData) { (error, _) in
                if let error = error {
                    print("Error updating Vibration preferences: \(error.localizedDescription)")
                } else {
                    print("User selections updated successfully: UID=\(userUID), Name=\(selectedUser)")
                }
                completion?(error)
            }
        }
    }
    
    // 心拍数監視の設定
    private func setupHeartRateObservers() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUID = currentUser.uid
        
        let ref = Database.database().reference()
        
        // 自分の心拍数を監視
        myHeartRateHandle = ref.child("Userdata").child(currentUID)
            .child("Heartbeat").child("Watch1").child("HeartRate")
            .observe(.value) { snapshot in
                var rate: Int = 0
                if let intRate = snapshot.value as? Int {
                    rate = intRate
                } else if let strRate = snapshot.value as? String, let intVal = Int(strRate) {
                    rate = intVal
                }
                DispatchQueue.main.async {
                    self.myHeartRate = rate
                }
            }
        
        // 相手の心拍数を監視
        opponentHeartRateHandle = ref.child("Userdata").child(userUID)
            .child("Heartbeat").child("Watch1").child("HeartRate")
            .observe(.value) { snapshot in
                var rate: Int = 0
                if let intRate = snapshot.value as? Int {
                    rate = intRate
                } else if let strRate = snapshot.value as? String, let intVal = Int(strRate) {
                    rate = intVal
                }
                DispatchQueue.main.async {
                    self.opponentHeartRate = rate
                }
            }
    }
    
    // 全ての監視を解除
    private func removeAllObservers() {
        let ref = Database.database().reference()
        
        // 心拍数の監視を解除
        if let handle = myHeartRateHandle {
            guard let currentUser = Auth.auth().currentUser else { return }
            ref.child("Userdata").child(currentUser.uid)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .removeObserver(withHandle: handle)
        }
        
        if let handle = opponentHeartRateHandle {
            ref.child("Userdata").child(userUID)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .removeObserver(withHandle: handle)
        }
        
        // 接続状態の監視を解除
        if let handle = connectionStatusHandle {
            ref.child("GameRooms").child(roomID).child("status")
                .removeObserver(withHandle: handle)
        }
        
        // 相手のアクティブ状態監視を解除
        if let handle = opponentActiveStatusHandle {
            ref.child("Userdata").child(userUID)
                .child("AppStatus").child("isActive")
                .removeObserver(withHandle: handle)
        }
    }
}

struct HeartRateOnlyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HeartRateOnlyView(
                roomID: "preview_room",
                selectedUser: "Test User",
                userUID: "dummyUID"
            )
            .environmentObject(AuthViewModel())
            .environmentObject(ViewModeManager())
        }
    }
}
