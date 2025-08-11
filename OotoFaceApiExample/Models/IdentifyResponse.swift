//
//  IdentifyResponse.swift
//  OotoFaceApiExample
//
//  Created by Yaroslav Zaicev on 08.08.2025.
//

import Foundation

struct APIContainer<T: Codable>: Codable {
    let transactionId: String
    let result: T
}

struct IdentifyResult: Codable {
    let templateId: String?
    let similarity: Double?
}

struct EnrollmentResult: Codable {
    let templateId: String
}

struct APIErrorResult: Codable {
    let status: String
    let code: Int
    let info: String
}

struct APIErrorResponse: Codable {
    let transactionId: String
    let result: APIErrorResult
}
