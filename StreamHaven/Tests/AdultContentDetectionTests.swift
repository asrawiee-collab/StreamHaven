import XCTest
@testable import StreamHaven

final class AdultContentDetectionTests: XCTestCase {

    func testDetectsExplicitKeywordsInTitle() {
        let explicitTitles = [
            "XXX Movie", "Adult Content", "Explicit Material"
        ]
        
        for title in explicitTitles {
            let isAdult = AdultContentDetector.isAdultContent(title: title)
            XCTAssertTrue(isAdult, "Should detect '\(title)' as adult content")
        }
    }

    func testDetectsAdultCategoryNames() {
        let adultCategories = [
            "Adult", "XXX", "18+", "Mature"
        ]
        
        for category in adultCategories {
            let isAdult = AdultContentDetector.isAdultContent(title: "Regular Title", categoryName: category)
            XCTAssertTrue(isAdult, "Should detect category '\(category)' as adult")
        }
    }

    func testAllowsCleanContent() {
        let cleanTitles = [
            "Toy Story", "The Lion King", "Finding Nemo", "Frozen"
        ]
        
        for title in cleanTitles {
            let isAdult = AdultContentDetector.isAdultContent(title: title, categoryName: "Animation")
            XCTAssertFalse(isAdult, "Should not flag '\(title)' as adult content")
        }
    }

    func testHandlesNilCategory() {
        let isAdult = AdultContentDetector.isAdultContent(title: "Regular Movie", categoryName: nil)
        XCTAssertFalse(isAdult, "Should handle nil category gracefully")
    }

    func testCaseInsensitiveDetection() {
        let variations = [
            "xxx movie", "XXX MOVIE", "Xxx Movie", "XxX MoViE"
        ]
        
        for title in variations {
            let isAdult = AdultContentDetector.isAdultContent(title: title, categoryName: nil)
            XCTAssertTrue(isAdult, "Should detect '\(title)' regardless of case")
        }
    }

    func testPartialWordMatchesAreNotFlagged() {
        let safeTitles = [
            "The Classics", // Contains "ass" but shouldn't match
            "Expression", // Contains "xxx" but in different context
            "Adulting 101"    // Contains "adult" but different meaning
        ]
        
        for title in safeTitles {
            let isAdult = AdultContentDetector.isAdultContent(title: title, categoryName: "Comedy")
            XCTAssertFalse(isAdult, "Should not flag '\(title)' as adult content")
        }
    }

    func testDetectsAdultInEitherTitleOrCategory() {
        let isAdultInTitle = AdultContentDetector.isAdultContent(title: "XXX Content", categoryName: "Documentary")
        XCTAssertTrue(isAdultInTitle)
        
        let isAdultInCategory = AdultContentDetector.isAdultContent(title: "Regular Show", categoryName: "Adult")
        XCTAssertTrue(isAdultInCategory)
    }

    func testEmptyStringsReturnFalse() {
        let isAdult = AdultContentDetector.isAdultContent(title: "", categoryName: "")
        XCTAssertFalse(isAdult, "Empty strings should not be flagged as adult")
    }
}
