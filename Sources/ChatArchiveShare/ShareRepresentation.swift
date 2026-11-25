import Foundation
import UniformTypeIdentifiers

struct ShareRepresentation {
    enum Strategy {
        case fileRepresentation
        case fileURL
    }

    let typeIdentifier: String
    let strategy: Strategy

    static func choose(from identifiers: [String]) -> ShareRepresentation? {
        let types = identifiers.compactMap { identifier in
            UTType(identifier).map { (identifier, $0) }
        }

        if let zip = types.first(where: { $0.1 == .zip }) {
            return ShareRepresentation(typeIdentifier: zip.0, strategy: .fileRepresentation)
        }
        if let archive = types.first(where: {
            $0.1.conforms(to: .archive) && !$0.1.conforms(to: .url)
        }) {
            return ShareRepresentation(typeIdentifier: archive.0, strategy: .fileRepresentation)
        }
        if let data = types.first(where: {
            $0.1.conforms(to: .data) && !$0.1.conforms(to: .url)
        }) {
            return ShareRepresentation(typeIdentifier: data.0, strategy: .fileRepresentation)
        }
        if let fileURL = types.first(where: { $0.1.conforms(to: .fileURL) }) {
            return ShareRepresentation(typeIdentifier: fileURL.0, strategy: .fileURL)
        }
        return nil
    }
}
