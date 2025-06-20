import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct OthelloView: View {
    var roomID: String
    var opponentName: String
    var userUID: String? // 相手のUID（明示的に受け取る）
    
    @State private var myHeartRate: Int = 0
    @State private var opponentHeartRate: Int = 0
    
    // 心拍数監視のハンドル
    @State private var myHeartRateHandle: DatabaseHandle?
    @State private var opponentHeartRateHandle: DatabaseHandle?
    @State private var connectionStatusHandle: DatabaseHandle?
    
    // 接続状態アラート用の状態変数
    @State private var showDisconnectionAlert: Bool = false
    @State private var roomStatus: String = "Connected"
    @State private var selfUpdatedStatus: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    // ハート・アニメーション用の状態変数
    @State private var heartScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.5
    @State private var heartOpacity: Double = 1.0
    @State private var rippleOpacity: Double = 1.0
    @State private var isAnimating: Bool = false
    
    // 心拍数に応じた1拍あたりの間隔（秒）
    var beatInterval: Double {
        60.0 / Double(max(myHeartRate, 1))
    }
    
    // 心拍数の差を視覚的に表示
    private var heartRateDifference: Int {
        abs(myHeartRate - opponentHeartRate)
    }
    
    private var leadingPlayer: String {
        if myHeartRate == opponentHeartRate {
            return "引き分け"
        } else if myHeartRate > opponentHeartRate {
            return "あなた"
        } else {
            return opponentName
        }
    }
    
    // オセロの盤面サイズ
    private let boardSize = 8
    
    // オセロの盤面状態（0: 空, 1: 黒, 2: 白）
    @State private var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 8), count: 8)
    
    // 現在のプレイヤー（1: 黒, 2: 白）
    @State private var currentPlayer: Int = 1
    
    // 初期化時に盤面を設定
    private func initializeBoard() {
        // 空の盤面を作成
        board = Array(repeating: Array(repeating: 0, count: boardSize), count: boardSize)
        
        // 初期配置（中央の4マス）
        let center = boardSize / 2
        board[center-1][center-1] = 2 // 白
        board[center][center] = 2 // 白
        board[center-1][center] = 1 // 黒
        board[center][center-1] = 1 // 黒
        
        // 黒（先手）から開始
        currentPlayer = 1
    }
    
    var body: some View {
        ZStack {
            // 背景色を黒に設定
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    
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
                    
                    // 心拍数差分表示
                    VStack(spacing: 4) {
                        Text("心拍数の差")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
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
                    }
                    
                    // オセロ盤面
                    VStack(spacing: 0) {
                        ForEach(0..<boardSize, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<boardSize, id: \.self) { column in
                                    ImprovedCellView(
                                        cellState: board[row][column],
                                        onTap: {
                                            // タップ時の処理（実際の駒を置く処理はここに実装）
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "054D00"))
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                    
                    // 現在のプレイヤー表示
                    HStack(spacing: 30) {
                        // 黒の駒数
                        VStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .shadow(color: .white.opacity(0.3), radius: 4)
                            
                            Text("\(countPieces(player: 1))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // 現在の手番表示
                        VStack {
                            Text("現在の手番")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Circle()
                                .fill(currentPlayer == 1 ? Color.black : Color.white)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .shadow(color: .white.opacity(0.5), radius: 5)
                        }
                        
                        // 白の駒数
                        VStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .shadow(color: .white.opacity(0.3), radius: 4)
                            
                            Text("\(countPieces(player: 2))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "222222"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.bottom)
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
            // 自分と相手の心拍数を監視する
            setupHeartRateObservers()
            
            // ルームのステータス監視を設定
            setupConnectionStatusObserver()
            
            // 接続状態を「Connected」に更新
            updateConnectionStatus(to: "Connected")
            
            // オセロ盤面の初期化
            initializeBoard()
            
            // アニメーション開始
            isAnimating = true
        }
        .onDisappear {
            // 監視を解除
            removeAllObservers()
            
            // アニメーション停止
            isAnimating = false
            
            // 自分で更新フラグが立っていなければ更新する
            if !selfUpdatedStatus {
                updateConnectionStatus(to: "cancelled")
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
    
    // 駒の数をカウント
    private func countPieces(player: Int) -> Int {
        var count = 0
        for row in board {
            for cell in row {
                if cell == player {
                    count += 1
                }
            }
        }
        return count
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
        
        // 相手のUIDが明示的に渡されている場合はそれを使用
        if let opponentUID = userUID {
            opponentHeartRateHandle = ref.child("Userdata").child(opponentUID)
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
        } else {
            // UIDが渡されていない場合は、roomIDから取得（以前の実装）
            ref.child("GameRooms").child(roomID).observeSingleEvent(of: .value) { snapshot in
                if let roomData = snapshot.value as? [String: Any] {
                    // 自分がcreatorかinvitedかを判断し、相手のUIDを取得
                    let creatorUID = roomData["creatorUID"] as? String ?? ""
                    let invitedUID = roomData["invitedUID"] as? String ?? ""
                    
                    let opponentUID = (currentUID == creatorUID) ? invitedUID : creatorUID
                    
                    // 相手の心拍数を監視
                    self.opponentHeartRateHandle = ref.child("Userdata").child(opponentUID)
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
            // 相手のUID不明のため、直接参照できない。
            // Firebaseの removeObserver(withHandle:) メソッドを使用
            ref.removeObserver(withHandle: handle)
        }
        
        // 接続状態の監視を解除
        if let handle = connectionStatusHandle {
            ref.child("GameRooms").child(roomID).child("status")
                .removeObserver(withHandle: handle)
        }
    }
}

// 改良されたセルビュー
struct ImprovedCellView: View {
    let cellState: Int // 0: 空, 1: 黒, 2: 白
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: "1A8700"))
                .overlay(
                    Rectangle()
                        .stroke(Color.black.opacity(0.5), lineWidth: 0.5)
                )
                .frame(width: 38, height: 38)
            
            if cellState > 0 {
                Circle()
                    .fill(cellState == 1 ? Color.black : Color.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: cellState == 1 ? .white.opacity(0.1) : .black.opacity(0.5),
                           radius: 2, x: 0, y: 1)
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

// 改良された心拍数表示カード
struct ImprovedHeartRateCard: View {
    var name: String
    var heartRate: Int
    var isLeading: Bool
    var beatInterval: Double
    
    @State private var heartScale: CGFloat = 1.0
    @State private var isAnimating: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // ユーザー名
            Text(name)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            // ハートアイコンと心拍数
            VStack(spacing: 6) {
                // アニメーションするハート
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
                    .scaleEffect(heartScale)
                    .shadow(color: .red.opacity(0.6), radius: isLeading ? 8 : 4)
                    .onAppear {
                        isAnimating = true
                    }
                    .onDisappear {
                        isAnimating = false
                    }
                    // 心拍数に合わせたアニメーション
                    .onReceive(
                        Timer.publish(every: beatInterval, on: .main, in: .common).autoconnect()
                    ) { _ in
                        withAnimation(.easeInOut(duration: beatInterval / 4)) {
                            heartScale = 1.3
                        }
                        withAnimation(Animation.easeInOut(duration: beatInterval * 3 / 4)
                                        .delay(beatInterval / 4)) {
                            heartScale = 1.0
                        }
                    }
                
                Text("\(heartRate)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("BPM")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(width: 120, height: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "222222"))
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
                .shadow(
                    color: isLeading ? .red.opacity(0.3) : .clear,
                    radius: 10, x: 0, y: 0
                )
        )
    }
}
// Color Extension for hex colors (if not already defined elsewhere)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct OthelloView_Previews: PreviewProvider {
    static var previews: some View {
        OthelloView(roomID: "preview_room", opponentName: "相手プレイヤー")
    }
}
