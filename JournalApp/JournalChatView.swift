//
//  JournalChatView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 05.04.2025.
//

import SwiftUI

struct JournalChatView: View {
    let entry: JournalEntry
    @State private var messages: [String] = [
        "Hi, how are you feeling today?",
        "Would you like to explore a thought or memory?"
    ]
    @State private var selectedMessageIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Companion")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 24)
                .padding(.horizontal, 20)

            Divider().padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<messages.count, id: \.self) { index in
                        HStack(alignment: .top) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            Text(messages[index])
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            }

            Spacer()

            HStack {
                Button("Next") {
                    selectedMessageIndex = (selectedMessageIndex + 1) % messages.count
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                Spacer()
            }
        }
        .background(Color("ChatBackground"))
    }
}
