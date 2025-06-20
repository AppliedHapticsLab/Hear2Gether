import SwiftUI
import SpriteKit
import FirebaseDatabase
import FirebaseAuth

// 1. UIColorを整数に変換する拡張関数を追加
extension UIColor {
    func toInt() -> Int {
        if self == UIColor.clear { return 0 }
        else if self == UIColor.cyan { return 1 }
        else if self == UIColor.yellow { return 2 }
        else if self == UIColor.magenta { return 3 }
        else if self == UIColor.green { return 4 }
        else if self == UIColor.red { return 5 }
        else if self == UIColor.blue { return 6 }
        else if self == UIColor.orange { return 7 }
        else if self == UIColor.gray { return 9 }  // お邪魔ブロック
        else { return 8 }  // その他
    }
}

struct TetrisView: View {
    var roomID: String
    var opponentName: String
    var userUID: String? // 相手のUID（明示的に受け取る）
    
    @StateObject private var scene = TetrisGameScene(size: CGSize(width: 300, height: 500))
    
    // 心拍数関連のstate
    @State private var myHeartRate: Int = 0
    @State private var opponentHeartRate: Int = 0
    @State private var myHeartRateHandle: DatabaseHandle?
    @State private var opponentHeartRateHandle: DatabaseHandle?
    
    // 接続状態アラート用の状態変数
    @State private var showDisconnectionAlert: Bool = false
    @State private var roomStatus: String = "Connected"
    @State private var selfUpdatedStatus: Bool = false
    @State private var connectionStatusHandle: DatabaseHandle?
    
    // 対戦関連の状態
    @State private var myRole: String = ""  // "creator" or "invited"
    @State private var opponentScore: Int = 0
    @State private var gameStateHandle: DatabaseHandle?
    @State private var opponentField: [[Int]] = Array(repeating: Array(repeating: 0, count: 10), count: 20)
    @State private var showOpponentField: Bool = true
    @State private var pendingGarbageLines: Int = 0
    @State private var opponentPendingLines: Int = 0
    
    // スコアアニメーション関連の状態管理
    @State private var animate = false
    @State private var previousScore: Int = 0  // 直前のスコアを記録
    
    // スクロールビュー関連
    @State private var scrollOffset: CGFloat = 0
    @Namespace private var scrollSpace
    
    // 勝利関連の状態変数
    @State private var showWinView: Bool = false
    @State private var creatorWins: Int = 0
    @State private var invitedWins: Int = 0
    @State private var gameResetHandle: DatabaseHandle?
    @State private var gameStateInitialized: Bool = false  // ★バグ修正: ゲーム状態初期化フラグ
    
    @Environment(\.dismiss) private var dismiss
    
    // 心拍数に応じた1拍あたりの間隔（秒）
    var beatInterval: Double {
        60.0 / Double(max(myHeartRate, 1))
    }
    
    // ジェスチャの最小スワイプ距離
    private let minSwipeDistance: CGFloat = 30.0
    
    // 自分の勝利数を取得
    private var myWins: Int {
        myRole == "creator" ? creatorWins : invitedWins
    }
    
    // 相手の勝利数を取得
    private var opponentWins: Int {
        myRole == "creator" ? invitedWins : creatorWins
    }
    
