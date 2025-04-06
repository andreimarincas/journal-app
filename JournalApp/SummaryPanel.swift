//
//  SummaryPanel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import SwiftUI

struct SummaryPanel: View {
    @State private var isHoveringRegenerateButton: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: SummaryPanelViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Summary")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                regenerateButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            Divider().padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isSummarizing {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<6, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(height: 12)
                                    .frame(maxWidth: [200, 250, 180, 220, 160, 240][index % 6], alignment: .leading)
                                    .shimmer()
                            }
                        }
                    } else {
                        Text(viewModel.summaryText)
                            .font(.system(size: 14))
                            .lineSpacing(6)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
        .onAppear {
            viewModel.maybeSummarize()
        }
    }
    
    private var regenerateButton: some View {
        Button(action: regenerateSummary) {
            Image(systemName: "sparkles")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    isHoveringRegenerateButton
                        ? Color.yellow : Color("SummarySparklesYellow"),
                    isHoveringRegenerateButton
                        ? Color.yellow.opacity(0.6) : Color("SummarySparklesYellow").opacity(0.5)
                )
                .frame(width: 28, height: 28)
                .font(.system(size: 16, weight: .regular))
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Circle())
                .opacity(isHoveringRegenerateButton ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Regenerate Summary")
        .onHover { hovering in
            isHoveringRegenerateButton = hovering
        }
        .disabled(viewModel.isSummarizing)
    }
    
    private var backgroundView: some View {
        ZStack(alignment: .leading) {
            Color("SummaryPanelBackground")
            LinearGradient(
                gradient: Gradient(colors: [
                    (colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.08 : 0.06),
                    Color.clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 8)
            .padding(.leading, -4)
        }
    }
    
    private func regenerateSummary() {
        viewModel.summarizeNotes()
    }
}


extension View {
    func shimmer(duration: Double = 1.0) -> some View {
        self
            .overlay(
                GeometryReader { geometry in
                    Color.white
                        .mask(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.4), Color.clear]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: geometry.size.width * 1.5, height: geometry.size.height)
                            .rotationEffect(.degrees(30))
                            .offset(x: -geometry.size.width)
                            .animation(
                                Animation.linear(duration: duration)
                                    .repeatForever(autoreverses: false),
                                value: UUID()
                            )
                        )
                }
            )
            .clipped()
    }
}
