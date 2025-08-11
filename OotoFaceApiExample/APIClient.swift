import Foundation
import UIKit

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

enum APIError: Error {
    case network(Error)
    case server(statusCode: Int, message: String, code: Int?)
    case decoding(Error)
    case invalidResponse(String)
    case unknown
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    // MARK: - Identify (1:N)
    func identify(
        image: UIImage,
        checkLiveness: Bool = false,
        checkDeepfake: Bool = false,
        completion: @escaping (Result<(templateId: String, similarity: Double), APIError>) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            completion(.failure(.invalidResponse("failed to encode jpeg")))
            return
        }

        var components = URLComponents(url: APIConstants.baseURL.appendingPathComponent(APIConstants.identifyEndpoint),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "check_liveness", value: checkLiveness ? "true" : "false"),
            URLQueryItem(name: "check_deepfake", value: checkDeepfake ? "true" : "false")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        setAuthHeaders(&request)
        let boundary = "----OOTO-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleIdentifyOrMapNoFace(data: data, response: response, error: error, completion: completion)
        }.resume()
    }

    // MARK: - Enrollment (Add)
    func enroll(
        image: UIImage,
        customTemplateId: String? = nil,
        checkLiveness: Bool = false,
        checkDeepfake: Bool = false,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            completion(.failure(.invalidResponse("failed to encode jpeg")))
            return
        }

        var components = URLComponents(url: APIConstants.baseURL.appendingPathComponent(APIConstants.addTemplateEndpoint),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "check_liveness", value: checkLiveness ? "true" : "false"),
            URLQueryItem(name: "check_deepfake", value: checkDeepfake ? "true" : "false")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        setAuthHeaders(&request)
        let boundary = "----OOTO-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // photo
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")

        // optional templateId
        if let tid = customTemplateId {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"templateId\"\r\n\r\n")
            body.append("\(tid)\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(.network(error))); return }
            guard let http = response as? HTTPURLResponse, let data = data else {
                completion(.failure(.unknown)); return
            }

            do {
                if http.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(APIContainer<EnrollmentResult>.self, from: data)
                    completion(.success(decoded.result.templateId))
                } else {
                    let err = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                    let message = err?.result.info ?? "server error"
                    completion(.failure(.server(statusCode: http.statusCode, message: message, code: err?.result.code)))
                }
            } catch {
                completion(.failure(.decoding(error)))
            }
        }.resume()
    }

    // MARK: - Delete
    func deleteTemplate(
        templateId: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let trimmed = templateId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.invalidResponse("templateId is empty after trim")))
            return
        }

        var request = URLRequest(url: APIConstants.baseURL.appendingPathComponent(APIConstants.deleteEndpoint))
        request.httpMethod = "POST"
        setAuthHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let body = DeleteRequest(templateId: trimmed)
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(.decoding(error)))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(.network(error))); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.unknown)); return
            }

            if (200...299).contains(http.statusCode) {
                if http.statusCode == 200, let data = data, !data.isEmpty {
                    _ = try? JSONDecoder().decode(DeleteSuccessResponse.self, from: data)
                }
                completion(.success(()))
                return
            }

            // Ошибка API: пробуем распарсить стандартную ошибку
            if let data = data, let err = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                completion(.failure(.server(statusCode: http.statusCode, message: err.result.info, code: err.result.code)))
            } else {
                completion(.failure(.server(statusCode: http.statusCode, message: "server error", code: nil)))
            }
        }.resume()
    }

    // MARK: - Helpers
    private func setAuthHeaders(_ request: inout URLRequest) {
        request.setValue(APIConstants.appId, forHTTPHeaderField: "APP-ID")
        request.setValue(APIConstants.appKey, forHTTPHeaderField: "APP-KEY")
    }

    private func handleIdentifyOrMapNoFace(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<(templateId: String, similarity: Double), APIError>) -> Void
    ) {
        if let error = error { completion(.failure(.network(error))); return }
        guard let http = response as? HTTPURLResponse, let data = data else {
            completion(.failure(.unknown)); return
        }

        do {
            if http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(APIContainer<IdentifyResult>.self, from: data)
                if let tid = decoded.result.templateId, let sim = decoded.result.similarity {
                    completion(.success((templateId: tid, similarity: sim)))
                } else {
                    completion(.failure(.invalidResponse("empty identify result")))
                }
            } else {
                if let err = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    let mapped = (err.result.code == 5) ? "No faces found" : err.result.info
                    completion(.failure(.server(statusCode: http.statusCode, message: mapped, code: err.result.code)))
                } else {
                    completion(.failure(.server(statusCode: http.statusCode, message: "server error", code: nil)))
                }
            }
        } catch {
            completion(.failure(.decoding(error)))
        }
    }
}
