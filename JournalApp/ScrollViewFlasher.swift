//
//  ScrollViewFlasher.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

struct ScrollViewFlasher: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = findScrollView(from: view) {
                scrollView.flashScrollers()
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func findScrollView(from view: NSView) -> NSScrollView? {
        var superview = view.superview
        while superview != nil {
            if let scrollView = superview as? NSScrollView {
                return scrollView
            }
            superview = superview?.superview
        }
        return nil
    }
}
