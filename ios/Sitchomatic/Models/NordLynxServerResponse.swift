import Foundation

struct NordLynxServerResponse: Codable, Sendable {
    let id: Int
    let name: String
    let hostname: String
    let station: String
    let load: Int
    let technologies: [Technology]?
    let locations: [ServerLocation]?
    let flag: String?

    struct Technology: Codable, Sendable {
        let identifier: String
        let metadata: [Metadata]?
    }

    struct Metadata: Codable, Sendable {
        let name: String
        let value: String
    }

    struct ServerLocation: Codable, Sendable {
        let country: Country?
    }

    struct Country: Codable, Sendable {
        let name: String
        let code: String
        let city: City?
    }

    struct City: Codable, Sendable {
        let name: String
    }
}
