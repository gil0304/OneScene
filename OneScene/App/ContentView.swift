//
//  ContentView.swift
//  OneScene
//
//  Created by 落合遼梧 on 2026/04/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = OneSceneViewModel()

    var body: some View {
        ZStack {
            OneScenePalette.backgroundGradient
                .ignoresSafeArea()

            currentScreen
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let toastMessage = viewModel.toastMessage {
                ToastPill(message: toastMessage)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: viewModel.screen)
        .animation(.easeInOut(duration: 0.25), value: viewModel.toastMessage)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch viewModel.screen {
        case .home:
            HomeScreen(viewModel: viewModel)
        case .camera:
            CameraScreen(viewModel: viewModel)
        case .review:
            CaptureReviewScreen(viewModel: viewModel)
        case .generating:
            GeneratingScreen(message: viewModel.generationMessage)
        case .result:
            ResultScreen(viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
