//
//  MainView.swift
//  Hear2gether
//
//  Created by Applied Haptics Laboratory on 2025/02/06.
//


import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = AppViewModel()
    // AuthViewModel のインスタンスを作成（アプリ全体で共有）
    @StateObject var authViewModel = AuthViewModel()
    // MainView用のNavigationPathを用意する
    @State private var mainPath = NavigationPath()

    var body: some View {
        // MainView をルートにするので、戻るボタンは表示されない
        NavigationStack(path: $mainPath) {
            ModeSelectionView()
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    print(viewModel.isLoggedIn)
                }
        }
        .preferredColorScheme(.dark)
    }
    
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AppViewModel())
    }
}
