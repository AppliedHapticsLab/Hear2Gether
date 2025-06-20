import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import Kingfisher
import Combine
import AudioToolbox
import CoreHaptics
import AVFoundation
import FirebaseStorage

// カラーテーマの拡張
extension ColorManager {
    // オプション画面用の追加カラー
    static let optionsHeaderColor = primaryColor
    static let optionsSubtleColor = subtleTextColor
    static let optionsInactiveColor = inactiveColor
}

struct OptionsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    // ユーザー情報用
    @State private var displayName: String = "Loading..."
    @State private var profileImageURL: String? = nil
    @State private var usernameHandle: DatabaseHandle?

    // MARK: - iPhone 設定用（AppStorage を利用してローカル保存）
    @AppStorage("iphoneVibrationEnabled") private var iphoneVibrationEnabled: Bool = false
    @AppStorage("hapticSetX") private var hapticSetXDouble: Double = 150.0
    @AppStorage("hapticSetY") private var hapticSetYDouble: Double = 150.0
    
    // UserDefaults の "hasShownAppleWatchConnection" キーの値を参照・更新する
    @AppStorage(Constants.connectionShownKey) private var connectionShown: Bool = true
    
    // Add this property to OptionsView
    private let hapticManager = HapticManager()
    
    // CGFloat 用に変換
    private var hapticSetX: CGFloat {
        get { CGFloat(hapticSetXDouble) }
        set { hapticSetXDouble = Double(newValue) }
    }
    private var hapticSetY: CGFloat {
        get { CGFloat(hapticSetYDouble) }
        set { hapticSetYDouble = Double(newValue) }
    }

    // MARK: - Apple Watch 設定用（Firebase 連携）
    @State private var appleWatchVibrationEnabled: Bool = false
    // Apple Watch 側の振動強度設定（0: Low, 1: Medium, 2: High）
    @State private var selectedOptionWatch: Int = 0
    let watchOptions = ["Low", "Medium", "High"]
    
    // 初期ロードフラグ - Firebaseからの読み込みが完了したか
    @State private var initialLoadCompleted: Bool = false
    // トグルの状態変更を追跡するフラグを追加
    @State private var isUpdatingToggle: Bool = false

    // MARK: - アカウント関連
    @State private var showingDeleteAlert = false
    @State private var showingLogoutAlert = false
    
    // 削除処理中フラグ
    @State private var isDeletingAccount = false

    var body: some View {
        ZStack {
            // 背景
            ColorManager.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // トップスペース（ステータスバー用）
                Color.clear
                    .frame(height: 40)
                // ヘッダー部分
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("設定")
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
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(ColorManager.inactiveColor)
                                )
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // リスト部分
                NavigationStack {
                    List {
                        // iPhone 設定セクション
                        Section(header:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "iphone")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(ColorManager.primaryColor)
                                    
                                    Text("iPhone")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(ColorManager.textColor)
                                }
                                
                                Text("iPhoneの振動設定")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(ColorManager.subtleTextColor)
                            }
                            .padding(.top, 10)
                        ) {
                            Toggle("振動を有効化する", isOn: $iphoneVibrationEnabled)
                                .listRowBackground(ColorManager.cardColor)
                                .foregroundColor(ColorManager.textColor)
                                .toggleStyle(SwitchToggleStyle(tint: ColorManager.primaryColor))
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                            
                            if iphoneVibrationEnabled {
                                VStack(spacing: 15) {
                                    Text("Vibration Strength")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(ColorManager.textColor)
                                    
                                    TouchView(
                                        hapticX: Binding(
                                            get: { CGFloat(hapticSetXDouble) },
                                            set: { hapticSetXDouble = Double($0) }
                                        ),
                                        hapticY: Binding(
                                            get: { CGFloat(hapticSetYDouble) },
                                            set: { hapticSetYDouble = Double($0) }
                                        )
                                    )
                                    .frame(height: 300)
                                    
                                    HStack {
                                        Spacer()
                                        VStack {
                                            Text("Sharpness")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(ColorManager.subtleTextColor)
                                            Text(String(format: "%.2f", Double(hapticSetX) / 300.0))
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                                .foregroundColor(ColorManager.primaryColor)
                                        }
                                        Spacer()
                                        VStack {
                                            Text("Intensity")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(ColorManager.subtleTextColor)
                                            Text(String(format: "%.2f", Double(hapticSetY) / 300.0))
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                                .foregroundColor(ColorManager.secondaryColor)
                                        }
                                        Spacer()
                                    }
                                    
                                    HStack{
                                        Button(action: {
                                            // Test the current haptic settings
                                            hapticManager.testCurrentHapticSettings()
                                        }) {
                                            HStack {
                                                Image(systemName: "waveform.path.ecg")
                                                    .foregroundColor(.white)
                                                Text("Test Vibration")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        ColorManager.primaryColor,
                                                        ColorManager.secondaryColor
                                                    ]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            )
                                            .shadow(color: ColorManager.primaryColor.opacity(0.3), radius: 5, x: 0, y: 3)
                                        }
                                        .disabled(!iphoneVibrationEnabled)
                                        .opacity(iphoneVibrationEnabled ? 1.0 : 0.5)
                                        .listRowBackground(ColorManager.cardColor)
                                    }
                                }
                                .padding(.vertical, 10)
                                .listRowBackground(ColorManager.cardColor)
                                
                                
                            }
                        }
                        .listRowSeparator(.hidden)
                        
                        // Apple Watch 設定セクション
                        Section(header:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "applewatch")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(ColorManager.primaryColor)
                                    
                                    Text("Apple Watch")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(ColorManager.textColor)
                                }
                                
                                Text("Apple Watchの振動設定")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(ColorManager.subtleTextColor)
                            }
                            .padding(.top, 10)
                        ) {
                            // 修正: onChange イベントを修正したトグルスイッチ
                            Toggle("振動を有効化する", isOn: $appleWatchVibrationEnabled)
                                .foregroundColor(ColorManager.textColor)
                                .toggleStyle(SwitchToggleStyle(tint: ColorManager.primaryColor))
                                .listRowBackground(ColorManager.cardColor)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .onChange(of: appleWatchVibrationEnabled) { newValue, _ in
                                    // 初期ロードが完了していて、かつ更新中でない場合のみFirebaseを更新
                                    if initialLoadCompleted && !isUpdatingToggle {
                                        updateFirebaseSetting(path: "MyPreference/Vibration/Toggle", value: appleWatchVibrationEnabled)
                                    }
                                }
                                .disabled(!initialLoadCompleted) // 初期ロード完了まで無効化
                            
                            if appleWatchVibrationEnabled {
                                VStack(spacing: 15) {
                                    Text("Vibration Strength")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(ColorManager.textColor)
                                    
                                    // 修正: 同様に onChange イベントを修正したセグメントコントロール
                                    Picker("Options", selection: $selectedOptionWatch) {
                                        ForEach(0..<watchOptions.count, id: \.self) { index in
                                            Text(watchOptions[index])
                                                .tag(index)
                                                .foregroundColor(ColorManager.textColor)
                                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.vertical, 5)
                                    .onChange(of: selectedOptionWatch) { newValue, _ in
                                        // 初期ロードが完了していて、かつ更新中でない場合のみFirebaseを更新
                                        if initialLoadCompleted && !isUpdatingToggle {
                                            updateFirebaseSetting(path: "MyPreference/Vibration/Number", value: selectedOptionWatch)
                                        }
                                    }
                                    .disabled(!initialLoadCompleted) // 初期ロード完了まで無効化
                                }
                                .padding(.vertical, 10)
                                .listRowBackground(ColorManager.cardColor)
                            }
                        }
                        .listRowSeparator(.hidden)
                        
                        // アカウント関連セクション
                        Section(header:
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(ColorManager.primaryColor)
                                    
                                    Text("Account")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(ColorManager.textColor)
                                }
                                
                                Text("アカウント設定と管理")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(ColorManager.subtleTextColor)
                            }
                            .padding(.top, 10)
                        ) {
                            NavigationLink(destination: EditAccountView()) {
                                HStack {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(ColorManager.primaryColor)
                                        .font(.system(size: 18))
                                    Text("アカウントの編集")
                                        .foregroundColor(ColorManager.textColor)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(.vertical, 4)
                            
                            Button {
                                showingLogoutAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(ColorManager.primaryColor)
                                        .font(.system(size: 18))
                                    Text("ログアウト")
                                        .foregroundColor(ColorManager.primaryColor)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .padding(.vertical, 4)
                            
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 18))
                                    Text("アカウントの削除")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .padding(.vertical, 4)
                            .disabled(isDeletingAccount) // 削除処理中は無効化

                        }
                        .listRowSeparator(.hidden)
                        
                        // 空のセクションで余白を確保
                            Section {
                                Color.clear.frame(height: 50)
                            }
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(ColorManager.backgroundColor)
                    
                    // ログアウト確認アラート
                    .alert("ログアウトしますか？", isPresented: $showingLogoutAlert) {
                        Button("キャンセル", role: .cancel) { }
                        Button("ログアウト", role: .destructive) {
                            connectionShown = false
                            
                            do {
                                try Auth.auth().signOut()
                                viewModel.isLoggedIn = false
                            } catch {
                                print("サインアウトに失敗: \(error.localizedDescription)")
                            }
                        }
                    } message: {
                        Text("本当にログアウトしますか？")
                    }
                    
                    // アカウント削除確認アラートの実装を修正
                    .alert("アカウント削除", isPresented: $showingDeleteAlert) {
                        Button("キャンセル", role: .cancel) { }
                        Button("削除する", role: .destructive) {
                            // 削除処理を実行
                            deleteAccount()
                        }
                    } message: {
                        Text("本当にアカウントを削除しますか？この操作は取り消せません。すべてのデータが完全に削除されます。")
                    }
                }
                .toolbar(.hidden, for: .navigationBar) // ナビゲーションバーを非表示に
            }
        }
        .onAppear {
            loadUserData()
            loadInitialFirebaseSettings()
        }
        .onDisappear {
            removeUserDataObserver()
        }
        .overlay(
            // 削除処理中のオーバーレイ表示
            Group {
                if isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.6)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .foregroundColor(.white)
                            
                            Text("アカウントを削除中...")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(25)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.8))
                        )
                    }
                }
            }
        )
    }
    
    // ユーザーデータの読み込み
    private func loadUserData() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let uid = currentUser.uid
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
    
    // ユーザーデータのオブサーバー削除
    private func removeUserDataObserver() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        
        if let handle = usernameHandle {
            ref.child("Username").child(uid).removeObserver(withHandle: handle)
        }
    }
    
    // Firebase 設定の更新 - 単純化版
    private func updateFirebaseSetting<T>(path: String, value: T) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        
        ref.child("Userdata").child(uid).child(path).setValue(value) { error, _ in
            if let error = error {
                print("設定更新エラー: \(error.localizedDescription)")
            }
        }
    }
    
    // Firebase 設定の初期読み込み - 修正版
    private func loadInitialFirebaseSettings() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        
        // ロード開始時にフラグを設定
        self.isUpdatingToggle = true
        
        // Firebase データの読み込みを一度にまとめて行う
        let vibrationRef = ref.child("Userdata").child(uid).child("MyPreference").child("Vibration")
        
        vibrationRef.observeSingleEvent(of: .value) { snapshot in
            if let vibrationData = snapshot.value as? [String: Any] {
                DispatchQueue.main.async {
                    // 全てのデータを一度に更新
                    if let toggleValue = vibrationData["Toggle"] as? Bool {
                        self.appleWatchVibrationEnabled = toggleValue
                    }
                    
                    if let number = vibrationData["Number"] as? Int {
                        self.selectedOptionWatch = number
                    } else if let numberStr = vibrationData["Number"] as? String, let number = Int(numberStr) {
                        self.selectedOptionWatch = number
                    }
                    
                    // 最後に全ての更新が完了してからフラグを設定
                    self.initialLoadCompleted = true
                    
                    // 少し遅延させてからトグルの更新を有効にする
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isUpdatingToggle = false
                    }
                }
            } else {
                // データが取得できなくても初期ロード完了とする
                DispatchQueue.main.async {
                    self.initialLoadCompleted = true
                    self.isUpdatingToggle = false
                }
            }
        }
    }
 
    // 修正: アカウント削除処理関数を改善
    private func deleteAccount() {
        // 削除処理中フラグを設定
        isDeletingAccount = true
        
        // 現在のユーザー情報を取得
        guard let user = Auth.auth().currentUser, let currentUID = authViewModel.currentUser?.uid else {
            isDeletingAccount = false
            showErrorAlert(message: "ユーザー情報の取得に失敗しました")
            return
        }
        
        // 1. ユーザーが再認証が必要か確認（最終ログイン時間によって異なる）
        let credential: AuthCredential? = nil // 必要に応じて認証情報を取得するロジックを追加
        
        // 1.1 再認証が必要な場合は再認証を実行
        if let credential = credential {
            user.reauthenticate(with: credential) { authResult, error in
                if let error = error {
                    isDeletingAccount = false
                    showErrorAlert(message: "再認証に失敗しました: \(error.localizedDescription)")
                    return
                }
                // 再認証成功、データ削除プロセスを開始
                self.startDeletionProcess(user: user, currentUID: currentUID)
            }
        } else {
            // 再認証不要、直接データ削除プロセスを開始
            startDeletionProcess(user: user, currentUID: currentUID)
        }
    }
    
    // 削除プロセスの実行（必要なデータの収集と削除実行）
    private func startDeletionProcess(user: User, currentUID: String) {
        let ref = Database.database().reference()
        
        // 1. データ収集: ユーザーに関連する全てのグループとフレンドデータを取得
        // すべての非同期操作を追跡するグループ
        let dataCollectionGroup = DispatchGroup()
        
        // グループデータ収集
        var userGroups: [String: [String: Any]] = [:]
        var groupMembers: [String: [String]] = [:]
        
        dataCollectionGroup.enter()
        ref.child("Userdata").child(currentUID).child("Groups").observeSingleEvent(of: .value) { snapshot in
            // 各グループのIDと詳細情報を収集
            for child in snapshot.children {
                if let groupSnapshot = child as? DataSnapshot {
                    let groupID = groupSnapshot.key
                    if let groupData = groupSnapshot.value as? [String: Any] {
                        userGroups[groupID] = groupData
                    }
                }
            }
            
            // 各グループのメンバー情報を収集
            let groupMembersGroup = DispatchGroup()
            
            for groupID in userGroups.keys {
                groupMembersGroup.enter()
                
                // グループメンバー情報の取得
                ref.child("BroadcastingRooms").child(groupID).child("members").observeSingleEvent(of: .value) { membersSnapshot in
                    if let members = membersSnapshot.value as? [String] {
                        groupMembers[groupID] = members
                    }
                    groupMembersGroup.leave()
                } withCancel: { error in
                    print("グループメンバー取得エラー: \(error.localizedDescription)")
                    groupMembersGroup.leave()
                }
            }
            
            groupMembersGroup.notify(queue: .main) {
                dataCollectionGroup.leave()
            }
        } withCancel: { error in
            print("グループデータ取得エラー: \(error.localizedDescription)")
            dataCollectionGroup.leave()
        }
        
        // フレンドデータ収集
        var userFriends: [String] = []
        var friendsPermissions: [String: [String]] = [:]
        
        dataCollectionGroup.enter()
        ref.child("AcceptUser").child(currentUID).child("permittedUser").observeSingleEvent(of: .value) { snapshot in
            // 自分がフレンドとして承認したユーザーのIDを収集
            for child in snapshot.children {
                if let friendSnapshot = child as? DataSnapshot {
                    userFriends.append(friendSnapshot.key)
                }
            }
            
            // 自分が承認されているユーザーを収集（双方向のフレンド関係）
            let friendsGroup = DispatchGroup()
            
            for friendUID in userFriends {
                friendsGroup.enter()
                ref.child("AcceptUser").child(friendUID).child("permittedUser").observeSingleEvent(of: .value) { permissionsSnapshot in
                    var permissions: [String] = []
                    for child in permissionsSnapshot.children {
                        if let permissionSnapshot = child as? DataSnapshot {
                            permissions.append(permissionSnapshot.key)
                        }
                    }
                    friendsPermissions[friendUID] = permissions
                    friendsGroup.leave()
                } withCancel: { error in
                    print("フレンド権限取得エラー: \(error.localizedDescription)")
                    friendsGroup.leave()
                }
            }
            
            friendsGroup.notify(queue: .main) {
                dataCollectionGroup.leave()
            }
        } withCancel: { error in
            print("フレンドデータ取得エラー: \(error.localizedDescription)")
            dataCollectionGroup.leave()
        }
        
        // 2. すべてのデータ収集が完了した後、削除プロセスを実行
        dataCollectionGroup.notify(queue: .main) {
            self.executeAccountDeletion(
                user: user,
                currentUID: currentUID,
                userGroups: userGroups,
                groupMembers: groupMembers,
                userFriends: userFriends,
                friendsPermissions: friendsPermissions
            )
        }
    }
    
    // 実際の削除処理の実行
    private func executeAccountDeletion(
        user: User,
        currentUID: String,
        userGroups: [String: [String: Any]],
        groupMembers: [String: [String]],
        userFriends: [String],
        friendsPermissions: [String: [String]]
    ) {
        let ref = Database.database().reference()
        let storage = Storage.storage().reference()
        
        // すべての削除処理を追跡するグループ
        let deletionGroup = DispatchGroup()
        
        // 1. グループデータの削除
        for (groupID, groupData) in userGroups {
            deletionGroup.enter()
            
            // 自分がホストの場合は完全に削除
            if let creatorBy = groupData["creatorBy"] as? String, creatorBy == currentUID {
                // グループの完全削除（BroadcastingRoomから）
                ref.child("BroadcastingRooms").child(groupID).removeValue { error, _ in
                    if let error = error {
                        print("グループ削除エラー (\(groupID)): \(error.localizedDescription)")
                    }
                    
                    // 各メンバーのUserdataからもグループ参照を削除
                    if let members = groupMembers[groupID] {
                        let membersDeletionGroup = DispatchGroup()
                        
                        for memberUID in members {
                            if memberUID != currentUID { // 自分以外のメンバー
                                membersDeletionGroup.enter()
                                ref.child("Userdata").child(memberUID).child("Groups").child(groupID).removeValue { error, _ in
                                    if let error = error {
                                        print("メンバーからのグループ参照削除エラー (\(memberUID), \(groupID)): \(error.localizedDescription)")
                                    }
                                    membersDeletionGroup.leave()
                                }
                            }
                        }
                        
                        membersDeletionGroup.notify(queue: .main) {
                            deletionGroup.leave()
                        }
                    } else {
                        deletionGroup.leave()
                    }
                }
            } else {
                // 自分がメンバーの場合は、グループから自分を削除
                if var members = groupMembers[groupID] {
                    members.removeAll { $0 == currentUID }
                    
                    // グループのメンバーリストを更新
                    ref.child("BroadcastingRooms").child(groupID).child("members").setValue(members) { error, _ in
                        if let error = error {
                            print("グループメンバー更新エラー (\(groupID)): \(error.localizedDescription)")
                        }
                        deletionGroup.leave()
                    }
                } else {
                    deletionGroup.leave()
                }
            }
        }
        
        // 2. フレンド関係の削除
        for friendUID in userFriends {
            deletionGroup.enter()
            
            // 2.1 相手のpermittedUserから自分を削除
            ref.child("AcceptUser").child(friendUID).child("permittedUser").child(currentUID).removeValue { error, _ in
                if let error = error {
                    print("フレンド関係削除エラー1 (\(friendUID)): \(error.localizedDescription)")
                }
                
                // 2.2 相手のpermissionsから自分を削除
                ref.child("AcceptUser").child(friendUID).child("permissions").child(currentUID).removeValue { error, _ in
                    if let error = error {
                        print("フレンド関係削除エラー2 (\(friendUID)): \(error.localizedDescription)")
                    }
                    deletionGroup.leave()
                }
            }
        }
        
        // 3. 自分のユーザーデータの削除
        deletionGroup.enter()
        
        // 3.1 Username データの削除
        ref.child("Username").child(currentUID).removeValue { error, _ in
            if let error = error {
                print("ユーザー名データ削除エラー: \(error.localizedDescription)")
            }
            
            // 3.2 Userdata 全体を削除
            ref.child("Userdata").child(currentUID).removeValue { error, _ in
                if let error = error {
                    print("ユーザーデータ削除エラー: \(error.localizedDescription)")
                }
                
                // 3.3 AcceptUser データの削除
                ref.child("AcceptUser").child(currentUID).removeValue { error, _ in
                    if let error = error {
                        print("アクセプトユーザーデータ削除エラー: \(error.localizedDescription)")
                    }
                    deletionGroup.leave()
                }
            }
        }
        
        // 4. Storage のプロフィール画像削除
        deletionGroup.enter()
        storage.child("profile_images/\(currentUID).jpg").delete { error in
            if let error = error {
                print("プロフィール画像削除エラー: \(error.localizedDescription)")
                // エラーがあっても続行（画像がない場合もあるため）
            }
            deletionGroup.leave()
        }
        
        // 5. すべての削除処理が完了したらFirebase Authenticationアカウントを削除
        deletionGroup.notify(queue: .main) {
            // Firebase Authentication からユーザーを削除
            user.delete { error in
                // 削除処理中フラグを解除
                self.isDeletingAccount = false
                
                if let error = error {
                    // エラーがあった場合の処理
                    self.showErrorAlert(message: "アカウントの削除に失敗しました: \(error.localizedDescription)")
                } else {
                    // 成功した場合：ログアウト処理と画面遷移
                    // UserDefaults をクリア
                    UserDefaults.standard.removeObject(forKey: "hasLoggedInBefore_\(currentUID)")
                    UserDefaults.standard.removeObject(forKey: Constants.connectionShownKey)
                    
                    // ログアウト状態にしてログイン画面に戻る
                    do {
                        try Auth.auth().signOut()
                        
                        // 設定をリセット
                        self.connectionShown = false
                        
                        // すべてのViewModelの状態をリセット
                        self.viewModel.isLoggedIn = false
                        
                        // 削除成功メッセージを表示してから画面遷移
                        self.showSuccessAlert(
                            title: "アカウント削除完了",
                            message: "アカウントとすべての関連データが正常に削除されました。"
                        )
                    } catch {
                        print("サインアウトに失敗: \(error.localizedDescription)")
                        self.showErrorAlert(message: "サインアウトに失敗しました: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // エラーアラートの表示
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "エラー",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // アラートを表示
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    // 成功アラートの表示と画面遷移
    private func showSuccessAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            // アラートを閉じた後にメインスレッドでログイン画面に戻る
            DispatchQueue.main.async {
                // 現在のビュー階層をリセットしてログイン画面に強制的に戻る
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    // アニメーションありで切り替え
                    UIView.transition(with: window,
                                    duration: 0.5,
                                    options: .transitionCrossDissolve,
                                    animations: {
                        // ルートビューをログイン画面に設定
                        window.rootViewController = UIHostingController(rootView:
                            LoginView()
                                .environmentObject(AuthViewModel())
                                .environmentObject(AppViewModel())
                        )
                    })
                }
            }
        })
        
        // アラートを表示
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

struct OptionsView_Previews: PreviewProvider {
    static var previews: some View {
        OptionsView()
            .environmentObject(AppViewModel())
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}

// 更新されたTouchView
struct TouchView: View {
    @Binding var hapticX: CGFloat
    @Binding var hapticY: CGFloat
    @State private var position: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景と基本線
                RoundedRectangle(cornerRadius: 24)
                    .fill(ColorManager.cardColor)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ColorManager.primaryColor.opacity(0.5),
                                        ColorManager.secondaryColor.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // 座標軸線
                ArrowLine(isVertical: false)
                    .stroke(ColorManager.primaryColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 300, height: 2)
                    .position(x: geometry.size.width/2, y: geometry.size.height/2)
                
                ArrowLine(isVertical: true)
                    .stroke(ColorManager.primaryColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 2, height: 300)
                    .position(x: geometry.size.width/2, y: geometry.size.height/2)
                
                // ポインター
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ColorManager.primaryColor,
                                ColorManager.secondaryColor
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .cornerRadius(8.0)
                    .shadow(color: ColorManager.primaryColor.opacity(0.3), radius: 8, x: 0, y: 0)
                    .position(x: position.x, y: position.y)
                
                // 強度ラベル
                VStack {
                    Text("intensity")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(ColorManager.subtleTextColor)
                    Text("HIGH")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(ColorManager.textColor)
                }
                .frame(width: 100)
                .position(x: geometry.size.width/2 + 50, y: geometry.size.height - 25)
                
                VStack {
                    Text("intensity")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(ColorManager.subtleTextColor)
                    Text("LOW")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(ColorManager.textColor)
                }
                .frame(width: 100)
                .position(x: geometry.size.width/2 + 50, y: 25)
                
                VStack {
                    Text("sharpness")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(ColorManager.subtleTextColor)
                    Text("LOW")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(ColorManager.textColor)
                }
                .frame(width: 100)
                .position(x: 45, y: geometry.size.height/2 - 35)
                
                VStack {
                    Text("sharpness")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(ColorManager.subtleTextColor)
                    Text("HIGH")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(ColorManager.textColor)
                }
                .frame(width: 100)
                .position(x: geometry.size.width - 45, y: geometry.size.height/2 - 35)
                
                // ジェスチャー領域
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let clampedX = max(0, min(value.location.x, 300))
                                let clampedY = max(0, min(value.location.y, 300))
                                self.position = CGPoint(x: clampedX, y: clampedY)
                                self.hapticX = clampedX
                                self.hapticY = clampedY
                            }
                    )
                    .onAppear {
                        self.position = CGPoint(x: hapticX, y: hapticY)
                    }
            }
        }
    }
}

