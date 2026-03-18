import Foundation

struct SavedRoom: Codable {
    var setup: GameSetup
    var players: [Player]
}

enum RoomStorage {
    private static let key = "SavedRoom"

    static func save(_ room: SavedRoom) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(room)
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() throws -> SavedRoom {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            throw NSError(domain: "RoomStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "沒有存檔"])
        }
        let decoder = JSONDecoder()
        return try decoder.decode(SavedRoom.self, from: data)
    }

    static func hasSave() -> Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    static func delete() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