    var body: some View {
        ZStack {
            // 背景色を黒に設定
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 15) {
                    // 心拍数表示エリア
                    HStack(spacing: 20) {
                        // 自分の心拍数
                        ImprovedHeartRateCard(
                            name: "あなた",
                            heartRate: myHeartRate,
                            isLeading: myHeartRate >= opponentHeartRate,
                            beatInterval: beatInterval
                        )
                        
                        // VS表示
                        Text("VS")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 0)
                        
                        // 相手の心拍数
                        ImprovedHeartRateCard(
                            name: opponentName,
                            heartRate: opponentHeartRate,
                            isLeading: opponentHeartRate > myHeartRate,
                            beatInterval: 60.0 / Double(max(opponentHeartRate, 1))
                        )
                    }
                    .padding(.vertical, 10)
                    
                    // 勝利数表示
                    WinsCounterView(
                        creatorName: myRole == "creator" ? "あなた" : opponentName,
                        invitedName: myRole == "invited" ? "あなた" : opponentName,
                        creatorWins: creatorWins,
                        invitedWins: invitedWins,
                        myRole: myRole
                    )
                    .padding(.horizontal)
                    
                    // スコア表示
                    HStack(spacing: 30) {
                        // 自分のスコア
                        ScoreView(title: "あなた", score: scene.score, animate: animate)
                        
                        // 相手のスコア
                        ScoreView(title: opponentName, score: opponentScore, animate: false)
                    }
                    
                    // ゲーム画面エリア
                    HStack(spacing: 15) {
                        // 自分のゲーム画面
                        ZStack {
                            // ゲーム背景
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("121212"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.cyan.opacity(0.7),
                                                    Color.purple.opacity(0.5)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: Color.cyan.opacity(0.3), radius: 10, x: 0, y: 0)
                            
                            // お邪魔ブロック警告表示
                            if pendingGarbageLines > 0 {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text("お邪魔ブロック: \(pendingGarbageLines)行")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.red)
                                            .padding(6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.black.opacity(0.7))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(Color.red, lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .padding(.bottom, 8)
                                    Spacer().frame(height: 30)
                                }
                            }
                            
                            // ゲーム画面
                            SpriteView(scene: scene)
                                .frame(width: 250, height: 450)
                                .cornerRadius(8)
                                .padding(2)
                        }
                        .frame(width: 270, height: 470)
                        // ジェスチャを追加
                        .gesture(swipeGesture)
                        .gesture(tapGesture)
                        .gesture(longPressGesture)
                        
                        // 相手のゲーム画面（ミニサイズ）
                        if showOpponentField {
                            VStack {
                                Text(opponentName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color("121212"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.orange.opacity(0.5),
                                                            Color.red.opacity(0.3)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                    
                                    // 相手のフィールドを表示
                                    OpponentFieldView(
                                        field: opponentField,
                                        pendingLines: opponentPendingLines
                                    )
                                    .frame(width: 90, height: 180)
                                    .padding(2)
                                }
                                .frame(width: 100, height: 200)
                                
                                if opponentPendingLines > 0 {
                                    Text("攻撃中: \(opponentPendingLines)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                        .padding(4)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.5))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.orange, lineWidth: 0.5)
                                                )
                                        )
                                }
                            }
                        }
                    }
                    
                    // 操作用ボタン
                    HStack(spacing: 12) {
                        // 左移動ボタン
                        ControlButton(systemName: "arrow.left", color: .indigo) {
                            scene.movePieceLeft()
                        }
                        
                        // ソフトドロップボタン
                        ControlButton(systemName: "arrow.down", color: .purple) {
                            scene.movePieceDown()
                        }
                        
                        // 右移動ボタン
                        ControlButton(systemName: "arrow.right", color: .indigo) {
                            scene.movePieceRight()
                        }
                        
                        // 回転ボタン
                        ControlButton(systemName: "arrow.clockwise", color: .cyan) {
                            scene.rotatePiece()
                        }
                        
                        // ハードドロップボタン
                        ControlButton(systemName: "arrow.down.to.line", color: .cyan) {
                            scene.hardDropPiece()
                        }
                    }
                    .padding(.horizontal)
                    
