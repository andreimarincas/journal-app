//
//  JournalTone.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

enum JournalTone: CaseIterable {
    case reflective, hopeful, melancholy

    var text: String {
        switch self {
        case .reflective: return "✨ I kept walking, not toward anything — just away from stillness."
        case .hopeful: return "✨ There’s something beautiful forming, just past what I can see."
        case .melancholy: return "✨ The sky carried weight I couldn’t name, only feel."
        }
    }
    
    var label: String {
        switch self {
        case .reflective: return "—Reflective"
        case .hopeful: return "—Hopeful"
        case .melancholy: return "—Melancholy"
        }
    }
    
    var color: Color {
        switch self {
        case .reflective: return Color("ToneReflective")
        case .hopeful: return Color("ToneHopeful")
        case .melancholy: return Color("ToneMelancholy")
        }
    }
}
