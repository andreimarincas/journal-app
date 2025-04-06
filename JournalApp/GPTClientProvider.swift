//
//  GPTClientProvider.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import Foundation

final class GPTClientProvider {
    static let shared: GPTClient = {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAI_API_Key") as? String ?? ""
        return GPTClient(apiKey: apiKey)
    }()
}
