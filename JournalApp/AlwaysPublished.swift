//
//  AlwaysPublished.swift
//  JournalApp
//
//  Created by Andrei Marincas on 07.04.2025.
//

import Combine
import Foundation

@propertyWrapper
class AlwaysPublished<Value>: ObservableObject {
    private var subject = PassthroughSubject<Value, Never>()

    private var _value: Value
    var wrappedValue: Value {
        get { _value }
        set {
            _value = newValue
            subject.send(newValue) // Always send
        }
    }

    var projectedValue: AnyPublisher<Value, Never> {
        subject.eraseToAnyPublisher()
    }

    init(wrappedValue: Value) {
        _value = wrappedValue
    }
}
