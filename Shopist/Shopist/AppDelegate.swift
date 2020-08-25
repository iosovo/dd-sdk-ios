/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import UIKit
import Datadog

internal fileprivate(set) var logger: Logger! // swiftlint:disable:this implicitly_unwrapped_optional
internal let appConfig = AppConfig(serviceName: "ios-sdk-shopist-app")
internal var rum: DDRUMMonitor? { Global.rum }

private struct User {
    let id: String
    let name: String
    let email: String

    static let users: [User] = [
        User(id: UUID().uuidString, name: "John Doe", email: "john@doe.com"),
        User(id: UUID().uuidString, name: "Jane Doe", email: "jane@doe.com"),
        User(id: UUID().uuidString, name: "Pat Doe", email: "pat@doe.com"),
        User(id: UUID().uuidString, name: "Sam Doe", email: "sam@doe.com")
    ]

    static func any() -> Self {
        return users.randomElement()! // swiftlint:disable:this force_unwrapping
    }
}

@UIApplicationMain
internal class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Datadog SDK
        Datadog.initialize(
            appContext: .init(),
            configuration: Datadog.Configuration
                .builderUsing(
                    rumApplicationID: appConfig.rumAppID,
                    clientToken: appConfig.clientToken,
                    environment: "tests"
                )
                // Currently, SDK doesn't auto-trace Alamofire requests
                // .set(tracedHosts: [API.baseHost])
                .build()
        )

        // Set user information
        let user = User.any()
        Datadog.setUserInfo(id: user.id, name: user.name, email: user.email)

        // Create logger instance
        logger = Logger.builder
            .set(serviceName: appConfig.serviceName)
            .printLogsToConsole(true, usingFormat: .shortWith(prefix: "[iOS App] "))
            .build()

        // Register global tracer
        Global.sharedTracer = Tracer.initialize(configuration: .init(serviceName: appConfig.serviceName))

        // Register global `RUMMonitor`
        Global.rum = RUMMonitor.initialize()

        // Set highest verbosity level to see internal actions made in SDK
        Datadog.verbosityLevel = .debug

        // Add attributes
        logger.addAttribute(forKey: "device-model", value: UIDevice.current.model)

        // Add tags
        #if DEBUG
        logger.addTag(withKey: "build_configuration", value: "debug")
        #else
        logger.addTag(withKey: "build_configuration", value: "release")
        #endif

        // Send some logs 🚀
        logger.info("application did finish launching")

        return true
    }

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
