//
//  TOYApp.swift
//  TOY
//
//  Created by David Park on 2/1/26.
//

import SwiftUI
import TOYShared

@main
struct TOYApp: App {
    init() {
        print("TOYShared version: \(TOYShared.version)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
