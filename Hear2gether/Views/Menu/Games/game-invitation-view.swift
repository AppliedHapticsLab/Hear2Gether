import SwiftUI
import FirebaseDatabase
import Kingfisher

// ゲーム招待データモデル
struct GameInvitationData {
    let senderUID: String
    let senderName: String
    let gameType: GameType
    let roomID: String
}

struct GameInvitationView: View {
    var invitation: GameInvitationData
    var onAccept: () -> Void
    var onDecline: () -> Void
    
    @State private var senderImageURL: String?
    @State private var showAcceptAnimation: Bool = false
    
    var body: some View {
        ZStack {
            // 半透明の黒色背景
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            // 招待カード
            VStack(spacing: 25) {
                // ヘッダー
                Text("ゲーム招待")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // 送信者の情報
                VStack(spacing: 15) {
                    // プロフィール画像
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        if let imageURL = senderImageURL,
                           let url = URL(string: imageURL),
                           !imageURL.isEmpty {
                            KFImage(url)
                                .placeholder {
                                    ProgressView()
                                        .foregroundColor(.white)
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 95, height: 95)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        } else {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text(invitation.senderName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("から\(invitation.gameType.title)の招待が届きました")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 10)
                
                // アクションボタン
                HStack(spacing: 20) {
                    // 拒否ボタン
                    Button(action: {
                        onDecline()
                    }) {
                        Text("拒否")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(hex: "333333"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // 承諾ボタン
                    Button(action: {
                        withAnimation {
                            showAcceptAnimation = true
                        }
                        
                        // アニメーション後に承諾処理
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onAccept()
                        }
                    }) {
                        Text("参加")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(width: 120, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.7)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .overlay(
                        Group {
                            if showAcceptAnimation {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(showAcceptAnimation ? 20 : 1)
                                    .opacity(showAcceptAnimation ? 0 : 1)
                                    .animation(
                                        Animation.easeOut(duration: 0.5),
                                        value: showAcceptAnimation
                                    )
                            }
                        }
                    )
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "222222"))
                    .shadow(color: Color.white.opacity(0.1), radius: 15, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(20)
        }
        .onAppear {
            fetchSenderProfileImage()
        }
    }
    
    // MARK: - Helper Functions
    
    private func fetchSenderProfileImage() {
        let ref = Database.database().reference()
        ref.child("Userdata").child(invitation.senderUID).child("profileImageURL")
            .observeSingleEvent(of: .value) { snapshot in
                if let imageURL = snapshot.value as? String {
                    DispatchQueue.main.async {
                        self.senderImageURL = imageURL
                    }
                }
            }
    }
}

struct GameInvitationView_Previews: PreviewProvider {
    static var previews: some View {
        GameInvitationView(
            invitation: GameInvitationData(
                senderUID: "senderUID123",
                senderName: "Bob",
                gameType: .tetris,
                roomID: "room123"
            ),
            onAccept: {},
            onDecline: {}
        )
    }
}
