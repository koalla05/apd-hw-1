import Foundation

public enum StudyCategory: String, Codable, CaseIterable {
    case reading, practice, project
}

public enum StudyPlanError: Error, Equatable {
    case blankTitle
    case nonPositiveEstimatedMinutes
    case duplicateID(String)
    case unknownID(String)
}

public struct StudyItem: Codable, Equatable {
    public let id: String
    public let title: String
    public let estimatedMinutes: Int
    public let category: StudyCategory
    public private(set) var isCompleted: Bool

    public init(
        id: String,
        title: String,
        estimatedMinutes: Int,
        category: StudyCategory,
        isCompleted: Bool = false
    ) throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw StudyPlanError.blankTitle
        }
        if estimatedMinutes <= 0 {
            throw StudyPlanError.nonPositiveEstimatedMinutes
        }
        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.category = category
        self.isCompleted = isCompleted
    }

    public mutating func markAsCompleted() {
        self.isCompleted = true
    }
}

public struct StudyPlan: Codable, Equatable {
    public private(set) var items: [StudyItem]

    public init(items: [StudyItem]) throws {
        var seen = Set<String>()
        for item in items {
            if seen.contains(item.id) {
                throw StudyPlanError.duplicateID(item.id)
            }
            seen.insert(item.id)
        }
        self.items = items.sorted { lhs, rhs in
            if lhs.title != rhs.title {
                return lhs.title < rhs.title
            }
            return lhs.id < rhs.id
        }
    }

    public static func decode(from data: Data) throws -> StudyPlan {
        fatalError("Implement array decoding")
    }

    public func items(in category: StudyCategory) -> [StudyItem] {
        return items.filter { $0.category == category }
    }

    public func incompleteMinutes() -> Int {
        return items.filter { !$0.isCompleted }.map { $0.estimatedMinutes }.reduce(0, +)
    }

    public mutating func markCompleted(id: String) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw StudyPlanError.unknownID(id)
        }
        items[index].markAsCompleted()
    }

    public mutating func importMerging(_ importedItems: [StudyItem]) throws {
        fatalError("Implement optional bonus")
    }
}
