//
//  LottieView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI
import Lottie

struct LottieView: NSViewRepresentable {
    let filename: String
    let loop: Bool

    func makeNSView(context: Context) -> NSView {
        let animationView = LottieAnimationView(name: filename)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loop ? .loop : .playOnce
        animationView.play()
        
        let container = NSView(frame: .zero)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
