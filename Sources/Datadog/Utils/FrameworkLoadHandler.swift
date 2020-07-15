/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

public class FrameworkLoadHandler: NSObject {
    static var testObserver: XCTestsAutoInstrumentation?

    @objc
    public static func handleLoad() {
        let isInTestMode = ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
        if isInTestMode {
            testObserver = XCTestsAutoInstrumentation()
            XCTestsAutoInstrumentation.instance = testObserver
        }
    }
}
