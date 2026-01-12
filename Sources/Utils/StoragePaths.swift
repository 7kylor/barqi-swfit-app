import Foundation

struct StoragePaths {
  static func documentURL(for id: UUID) throws -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let dataDir = docs.appendingPathComponent("data", isDirectory: true)

    if !FileManager.default.fileExists(atPath: dataDir.path) {
      try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
    }

    return dataDir.appendingPathComponent("\(id.uuidString).pdf")
  }

  static func modelDirectory() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent("models", isDirectory: true)
  }
}
