import XCTest
@testable import StudyPlanner

final class StudyPlannerPublicTests: XCTestCase {
    func testValidItemStoresValues() throws {
        let item = try StudyItem(
            id: "read-1",
            title: "Read Swift",
            estimatedMinutes: 30,
            category: .reading
        )

        XCTAssertEqual(item.id, "read-1")
        XCTAssertFalse(item.isCompleted)
    }

    func testBlankTitleIsRejected() {
        XCTAssertThrowsError(
            try StudyItem(id: "x", title: "  \n", estimatedMinutes: 10, category: .practice)
        )
    }

    func testIncompleteMinutesAndCompletion() throws {
        let first = try StudyItem(id: "a", title: "A", estimatedMinutes: 10, category: .reading)
        let second = try StudyItem(id: "b", title: "B", estimatedMinutes: 20, category: .practice)
        var plan = try StudyPlan(items: [first, second])

        try plan.markCompleted(id: "a")

        XCTAssertEqual(plan.incompleteMinutes(), 20)
    }

    // MARK: - Student-Authored Tests (AAA Pattern)

    // MARK: Task 1: Validation and errors

    func testTitleValidationTakesPrecedenceOverMinutes() {
        // Arrange
        let blankTitle = "   \n\t"
        let negativeMinutes = -5

        // Act & Assert
        XCTAssertThrowsError(
            try StudyItem(id: "1", title: blankTitle, estimatedMinutes: negativeMinutes, category: .reading)
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, .blankTitle)
        }
    }

    func testZeroEstimatedMinutesThrowsError() {
        // Arrange
        let validTitle = "Learn Concurrency"
        let zeroMinutes = 0

        // Act & Assert
        XCTAssertThrowsError(
            try StudyItem(id: "2", title: validTitle, estimatedMinutes: zeroMinutes, category: .practice)
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, .nonPositiveEstimatedMinutes)
        }
    }

    func testNegativeEstimatedMinutesThrowsError() {
        // Arrange
        let validTitle = "Learn Memory Management"
        let negativeMinutes = -15

        // Act & Assert
        XCTAssertThrowsError(
            try StudyItem(id: "3", title: validTitle, estimatedMinutes: negativeMinutes, category: .project)
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, .nonPositiveEstimatedMinutes)
        }
    }

    // MARK: Task 2: Codable boundaries

    func testDecodingStudyItemWithBlankTitleThrowsError() {
        // Arrange
        let blankTitleJSON = """
        {"id": "inv-1", "title": "   ", "estimatedMinutes": 20, "category": "reading", "isCompleted": false}
        """.data(using: .utf8)!

        // Act & Assert
        XCTAssertThrowsError(try JSONDecoder().decode(StudyItem.self, from: blankTitleJSON)) { error in
            XCTAssertEqual(error as? StudyPlanError, .blankTitle)
        }
    }

    func testDecodingStudyItemWithNonPositiveMinutesThrowsError() {
        // Arrange
        let invalidMinutesJSON = """
        {"id": "inv-2", "title": "Valid", "estimatedMinutes": -10, "category": "practice", "isCompleted": false}
        """.data(using: .utf8)!

        // Act & Assert
        XCTAssertThrowsError(try JSONDecoder().decode(StudyItem.self, from: invalidMinutesJSON)) { error in
            XCTAssertEqual(error as? StudyPlanError, .nonPositiveEstimatedMinutes)
        }
    }

    func testDecodingStudyItemDefaultsIsCompletedToFalseWhenOmitted() throws {
        // Arrange
        let jsonWithoutCompleted = """
        {"id": "valid-1", "title": "Read Docs", "estimatedMinutes": 30, "category": "reading"}
        """.data(using: .utf8)!

        // Act
        let decodedItem = try JSONDecoder().decode(StudyItem.self, from: jsonWithoutCompleted)

        // Assert
        XCTAssertEqual(decodedItem.id, "valid-1")
        XCTAssertEqual(decodedItem.title, "Read Docs")
        XCTAssertFalse(decodedItem.isCompleted)
    }

    func testKeyedStudyPlanDecodingSortsItemsDeterministically() throws {
        // Arrange
        let keyedJSON = """
        {
            "items": [
                {"id": "z", "title": "Zeta", "estimatedMinutes": 10, "category": "reading", "isCompleted": false},
                {"id": "a", "title": "Alpha", "estimatedMinutes": 20, "category": "practice", "isCompleted": true}
            ]
        }
        """.data(using: .utf8)!

        // Act
        let plan = try JSONDecoder().decode(StudyPlan.self, from: keyedJSON)

        // Assert
        XCTAssertEqual(plan.items.count, 2)
        XCTAssertEqual(plan.items[0].id, "a")
        XCTAssertEqual(plan.items[1].id, "z")
    }

    func testKeyedStudyPlanDecodingRejectsDuplicateIDs() {
        // Arrange
        let duplicateKeyedJSON = """
        {
            "items": [
                {"id": "dup", "title": "Task 1", "estimatedMinutes": 10, "category": "reading", "isCompleted": false},
                {"id": "dup", "title": "Task 2", "estimatedMinutes": 20, "category": "practice", "isCompleted": false}
            ]
        }
        """.data(using: .utf8)!

        // Act & Assert
        XCTAssertThrowsError(try JSONDecoder().decode(StudyPlan.self, from: duplicateKeyedJSON)) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("dup"))
        }
    }

    func testTopLevelJSONArrayDecodingSucceeds() throws {
        // Arrange
        let jsonArrayData = """
        [
            {"id": "item-2", "title": "Task B", "estimatedMinutes": 25, "category": "practice", "isCompleted": false},
            {"id": "item-1", "title": "Task A", "estimatedMinutes": 15, "category": "reading", "isCompleted": true}
        ]
        """.data(using: .utf8)!

        // Act
        let plan = try StudyPlan.decode(from: jsonArrayData)

        // Assert
        XCTAssertEqual(plan.items.count, 2)
        XCTAssertEqual(plan.items[0].id, "item-1")
        XCTAssertEqual(plan.items[1].id, "item-2")
    }

    func testDecodingStudyPlanFromFixtureFile() throws {
        // Arrange
        guard let fixtureURL = Bundle.module.url(forResource: "study-items", withExtension: "json", subdirectory: "Fixtures") else {
            XCTFail("Fixture study-items.json not found")
            return
        }
        let fixtureData = try Data(contentsOf: fixtureURL)

        // Act
        let plan = try StudyPlan.decode(from: fixtureData)

        // Assert
        XCTAssertEqual(plan.items.count, 3)
    }

    // MARK: Task 3: Duplicates and ordering

    func testFirstDuplicateIDEncounteredIsReported() throws {
        // Arrange
        let item1 = try StudyItem(id: "id-1", title: "Beta", estimatedMinutes: 10, category: .reading)
        let item2 = try StudyItem(id: "id-2", title: "Alpha", estimatedMinutes: 20, category: .practice)
        let item3 = try StudyItem(id: "id-3", title: "Alpha", estimatedMinutes: 30, category: .project)
        let item2Dup = try StudyItem(id: "id-2", title: "Alpha Repeat", estimatedMinutes: 15, category: .practice)
        let item1Dup = try StudyItem(id: "id-1", title: "Beta Repeat", estimatedMinutes: 25, category: .reading)

        // Act & Assert: index 3 repeats id-2 before index 4 repeats id-1
        XCTAssertThrowsError(try StudyPlan(items: [item1, item2, item3, item2Dup, item1Dup])) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("id-2"))
        }
    }

    func testItemsWithSameTitleAreSortedByID() throws {
        // Arrange
        let itemBeta = try StudyItem(id: "id-1", title: "Beta", estimatedMinutes: 10, category: .reading)
        let itemAlpha3 = try StudyItem(id: "id-3", title: "Alpha", estimatedMinutes: 30, category: .project)
        let itemAlpha2 = try StudyItem(id: "id-2", title: "Alpha", estimatedMinutes: 20, category: .practice)

        // Act
        let plan = try StudyPlan(items: [itemBeta, itemAlpha3, itemAlpha2])

        // Assert: "Alpha" items sorted by ID (id-2 < id-3), then "Beta"
        XCTAssertEqual(plan.items.map(\.id), ["id-2", "id-3", "id-1"])
    }

    // MARK: Task 4: Queries and completion

    func testCategoryQueryReturnsMatchingItems() throws {
        // Arrange
        let itemReading = try StudyItem(id: "1", title: "Read", estimatedMinutes: 30, category: .reading)
        let itemProject = try StudyItem(id: "2", title: "Code", estimatedMinutes: 45, category: .project)
        let plan = try StudyPlan(items: [itemReading, itemProject])

        // Act
        let readingItems = plan.items(in: .reading)

        // Assert
        XCTAssertEqual(readingItems.count, 1)
        XCTAssertEqual(readingItems.first?.id, "1")
    }

    func testCategoryQueryReturnsEmptyArrayWhenNoMatches() throws {
        // Arrange
        let itemReading = try StudyItem(id: "1", title: "Read", estimatedMinutes: 30, category: .reading)
        let plan = try StudyPlan(items: [itemReading])

        // Act
        let practiceItems = plan.items(in: .practice)

        // Assert
        XCTAssertTrue(practiceItems.isEmpty)
    }

    func testIncompleteMinutesSumsOnlyUncompletedItems() throws {
        // Arrange
        let item1 = try StudyItem(id: "1", title: "Read", estimatedMinutes: 30, category: .reading, isCompleted: false)
        let item2 = try StudyItem(id: "2", title: "Code", estimatedMinutes: 45, category: .project, isCompleted: true)
        let item3 = try StudyItem(id: "3", title: "Quiz", estimatedMinutes: 15, category: .practice, isCompleted: false)
        let plan = try StudyPlan(items: [item1, item2, item3])

        // Act
        let totalIncomplete = plan.incompleteMinutes()

        // Assert: 30 + 15 = 45 (item2 is completed, so excluded)
        XCTAssertEqual(totalIncomplete, 45)
    }

    func testIncompleteMinutesReturnsZeroWhenAllItemsAreCompleted() throws {
        // Arrange
        let item = try StudyItem(id: "1", title: "Done Task", estimatedMinutes: 25, category: .reading, isCompleted: true)
        let plan = try StudyPlan(items: [item])

        // Act
        let total = plan.incompleteMinutes()

        // Assert
        XCTAssertEqual(total, 0)
    }

    func testMarkCompletedThrowsForUnknownID() throws {
        // Arrange
        let item = try StudyItem(id: "task-1", title: "Study", estimatedMinutes: 20, category: .reading)
        var plan = try StudyPlan(items: [item])

        // Act & Assert
        XCTAssertThrowsError(try plan.markCompleted(id: "missing-id")) { error in
            XCTAssertEqual(error as? StudyPlanError, .unknownID("missing-id"))
        }
    }

    func testMarkCompletedIsIdempotent() throws {
        // Arrange
        let item = try StudyItem(id: "task-1", title: "Study", estimatedMinutes: 20, category: .reading, isCompleted: true)
        var plan = try StudyPlan(items: [item])

        // Act: mark already completed item again
        try plan.markCompleted(id: "task-1")

        // Assert: should not throw, item remains completed
        XCTAssertTrue(plan.items[0].isCompleted)
        XCTAssertEqual(plan.incompleteMinutes(), 0)
    }

    // MARK: Bonus Task: importMerging

    func testImportMergingReplacesExistingItemAtCurrentPosition() throws {
        // Arrange
        let itemA = try StudyItem(id: "A", title: "Title A", estimatedMinutes: 10, category: .reading)
        let itemB = try StudyItem(id: "B", title: "Title B", estimatedMinutes: 20, category: .practice)
        let itemC = try StudyItem(id: "C", title: "Title C", estimatedMinutes: 30, category: .project)
        var plan = try StudyPlan(items: [itemA, itemB, itemC])

        let updatedB = try StudyItem(id: "B", title: "Updated Title B", estimatedMinutes: 50, category: .practice, isCompleted: true)

        // Act
        try plan.importMerging([updatedB])

        // Assert: position 1 still holds ID B, but with updated values
        XCTAssertEqual(plan.items.map(\.id), ["A", "B", "C"])
        XCTAssertEqual(plan.items[1].title, "Updated Title B")
        XCTAssertEqual(plan.items[1].estimatedMinutes, 50)
        XCTAssertTrue(plan.items[1].isCompleted)
    }

    func testImportMergingAppendsNewIDsInAscendingIDOrder() throws {
        // Arrange
        let existingItem = try StudyItem(id: "x1", title: "Task 1", estimatedMinutes: 10, category: .reading)
        var plan = try StudyPlan(items: [existingItem])

        let newZ = try StudyItem(id: "z9", title: "Zeta", estimatedMinutes: 10, category: .project)
        let newA = try StudyItem(id: "a2", title: "Alpha", estimatedMinutes: 20, category: .practice)
        let newM = try StudyItem(id: "m5", title: "Mu", estimatedMinutes: 15, category: .reading)

        // Act: incoming items passed in non-sorted order (z9, a2, m5)
        try plan.importMerging([newZ, newA, newM])

        // Assert: existing item x1 stays at index 0, new items appended sorted by ID (a2, m5, z9)
        XCTAssertEqual(plan.items.map(\.id), ["x1", "a2", "m5", "z9"])
    }

    func testImportMergingAtomicallyRejectsDuplicateIncomingIDs() throws {
        // Arrange
        let itemA = try StudyItem(id: "A", title: "Item A", estimatedMinutes: 10, category: .reading)
        let itemB = try StudyItem(id: "B", title: "Item B", estimatedMinutes: 20, category: .practice)
        var plan = try StudyPlan(items: [itemA, itemB])

        let incoming1 = try StudyItem(id: "A", title: "Item A Updated", estimatedMinutes: 15, category: .reading)
        let incoming2 = try StudyItem(id: "C", title: "Item C", estimatedMinutes: 25, category: .project)
        let incomingDup = try StudyItem(id: "C", title: "Item C Again", estimatedMinutes: 35, category: .project)

        // Act & Assert
        XCTAssertThrowsError(try plan.importMerging([incoming1, incoming2, incomingDup])) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("C"))
        }

        // Assert atomicity: original plan is completely unmodified
        XCTAssertEqual(plan.items, [itemA, itemB])
    }
}