                    // 心拍数差分表示
                    VStack(spacing: 4) {
                        Text("心拍数の差")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        let heartRateDifference = abs(myHeartRate - opponentHeartRate)
                        Text("\(heartRateDifference)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(heartRateDifference > 10 ? .orange : .green)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 5)
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
                        
                        let leadingPlayer = myHeartRate > opponentHeartRate ? "あなた" : opponentName
                        if heartRateDifference > 0 {
                            Text("リード: \(leadingPlayer)")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(
                                    leadingPlayer == "あなた" ? .green : .orange
                                )
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("222222"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // 最下部の余白（安全領域を確保するため）
                    Color.clear.frame(height: 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                // スクロール位置を検出するためのコード
                .background(GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .named("scrollView")).minY
                    )
                })
                // コンテンツが小さい画面でも下までスクロールできるようにする
                .frame(minHeight: UIScreen.main.bounds.height)
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            .opacity(scene.isGameOver || showWinView ? 0.3 : 1.0)
            
            // ゲームオーバー表示
            if scene.isGameOver {
                GameOverView(onRestart: {
                    scene.startGame()
                    resetMultiplayerGame()
                })
            }
            
            // 勝利表示
            if showWinView {
                WinView(onRestart: {
                    scene.startGame()
                    resetMultiplayerGame()
                    showWinView = false
                })
            }
        }
        .navigationBarBackButtonHidden(true)
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
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.startGame()
            
            // 自分と相手の心拍数を監視する
            setupHeartRateObservers()
            
            // ルームのステータス監視を設定
            setupConnectionStatusObserver()
            
            // 接続状態を「Connected」に更新
            updateConnectionStatus(to: "Connected")
            
            // マルチプレイヤーモードをセットアップ
            setupMultiplayer()
            
            // ★バグ修正: 勝利数の整合性チェック
            ensureWinsConsistency()
        }
        .onChange(of: scene.score) { newScore, _ in
            if newScore != previousScore {
                animateScoreChange()
                // スコア更新をFirebaseに送信
                updateMultiplayerScore(score: newScore)
            }
        }
        .onDisappear {
            // 監視を解除
            removeAllObservers()
            
            // 自分で更新フラグが立っていなければ更新する
            if !selfUpdatedStatus {
                updateConnectionStatus(to: "cancelled")
            }
        }
        .alert("接続が切れました", isPresented: $showDisconnectionAlert) {
            Button("OK", role: .cancel) {
                dismiss() // ビューを閉じる
            }
        } message: {
            Text("相手との接続が切れました。ホーム画面に戻ります。")
        }
        // セーフエリア外までコンテンツを拡張
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // マルチプレイヤーセットアップ
    private func setupMultiplayer() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // 自分がcreatorかinvitedかを判断
        let ref = Database.database().reference()
        ref.child("GameRooms").child(roomID).observeSingleEvent(of: .value) { snapshot, _ in
            guard let roomData = snapshot.value as? [String: Any] else { return }
            
            let creatorUID = roomData["creatorUID"] as? String ?? ""
            self.myRole = (currentUser.uid == creatorUID) ? "creator" : "invited"
            
            // 勝利数の初期確認
            if let creatorWins = roomData["creatorWins"] as? Int {
                self.creatorWins = creatorWins
            }
            if let invitedWins = roomData["invitedWins"] as? Int {
                self.invitedWins = invitedWins
            }
            
            // ゲーム状態がなければ初期化
            self.checkAndInitializeGameState()
            
            // ★バグ修正: ゲームリセット状態の監視を先に設定
            self.observeGameReset()
            
            // ゲーム状態の監視を開始
            self.observeGameState()
            
            // 相手のアクションを監視
            self.observeOpponentActions()
            
            // sceneにマルチプレイヤー情報を設定
            self.configureGameSceneForMultiplayer()
            
            // ★バグ修正: 勝利数監視を追加
            self.observeWinsUpdate()
        }
    }
    
    // ★バグ修正: ゲームリセット状態を監視する関数を修正
    private func observeGameReset() {
        let ref = Database.database().reference()
        let resetRef = ref.child("GameRooms").child(roomID).child("gameReset")
        
        gameResetHandle = resetRef.observe(.value) { snapshot, _ in
            guard let resetData = snapshot.value as? [String: Any],
                  let resetFlag = resetData["resetFlag"] as? Bool,
                  resetFlag == true,
                  let initiator = resetData["initiator"] as? String else { return }
            
            // ★バグ修正: 自分が開始したリセットかどうかに関わらず、必ずゲームをリセット
            DispatchQueue.main.async {
                // ゲームをリセット
                self.scene.startGame()
                
                // 勝利表示がある場合は閉じる
                self.showWinView = false
                
                // Firebase上のresetFlagをfalseに戻す（連続でのリセット誤検出を防止）
                if initiator != self.myRole {
                    // 少し遅延を入れて、互いのリセットが干渉しないようにする
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        resetRef.updateChildValues(["resetFlag": false])
                    }
                }
            }
        }
    }
    
    // ゲームシーンを対戦モード用に設定
    private func configureGameSceneForMultiplayer() {
        // GameSceneクラスにコールバックを設定
        scene.onLinesCleared = { lines in
            guard lines > 0 else { return }
            
            // ラインを消した数に応じてお邪魔ブロックを送る
            self.sendGarbageLines(lineCount: lines)
        }
        
        scene.onGameOver = {
            // ゲームオーバー状態をFirebaseに通知
            self.reportGameOver()
        }
        
        scene.onFieldUpdated = { field in
            // 自分のフィールド状態を更新
            self.updateField(field: field)
        }
    }

    // ゲーム状態がなければ初期化
    private func checkAndInitializeGameState() {
        let ref = Database.database().reference()
        let gameStateRef = ref.child("GameRooms").child(roomID).child("tetrisGameState")
        
        gameStateRef.observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() || snapshot.value is NSNull {
                // 初期ゲーム状態をFirebaseに送信
                let initialState: [String: Any] = [
                    "creatorScore": 0,
                    "invitedScore": 0,
                    "creatorField": Array(repeating: Array(repeating: 0, count: 10), count: 20),
                    "invitedField": Array(repeating: Array(repeating: 0, count: 10), count: 20),
                    "creatorPendingLines": 0,
                    "invitedPendingLines": 0,
                    "gameStatus": "playing",
                    "timestamp": ServerValue.timestamp()
                ]
                
                gameStateRef.setValue(initialState)
                
                // 勝利数を初期化（存在しない場合のみ）
                ref.child("GameRooms").child(roomID).child("creatorWins").observeSingleEvent(of: .value) { snapshot in
                    if !snapshot.exists() || snapshot.value is NSNull {
                        ref.child("GameRooms").child(roomID).child("creatorWins").setValue(0)
                    }
                }
                
                ref.child("GameRooms").child(roomID).child("invitedWins").observeSingleEvent(of: .value) { snapshot in
                    if !snapshot.exists() || snapshot.value is NSNull {
                        ref.child("GameRooms").child(roomID).child("invitedWins").setValue(0)
                    }
                }
            }
        }
    }
    
    // ★バグ修正: ゲーム状態の監視を修正
    private func observeGameState() {
        let ref = Database.database().reference()
        let gameStateRef = ref.child("GameRooms").child(roomID).child("tetrisGameState")
        
        gameStateHandle = gameStateRef.observe(.value) { snapshot, _ in
            guard let gameData = snapshot.value as? [String: Any] else { return }
            
            DispatchQueue.main.async {
                // ★バグ修正: 初回読み込み時のフラグを設定
                if !self.gameStateInitialized {
                    self.gameStateInitialized = true
                    
                    // ★バグ修正: ゲーム状態が「gameOver」でなければ勝利表示をリセット
                    if let gameStatus = gameData["gameStatus"] as? String,
                       gameStatus != "gameOver" {
                        self.showWinView = false
                    }
                }
                
                // 相手のスコアを更新
                if self.myRole == "creator" {
                    if let invitedScore = gameData["invitedScore"] as? Int {
                        self.opponentScore = invitedScore
                    }
                } else {
                    if let creatorScore = gameData["creatorScore"] as? Int {
                        self.opponentScore = creatorScore
                    }
                }
                
                // 相手のフィールドを更新
                let opponentFieldKey = self.myRole == "creator" ? "invitedField" : "creatorField"
                if let field = gameData[opponentFieldKey] as? [[Int]] {
                    self.opponentField = field
                }
                
                // お邪魔ブロック状況を更新
                let myPendingKey = self.myRole == "creator" ? "creatorPendingLines" : "invitedPendingLines"
                let opponentPendingKey = self.myRole == "creator" ? "invitedPendingLines" : "creatorPendingLines"
                
                if let pending = gameData[myPendingKey] as? Int {
                    self.pendingGarbageLines = pending
                    
                    // シーンにお邪魔ブロック情報を通知
                    if pending > 0 {
                        self.scene.receiveGarbageLines(count: pending)
                        
                        // 処理済みとしてカウンターをリセット
                        self.resetPendingLines()
                    }
                }
                
                if let opponentPending = gameData[opponentPendingKey] as? Int {
                    self.opponentPendingLines = opponentPending
                }
                
                // ゲームステータスを確認
                if let gameStatus = gameData["gameStatus"] as? String,
                   gameStatus == "gameOver",
                   let loser = gameData["loser"] as? String {
                    
                    // ★バグ修正: タイムスタンプを確認して最近のゲームオーバーだけを処理
                    if let timestamp = gameData["timestamp"] as? TimeInterval {
                        let currentTime = Date().timeIntervalSince1970 * 1000
                        let timeDifference = currentTime - timestamp
                        
                        // 60秒以内のゲームオーバーイベントのみ処理
                        if timeDifference < 60000 {
                            // 相手がゲームオーバーになった場合、勝利表示を行う
                            if loser != self.myRole && !self.showWinView {
                                self.showWinView = true
                                
                                // 勝利数をインクリメント
                                self.incrementWins()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ★バグ修正: 勝利数を増やす関数を修正
    private func incrementWins() {
        let ref = Database.database().reference()
        let winKey = myRole == "creator" ? "creatorWins" : "invitedWins"
        
        // 勝利数更新前に現在の値を再度確認
        ref.child("GameRooms").child(roomID).child(winKey).observeSingleEvent(of: .value) { snapshot, _ in
            var currentWins = 0
            if let value = snapshot.value as? Int {
                currentWins = value
            }
            
            // 最新の値に1を足す
            let newWins = currentWins + 1
            
            // 更新
            ref.child("GameRooms").child(roomID).child(winKey).setValue(newWins) { error, _ in
                if error == nil {
                    // UI更新
                    DispatchQueue.main.async {
                        if self.myRole == "creator" {
                            self.creatorWins = newWins
                        } else {
                            self.invitedWins = newWins
                        }
                    }
                    
                    // 勝利数の変更を通知
                    ref.child("GameRooms").child(roomID).child("winsUpdated").setValue(true)
                }
            }
        }
    }
    
    // ★バグ修正: 勝利数を監視する関数を追加
    private func observeWinsUpdate() {
        let ref = Database.database().reference()
        
        // creatorWinsとinvitedWinsの監視を設定
        ref.child("GameRooms").child(roomID).child("creatorWins").observe(.value) { snapshot, _ in
            if let wins = snapshot.value as? Int {
                DispatchQueue.main.async {
                    self.creatorWins = wins
                }
            }
        }
        
        ref.child("GameRooms").child(roomID).child("invitedWins").observe(.value) { snapshot, _ in
            if let wins = snapshot.value as? Int {
                DispatchQueue.main.async {
                    self.invitedWins = wins
                }
            }
        }
    }
    
    // ★バグ修正: 勝利数の整合性を確認する関数を追加
    private func ensureWinsConsistency() {
        // アプリ起動時やネットワーク再接続時に勝利数の整合性を確認
        let ref = Database.database().reference()
        
        ref.child("GameRooms").child(roomID).observeSingleEvent(of: .value) { snapshot, _ in
            guard let roomData = snapshot.value as? [String: Any] else { return }
            
            // 勝利数の取得
            let creatorWinsDB = roomData["creatorWins"] as? Int ?? 0
            let invitedWinsDB = roomData["invitedWins"] as? Int ?? 0
            
            // ローカル状態と差異があれば更新
            DispatchQueue.main.async {
                if self.creatorWins != creatorWinsDB {
                    self.creatorWins = creatorWinsDB
                }
                
                if self.invitedWins != invitedWinsDB {
                    self.invitedWins = invitedWinsDB
                }
            }
        }
    }
    
    // 相手のアクションを監視
    private func observeOpponentActions() {
        let ref = Database.database().reference()
        let opponentRole = myRole == "creator" ? "invited" : "creator"
        let actionsRef = ref.child("GameRooms").child(roomID).child("tetrisActions").child(opponentRole)
        
        actionsRef.observe(.childAdded) { snapshot, _ in
            guard let actionData = snapshot.value as? [String: Any] else { return }
            
            // アクションタイプに基づいて処理
            if let actionType = actionData["type"] as? String {
                switch actionType {
                case "clearedLines":
                    // 相手がラインを消した場合、お邪魔ブロックを受け取る
                    if let linesCount = actionData["count"] as? Int {
                        self.receiveGarbageLines(count: linesCount)
                    }
                default:
                    break
                }
            }
            
            // 処理済みのアクションを削除
            snapshot.ref.removeValue()
        }
    }
    
    // お邪魔ブロックカウンターをリセット
    private func resetPendingLines() {
        let ref = Database.database().reference()
        let pendingKey = myRole == "creator" ? "creatorPendingLines" : "invitedPendingLines"
        
        ref.child("GameRooms").child(roomID)
           .child("tetrisGameState")
           .child(pendingKey)
           .setValue(0)
    }
    
    // お邪魔ラインを受け取る処理
    private func receiveGarbageLines(count: Int) {
        let ref = Database.database().reference()
        let pendingKey = myRole == "creator" ? "creatorPendingLines" : "invitedPendingLines"
        
        // トランザクションでカウンターを更新
        ref.child("GameRooms").child(roomID).child("tetrisGameState").child(pendingKey)
            .runTransactionBlock { currentData in
                var currentCount = 0
                if let value = currentData.value as? Int {
                    currentCount = value
                }
                
                currentData.value = currentCount + count
                return TransactionResult.success(withValue: currentData)
            }
    }
    
    // ラインを消したときお邪魔ブロックを送る
    private func sendGarbageLines(lineCount: Int) {
        guard lineCount > 0 else { return }
        
        // 送信するお邪魔ライン数（ルールに基づいて計算）
        var garbageLines = 0
        switch lineCount {
        case 1: garbageLines = 0  // 1ライン消しでは送らない
        case 2: garbageLines = 1  // 2ライン消しで1ライン
        case 3: garbageLines = 2  // 3ライン消しで2ライン
        case 4: garbageLines = 4  // 4ライン消し（テトリス）で4ライン
        default: break
        }
        
        if garbageLines > 0 {
            let ref = Database.database().reference()
            let actionsRef = ref.child("GameRooms").child(roomID).child("tetrisActions").child(myRole)
            
            let actionData: [String: Any] = [
                "type": "clearedLines",
                "count": garbageLines,
                "timestamp": ServerValue.timestamp()
            ]
            
            // アクションをFirebaseに記録
            actionsRef.childByAutoId().setValue(actionData)
            
            // 相手へのお邪魔ブロックカウンターを更新
            let opponentPendingKey = myRole == "creator" ? "invitedPendingLines" : "creatorPendingLines"
            
            ref.child("GameRooms").child(roomID).child("tetrisGameState").child(opponentPendingKey)
                .runTransactionBlock { currentData in
                    var currentCount = 0
                    if let value = currentData.value as? Int {
                        currentCount = value
                    }
                    
                    currentData.value = currentCount + garbageLines
                    return TransactionResult.success(withValue: currentData)
                }
        }
    }
    
    // 相手へゲームリセットを通知する関数
    private func notifyGameReset() {
        let ref = Database.database().reference()
        
        let resetData: [String: Any] = [
            "resetFlag": true,
            "initiator": myRole,
            "timestamp": ServerValue.timestamp()
        ]
        
        ref.child("GameRooms").child(roomID).child("gameReset").setValue(resetData)
    }
    
    // UIColorを整数に変換
    func updateField(field: [[UIColor?]]) {
        let ref = Database.database().reference()
        let fieldKey = myRole == "creator" ? "creatorField" : "invitedField"
        
        // UIColorを整数に変換
        var intField: [[Int]] = Array(repeating: Array(repeating: 0, count: field[0].count), count: field.count)
        
        for row in 0..<field.count {
            for col in 0..<field[row].count {
                if let color = field[row][col] {
                    intField[row][col] = color.toInt()
                } else {
                    intField[row][col] = 0  // 空セル
                }
            }
        }
        
        // 整数配列をFirebaseに送信
        ref.child("GameRooms").child(roomID).child("tetrisGameState").child(fieldKey)
            .setValue(intField)
    }
    
    // スコアをFirebaseに更新
    private func updateMultiplayerScore(score: Int) {
        let ref = Database.database().reference()
        let scoreKey = myRole == "creator" ? "creatorScore" : "invitedScore"
        
        ref.child("GameRooms").child(roomID).child("tetrisGameState").child(scoreKey)
            .setValue(score)
    }
    
    // ゲームオーバー状態をFirebaseに通知
    private func reportGameOver() {
        let ref = Database.database().reference()
        
        let gameOverData = [
            "gameStatus": "gameOver",
            "loser": myRole,  // 自分がゲームオーバーになった
            "timestamp": ServerValue.timestamp()
        ] as [String: Any]
        
        ref.child("GameRooms").child(roomID).child("tetrisGameState")
            .updateChildValues(gameOverData)
    }
    
    // マルチプレイヤーゲームをリセット
    private func resetMultiplayerGame() {
        let ref = Database.database().reference()
        
        // ゲーム状態をリセット（どちらのroleでも実行可能に）
        let resetData: [String: Any] = [
            "creatorScore": 0,
            "invitedScore": 0,
            "creatorField": Array(repeating: Array(repeating: 0, count: 10), count: 20),
            "invitedField": Array(repeating: Array(repeating: 0, count: 10), count: 20),
            "creatorPendingLines": 0,
            "invitedPendingLines": 0,
            "gameStatus": "playing",
            "timestamp": ServerValue.timestamp()
        ]
        
        ref.child("GameRooms").child(roomID).child("tetrisGameState")
            .setValue(resetData)
        
        // 相手に通知
        notifyGameReset()
    }
    
    // ★バグ修正: 接続状態を更新する関数を修正
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
            if error == nil {
                if status == "Connected" {
                    // 接続時は勝利数をリセット
                    self.resetWinsCount {
                        completion?()
                    }
                } else if (status == "cancelled" || status == "waiting") {
                    // 退室時にゲーム状態をリセット
                    let resetData: [String: Any] = [
                        "creatorScore": 0,
                        "invitedScore": 0,
                        "creatorField": Array(repeating: Array(repeating: 0, count: 10), count: 20),
                        "invitedField": Array(repeating: Array(repeating: 0, count: 10), count: 20),
                        "creatorPendingLines": 0,
                        "invitedPendingLines": 0,
                        "gameStatus": "waiting",  // 「playing」から「waiting」へ
                        "timestamp": ServerValue.timestamp()
                    ]
                    
                    ref.child("GameRooms").child(roomID).child("tetrisGameState").setValue(resetData) { (error, _) in
                        // gameResetフラグもリセット
                        ref.child("GameRooms").child(roomID).child("gameReset").setValue(["resetFlag": false, "initiator": "system"])
                        completion?()
                    }
                } else {
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }
    
    private func resetWinsCount(completion: (() -> Void)? = nil) {
        let ref = Database.database().reference()
        
        // 勝利数をリセット
        let winsResetData: [String: Any] = [
            "creatorWins": 0,
            "invitedWins": 0
        ]
        
        ref.child("GameRooms").child(roomID).updateChildValues(winsResetData) { (error, _) in
            if error == nil {
                // ローカルの勝利数も更新
                DispatchQueue.main.async {
                    self.creatorWins = 0
                    self.invitedWins = 0
                }
            }
            completion?()
        }
    }
    
    // スコアが変わったときにアニメーションを実行
    private func animateScoreChange() {
        animate = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animate = false
        }
        previousScore = scene.score
    }
    
    // 心拍数監視の設定
    private func setupHeartRateObservers() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUID = currentUser.uid
        
        let ref = Database.database().reference()
        
        // 自分の心拍数を監視
        myHeartRateHandle = ref.child("Userdata").child(currentUID)
            .child("Heartbeat").child("Watch1").child("HeartRate")
            .observe(.value) { snapshot, _ in
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
        
        // 相手のUIDが明示的に渡されている場合はそれを使用
        if let opponentUID = userUID {
            opponentHeartRateHandle = ref.child("Userdata").child(opponentUID)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .observe(.value) { snapshot, _ in
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
        } else {
            // UIDが渡されていない場合は、roomIDから取得
            ref.child("GameRooms").child(roomID).observeSingleEvent(of: .value) { snapshot, _ in
                if let roomData = snapshot.value as? [String: Any] {
                    // 自分がcreatorかinvitedかを判断し、相手のUIDを取得
                    let creatorUID = roomData["creatorUID"] as? String ?? ""
                    let invitedUID = roomData["invitedUID"] as? String ?? ""
                    
                    let opponentUID = (currentUID == creatorUID) ? invitedUID : creatorUID
                    
                    // 相手の心拍数を監視
                    self.opponentHeartRateHandle = ref.child("Userdata").child(opponentUID)
                        .child("Heartbeat").child("Watch1").child("HeartRate")
                        .observe(.value) { snapshot, _ in
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
            }
        }
    }
    
    // 接続状態を監視する関数
    private func setupConnectionStatusObserver() {
        let ref = Database.database().reference()
        
        connectionStatusHandle = ref.child("GameRooms").child(roomID).child("status")
            .observe(.value) { snapshot, _ in
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
    
    // ★バグ修正: 全ての監視を解除する関数を修正
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
            ref.removeObserver(withHandle: handle)
        }
        
        // 接続状態の監視を解除
        if let handle = connectionStatusHandle {
            ref.child("GameRooms").child(roomID).child("status")
                .removeObserver(withHandle: handle)
        }
        
        // ゲーム状態の監視を解除
        if let handle = gameStateHandle {
            ref.child("GameRooms").child(roomID).child("tetrisGameState")
                .removeObserver(withHandle: handle)
        }
        
        // ゲームリセット監視の解除
        if let handle = gameResetHandle {
            ref.child("GameRooms").child(roomID).child("gameReset")
                .removeObserver(withHandle: handle)
        }
        
        // ★バグ修正: 勝利数監視の解除
        ref.child("GameRooms").child(roomID).child("creatorWins").removeAllObservers()
        ref.child("GameRooms").child(roomID).child("invitedWins").removeAllObservers()
    }
    
    // スワイプジェスチャ（左右下移動）
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: minSwipeDistance)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                if abs(horizontal) > abs(vertical) {
                    // 横方向スワイプ
                    horizontal > 0 ? scene.movePieceRight() : scene.movePieceLeft()
                } else {
                    // 縦方向スワイプ（下方向のみ）
                    if vertical > 0 {
                        scene.movePieceDown()
                    }
                }
            }
    }
    
    // タップジェスチャ（回転）
    private var tapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded {
                scene.rotatePiece()
            }
    }
    
    // 長押しジェスチャ（ハードドロップ）
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in
                scene.hardDropPiece()
            }
    }
}

// 相手のテトリスフィールド表示用ビュー
struct OpponentFieldView: View {
    let field: [[Int]]
    let pendingLines: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // 配列を逆順（下から上）に描画することで、
            // 正しい向きで表示されるようにする
            ForEach((0..<field.count).reversed(), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<field[row].count, id: \.self) { col in
                        Rectangle()
                            .fill(getColorForCell(field[row][col]))
                            .frame(width: 9, height: 9)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
        .overlay(
            VStack {
                if pendingLines > 0 {
                    Text("\(pendingLines)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                }
            }
        )
    }
    
    // セルの状態に応じた色を返す
    private func getColorForCell(_ value: Int) -> Color {
        switch value {
        case 0: return Color.clear
        case 1: return Color.red
        case 2: return Color.blue
        case 3: return Color.green
        case 4: return Color.yellow
        case 5: return Color.purple
        case 6: return Color.orange
        case 7: return Color.cyan
        case 9: return Color.gray  // お邪魔ブロック
        default: return Color.white
        }
    }
}

// スコア表示コンポーネント
struct ScoreView: View {
    var title: String
    var score: Int
    var animate: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Text("\(score)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(animate ? 1.4 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animate)
                .frame(height: 50)
                .padding(.bottom, 4)
                .overlay(
                    // スコアの下に光るライン
                    Rectangle()
                        .frame(height: 2)
                        .offset(y: 25)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.clear, .cyan, .purple, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("161616"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
        )
    }
}

// ゲームオーバー表示コンポーネント
struct GameOverView: View {
    var onRestart: () -> Void
    @State private var showAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            // ゲームオーバーテキスト
            Text("GAME OVER")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .cyan, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.bottom, 8)
                .opacity(showAnimation ? 1 : 0)
                .offset(y: showAnimation ? 0 : -20)
            
            // 再開ボタン
            Button(action: onRestart) {
                Text("NEW GAME")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .opacity(showAnimation ? 1 : 0)
            .scaleEffect(showAnimation ? 1 : 0.8)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("121212").opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.5)) {
                showAnimation = true
            }
        }
    }
}

// 勝利表示用のビュー
struct WinView: View {
    var onRestart: () -> Void
    @State private var showAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 勝利テキスト
            Text("YOU WIN!")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.bottom, 16)
                .opacity(showAnimation ? 1 : 0)
                .offset(y: showAnimation ? 0 : -30)
                .shadow(color: .orange.opacity(0.8), radius: 15, x: 0, y: 0)
            
            // 輝く星のエフェクト
            HStack(spacing: 20) {
                ForEach(0..<3) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.8), radius: 10, x: 0, y: 0)
                        .offset(y: showAnimation ? 0 : 50)
                        .opacity(showAnimation ? 1 : 0)
                        .scaleEffect(showAnimation ? 1 : 0.3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(i) * 0.1), value: showAnimation)
                }
            }
            .padding(.bottom, 24)
            
            // 再開ボタン
            Button(action: onRestart) {
                Text("NEW GAME")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 36)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(30)
                    .shadow(color: Color.orange.opacity(0.7), radius: 10, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            }
            .opacity(showAnimation ? 1 : 0)
            .scaleEffect(showAnimation ? 1 : 0.8)
        }
        .padding(50)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("121212").opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.yellow.opacity(0.7),
                                    Color.orange.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.orange.opacity(0.3), radius: 30, x: 0, y: 10)
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showAnimation = true
            }
        }
    }
}

