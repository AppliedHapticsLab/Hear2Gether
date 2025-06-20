import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct CardGameView: View {
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
    
    // トランプゲーム用の状態変数
    @State private var myCard: Int? = nil
    @State private var opponentCard: Int? = nil
    @State private var gameResult: String? = nil
    @State private var roundsPlayed: Int = 0
    @State private var myScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var isDealing: Bool = false
    @State private var showingAnimation: Bool = false
    
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
                    Spacer()
                    
                    // ゲームエリア
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "1A1A1A"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.red.opacity(0.5),
                                                Color.purple.opacity(0.3)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 25) {
                            // ゲームタイトル
                            Text("トランプ対決")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            // 相手のカード表示
                            CardView(
                                cardValue: opponentCard,
                                isFlipped: opponentCard != nil,
                                isDealing: isDealing,
                                isOpponent: true
                            )
                            .frame(width: 120, height: 180)
                            
                            // 結果表示
                            if let result = gameResult {
                                Text(result)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(
                                        result == "勝ち" ? .green :
                                            result == "負け" ? .red : .orange
                                    )
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 20)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: "222222"))
                                            .overlay(
                                                Capsule()
                                                    .stroke(
                                                        result == "勝ち" ? Color.green.opacity(0.5) :
                                                            result == "負け" ? Color.red.opacity(0.5) : Color.orange.opacity(0.5),
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                            }
                            
                            // 自分のカード表示
                            CardView(
                                cardValue: myCard,
                                isFlipped: myCard != nil,
                                isDealing: isDealing,
                                isOpponent: false
                            )
                            .frame(width: 120, height: 180)
                            
                            // カードを引くボタン
                            Button(action: {
                                dealCards()
                            }) {
                                Text(roundsPlayed == 0 ? "ゲーム開始" : "もう一度引く")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 30)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: "4A2545"))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                            .shadow(color: Color.purple.opacity(0.3), radius: 5)
                                    )
                            }
                            .disabled(isDealing)
                        }
                        .padding(.vertical, 20)
                    }
                    .frame(height: 600)
                    .padding(.horizontal)
                    
                    Spacer()
                    // スコア表示
                    HStack(spacing: 30) {
                        // 自分のスコア
                        VStack {
                            Text("あなた")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text("\(myScore)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80)
                        
                        // ラウンド表示
                        VStack {
                            Text("ラウンド")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text("\(roundsPlayed)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // 相手のスコア
                        VStack {
                            Text(opponentName)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                            Text("\(opponentScore)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80)
                    }
                    .padding(.vertical, 15)
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
                .padding(.top, 20)
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
        }
        .onDisappear {
            // 監視を解除
            removeAllObservers()
            
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
    
    // カードを引く処理
    private func dealCards() {
        isDealing = true
        gameResult = nil
        
        // カードをリセット
        myCard = nil
        opponentCard = nil
        
        // 新しいカードを引く
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                // 1〜13のランダムな数字（トランプのA〜Kに相当）
                myCard = Int.random(in: 1...13)
                opponentCard = Int.random(in: 1...13)
                
                // 結果判定
                if myCard == opponentCard {
                    gameResult = "引き分け"
                } else if myCard! > opponentCard! {
                    gameResult = "勝ち"
                    myScore += 1
                } else {
                    gameResult = "負け"
                    opponentScore += 1
                }
                
                roundsPlayed += 1
                
                // 結果をFirebaseに保存
                updateGameResult()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isDealing = false
            }
        }
    }
    
    // ゲーム結果をFirebaseに保存
    private func updateGameResult() {
        guard Auth.auth().currentUser != nil else { return }
        let ref = Database.database().reference()
        
        let resultData = [
            "myCard": myCard ?? 0,
            "opponentCard": opponentCard ?? 0,
            "result": gameResult ?? "",
            "roundsPlayed": roundsPlayed,
            "timestamp": ServerValue.timestamp()
        ] as [String : Any]
        
        ref.child("GameRooms").child(roomID).child("cardGame")
            .updateChildValues(resultData)
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
            // UIDが渡されていない場合は、roomIDから取得
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
            // FirebaseのremoveObserver(withHandle:)メソッドを使用
            ref.removeObserver(withHandle: handle)
        }
        
        // 接続状態の監視を解除
        if let handle = connectionStatusHandle {
            ref.child("GameRooms").child(roomID).child("status")
                .removeObserver(withHandle: handle)
        }
    }
}

// トランプカードビュー
struct CardView: View {
    var cardValue: Int?
    var isFlipped: Bool
    var isDealing: Bool
    var isOpponent: Bool
    
    @State private var rotation: Double = 0
    
    // カードの値からスーツとランクを取得
    private var cardRank: String {
        guard let value = cardValue else { return "" }
        switch value {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(value)"
        }
    }
    
    var body: some View {
        ZStack {
            // カード表面
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                .overlay(
                    Group {
                        if let _ = cardValue {
                            VStack {
                                HStack {
                                    Text(cardRank)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.leading, 10)
                                        .padding(.top, 5)
                                    
                                    Spacer()
                                }
                                
                                Spacer()
                                
                                Text(cardRank)
                                    .font(.system(size: 60, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                HStack {
                                    Spacer()
                                    
                                    Text(cardRank)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.trailing, 10)
                                        .padding(.bottom, 5)
                                        .rotationEffect(.degrees(180))
                                }
                            }
                        }
                    }
                )
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            
            // カード裏面
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "6A11CB"), Color(hex: "2575FC")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                .overlay(
                    Image(systemName: "suit.club.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.2))
                )
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: isOpponent ? 1 : -1, y: 0, z: 0))
        .onAppear {
            withAnimation(.easeOut(duration: 0.1)) {
                rotation = isOpponent ? -5 : 5
            }
        }
        .onChange(of: isDealing) { newValue,_ in
            if newValue {
                withAnimation(.easeInOut(duration: 0.3)) {
                    rotation = isOpponent ? 10 : -10
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        rotation = isOpponent ? -5 : 5
                    }
                }
            }
        }
    }
}

struct CardGameView_Previews: PreviewProvider {
    static var previews: some View {
        CardGameView(roomID: "preview_room", opponentName: "相手プレイヤー")
    }
}


