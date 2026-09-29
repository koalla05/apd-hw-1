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

    private enum CodingKeys: String, CodingKey {
        case id, title, estimatedMinutes, category, isCompleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        let category = try container.decode(StudyCategory.self, forKey: .category)
        let isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        try self.init(
            id: id,
            title: title,
            estimatedMinutes: estimatedMinutes,
            category: category,
            isCompleted: isCompleted
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(category, forKey: .category)
        try container.encode(isCompleted, forKey: .isCompleted)
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

    private enum CodingKeys: String, CodingKey {
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let items = try container.decode([StudyItem].self, forKey: .items)
        try self.init(items: items)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
    }

    public static func decode(from data: Data) throws -> StudyPlan {
        let items = try JSONDecoder().decode([StudyItem].self, from: data)
        return try StudyPlan(items: items)
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
        var incomingSeen = Set<String>()
        for item in importedItems {
            if incomingSeen.contains(item.id) {
                throw StudyPlanError.duplicateID(item.id)
            }
            incomingSeen.insert(item.id)
        }

        var updatedItems = self.items
        var newItems: [StudyItem] = []

        for item in importedItems {
            if let existingIndex = updatedItems.firstIndex(where: { $0.id == item.id }) {
                updatedItems[existingIndex] = item
            } else {
                newItems.append(item)
            }
        }

        newItems.sort { $0.id < $1.id }
        updatedItems.append(contentsOf: newItems)
        self.items = updatedItems
    }
}