// 勝利数表示用のコンポーネント
struct WinsCounterView: View {
    var creatorName: String
    var invitedName: String
    var creatorWins: Int
    var invitedWins: Int
    var myRole: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text("勝利数")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(spacing: 30) {
                // クリエーターの勝利数
                VStack(spacing: 4) {
                    Text(creatorName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(myRole == "creator" ? .green : .gray)
                        .lineLimit(1)
                    
                    Text("\(creatorWins)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(myRole == "creator" ? .green : .white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("1E1E1E"))
                        .shadow(color: (myRole == "creator" ? Color.green : Color.white).opacity(0.2), radius: 5, x: 0, y: 2)
                )
                
                Text("vs")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.gray)
                
                // 招待者の勝利数
                VStack(spacing: 4) {
                    Text(invitedName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(myRole == "invited" ? .green : .gray)
                        .lineLimit(1)
                    
                    Text("\(invitedWins)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(myRole == "invited" ? .green : .white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("1E1E1E"))
                        .shadow(color: (myRole == "invited" ? Color.green : Color.white).opacity(0.2), radius: 5, x: 0, y: 2)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("161616"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// カスタムボタンコンポーネント
struct ControlButton: View {
    let systemName: String
    let color: Color
    let action: () -> Void
    
    // ボタンのプレス状態
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // 触覚フィードバック
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    ZStack {
                        // ベース
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        color.opacity(0.7),
                                        color.opacity(0.5)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // ボタン押下時のエフェクト
                        if isPressed {
                            Circle()
                                .fill(color.opacity(0.3))
                                .scaleEffect(1.5)
                                .opacity(0.4)
                        }
                        
                        // ボタンの縁取り
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(color: color.opacity(0.5), radius: 8, x: 0, y: 4)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .pressEvents {
            // ボタン押下時
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onRelease: {
            // ボタンリリース時
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
        }
    }
}

// プレスジェスチャー検出用の拡張
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}

// スクロールオフセットの優先度キー
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TetrisView_Previews: PreviewProvider {
    static var previews: some View {
        TetrisView(roomID: "preview_room", opponentName: "相手プレイヤー")
    }
}
