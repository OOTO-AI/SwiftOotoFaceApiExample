import Foundation

struct DeleteSuccessResponse: Codable {
    let transactionId: String
}

struct DeleteRequest: Codable {
    let templateId: String
}
