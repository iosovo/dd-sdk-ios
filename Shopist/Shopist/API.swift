/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import Alamofire
import Datadog

internal func fakeError(onceIn upperRandomBound: UInt8) -> Error? {
    assert(upperRandomBound != 0, "fakeError can be generated with non-zero positive numbers")
    if UInt8.random(in: 0..<upperRandomBound) == 0 {
        return NSError(
            domain: "Network",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Request denied"]
        )
    }
    return nil
}

internal struct Category: Decodable {
    let id: String
    let title: String
    let cover: URL
}

internal struct Product: Decodable, Equatable {
    let name: String
    let price: String
    let cover: URL
    let id: Int
    let isInStock: Bool
}

internal struct Payment: Encodable {
    struct Checkout: Encodable {
        let cardNumber: String
        let cvc: Int
        let exp: String

        init() {
            cardNumber = "\(Self.random(length: 16))"
            cvc = Self.random(length: 3)
            exp = "\(Int.random(in: 1...12))/\(Int.random(in: 21...30))"
        }

        private static func random(length: UInt8) -> Int {
            let max = Int(pow(10.0, Double(length)))
            let min = max / 10
            let output = Int.random(in: min..<max)
            return output
        }
    }
    let checkout = Checkout()

    struct Response: Decodable {
        let id: String?
        let cartID: String?
        let cardNumber: String
        let cvc: Int
        let exp: String
        let email: String
        let createdAt: String
        let updatedAt: String
    }
}

internal final class API {
    // swiftlint:disable force_cast
    static let baseHost = Bundle.main.object(forInfoDictionaryKey: "ShopistBaseURL") as! String
    // swiftlint:enable force_cast
    private static let baseURL = "https://" + baseHost
    private static let apiURL = "https://api." + baseHost

    typealias Completion<T: Decodable> = (Result<T, Error>) -> Void
    private let httpClient = Alamofire.Session(configuration: .default)
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func getCategories(completion: @escaping Completion<[Category]>) {
        let urlString = "\(Self.baseURL)/categories.json"
        make(request: URLRequest(urlString), completion: completion)
    }

    func getItems(for category: Category, completion: @escaping Completion<[Product]>) {
        let categoryID = category.id
        let urlString = "\(Self.baseURL)/category_\(categoryID).json"
        make(request: URLRequest(urlString), completion: completion)
    }

    func checkout(with discountCode: String?, payment: Payment = Payment(), completion: @escaping Completion<Payment.Response>) {
        var url = "\(Self.apiURL)/checkout.json"
        if let someCode = discountCode {
            url.append("?coupon_code=\(someCode)")
        }
        // swiftlint:disable force_try
        var request = try! URLRequest(url: url, method: .post)
        request.httpBody = try! jsonEncoder.encode(payment)
        // swiftlint:enable force_try
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        make(request: request, completion: completion)
    }

    private func make<T: Decodable>(request: URLRequest, completion: @escaping Completion<T>) {
        // swiftlint:disable force_unwrapping
        let url = request.url!
        let resourceName = url.pathComponents.joined()
        let httpMethod = RUMHTTPMethod(rawValue: request.httpMethod!)!
        // swiftlint:enable force_unwrapping
        rum?.startResourceLoading(resourceName: resourceName, url: url, httpMethod: httpMethod)

        let tracer = Global.sharedTracer
        let span = tracer.startSpan(operationName: request.url?.path ?? "network request").setActive()
        let headerWriter = HTTPHeadersWriter()
        headerWriter.inject(spanContext: span.context)
        var tracedRequest = request
        headerWriter.tracePropagationHTTPHeaders.forEach { tracedRequest.setValue($1, forHTTPHeaderField: $0) }

        httpClient.request(tracedRequest).validate().response { result in
            let statusCode = result.response?.statusCode
            span.setTag(key: OTTags.httpStatusCode, value: statusCode)
            if let someError = (result.error ?? fakeError(onceIn: 50)) {
                span.handleError(someError)
                rum?.stopResourceLoadingWithError(resourceName: resourceName, error: someError, source: .network, httpStatusCode: statusCode)
                completion(.failure(someError))
            } else if let someData = result.data {
                rum?.stopResourceLoading(
                    resourceName: resourceName,
                    kind: .fetch,
                    httpStatusCode: statusCode,
                    size: UInt64(someData.count)
                )
                let decodingSpan = tracer.startSpan(operationName: "decoding response data")
                decodingSpan.setTag(key: "data_size_in_bytes", value: someData.count)
                let completionResult: Result<T, Error>
                do {
                    Thread.sleep(for: .short)
                    let decoded = try self.jsonDecoder.decode(T.self, from: someData)
                    completionResult = .success(decoded)
                } catch {
                    decodingSpan.handleError(error)
                    completionResult = .failure(error)
                }
                decodingSpan.finish()
                completion(completionResult)
            }
            span.finish()
        }
    }
}

private extension OTSpan {
    func handleError(_ error: Error) {
        let nsError = error as NSError
        let errorStack = String(describing: error)
        let errorMessage = nsError.localizedDescription
        let errorKind = "\(nsError.domain) - \(nsError.code)"
        let logs: [String: Encodable] = [
            OTLogFields.event: "error",
            OTLogFields.errorKind: errorKind,
            OTLogFields.message: errorMessage,
            OTLogFields.stack: errorStack,
        ]
        self.log(fields: logs)
    }
}

private extension URLRequest {
    init(_ string: String) {
        self = URLRequest(url: URL(string: string)!) // swiftlint:disable:this force_unwrapping
    }
}