// EditAccountView と その他のコンポーネントは同じ
struct EditAccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name: String = ""
    @State private var imageURL: String = ""
    
    // 画像選択用
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    
    // 更新完了アラート用
    @State private var showUpdateAlert = false
    
    var body: some View {
        ZStack {
            // 背景
            ColorManager.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // プロフィール画像
                Button(action: {
                    showImagePicker = true
                }) {
                    if let url = URL(string: imageURL), selectedImage == nil {
                        KFImage(url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
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
                    } else if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
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
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(ColorManager.inactiveColor)
                            .frame(width: 150, height: 150)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                ColorManager.primaryColor.opacity(0.5),
                                                ColorManager.secondaryColor.opacity(0.5)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(image: $selectedImage, didFinishPicking: {
                        if let image = selectedImage {
                            let cropped = cropToSquare(image: image)
                            self.selectedImage = cropped
                            uploadProfileImage(cropped) { url in
                                if let url = url {
                                    self.imageURL = url.absoluteString
                                    updateUserImageURL(url.absoluteString)
                                    showUpdateAlert = true
                                }
                            }
                        }
                    })
                }
                
                // 名前編集用 TextField
                VStack(alignment: .leading, spacing: 8) {
                    Text("名前")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(ColorManager.subtleTextColor)
                    
                    TextField("Your name", text: $name, onCommit: {
                        updateUserName(name)
                    })
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(ColorManager.textColor)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(ColorManager.cardColor)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ColorManager.primaryColor.opacity(0.5),
                                        ColorManager.secondaryColor.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .padding(.horizontal, 25)
                
                // 更新ボタン
                Button(action: {
                    updateUserName(name)
                }) {
                    Text("更新する")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            ColorManager.primaryColor,
                                            ColorManager.secondaryColor
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: ColorManager.primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("アカウント編集")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            loadUserData()
        }
        .alert("変更しました", isPresented: $showUpdateAlert) {
            Button("OK", role: .cancel) { }
        }
    }
    
    // 以前の関数群
    private func loadUserData() {
        guard let currentUser = authViewModel.currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        ref.child("Username").child(uid).observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                self.name = dict["UName"] as? String ?? ""
                self.imageURL = dict["Uimage"] as? String ?? ""
            }
        }
    }
    
    private func updateUserName(_ newName: String) {
        guard let currentUser = authViewModel.currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        ref.child("Username").child(uid).child("UName").setValue(newName) { error, _ in
            if let error = error {
                print("名前更新エラー: \(error.localizedDescription)")
            } else {
                print("名前更新完了")
                showUpdateAlert = true
            }
        }
    }
    
    private func updateUserImageURL(_ url: String) {
        guard let currentUser = authViewModel.currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        ref.child("Username").child(uid).child("Uimage").setValue(url) { error, _ in
            if let error = error {
                print("画像URL更新エラー: \(error.localizedDescription)")
            } else {
                print("画像URL更新完了")
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage, completion: @escaping (URL?) -> Void) {
        guard let currentUser = authViewModel.currentUser else {
            completion(nil)
            return
        }
        let uid = currentUser.uid
        let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("画像アップロードエラー: \(error.localizedDescription)")
                completion(nil)
                return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("ダウンロードURL取得エラー: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    completion(url)
                }
            }
        }
    }
    
    private func cropToSquare(image: UIImage) -> UIImage {
        let originalWidth  = image.size.width
        let originalHeight = image.size.height
        let squareLength = min(originalWidth, originalHeight)
        let x = (originalWidth - squareLength) / 2.0
        let y = (originalHeight - squareLength) / 2.0
        let cropRect = CGRect(x: x, y: y, width: squareLength, height: squareLength)
        
        if let cgImage = image.cgImage,
           let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
}

// その他のコンポーネントはそのまま利用
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var didFinishPicking: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.didFinishPicking()
            picker.dismiss(animated: true)
        }
    }
}

struct ArrowLine: Shape {
    var isVertical: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isVertical {
            let midX = rect.midX
            path.move(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: midX, y: rect.maxY))
            path.move(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: midX - 5, y: rect.minY + 10))
            path.move(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: midX + 5, y: rect.minY + 10))
            path.move(to: CGPoint(x: midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: midX - 5, y: rect.maxY - 10))
            path.move(to: CGPoint(x: midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: midX + 5, y: rect.maxY - 10))
        } else {
            let midY = rect.midY
            path.move(to: CGPoint(x: rect.minX, y: midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: midY))
            path.move(to: CGPoint(x: rect.minX, y: midY))
            path.addLine(to: CGPoint(x: rect.minX + 10, y: midY - 5))
            path.move(to: CGPoint(x: rect.minX, y: midY))
            path.addLine(to: CGPoint(x: rect.minX + 10, y: midY + 5))
            path.move(to: CGPoint(x: rect.maxX, y: midY))
            path.addLine(to: CGPoint(x: rect.maxX - 10, y: midY - 5))
            path.move(to: CGPoint(x: rect.maxX, y: midY))
            path.addLine(to: CGPoint(x: rect.maxX - 10, y: midY + 5))
        }
        return path
    }
}
