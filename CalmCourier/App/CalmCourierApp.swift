//
//  CalmCourierApp.swift
//  CalmCourier
//
//  Created by Sarah Clark on 11/5/26.
//

import SwiftUI

@main
struct CalmCourierApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            AppRootView(environment: environment)
        }
    }
}
