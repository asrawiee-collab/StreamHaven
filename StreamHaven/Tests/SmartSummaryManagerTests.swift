//
//  SmartSummaryManagerTests.swift
//  StreamHaven
//
//  Tests for SmartSummaryManager functionality
//

import NaturalLanguage
import XCTest
@testable import StreamHaven

@MainActor
final class SmartSummaryManagerTests: XCTestCase {
    var manager: SmartSummaryManager!
    
    override func setUp() async throws {
        try await super.setUp()
        manager = SmartSummaryManager()
    }
    
    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Summary Generation
    
    func testGenerateSummaryFromLongPlot() {
        let longPlot = """
        John Smith is a skilled detective working in New York City. One day, he receives a mysterious phone call about a missing person. 
        As he begins his investigation, he discovers a complex web of lies and deception. The case leads him to dangerous criminals. 
        Along the way, he meets Sarah, a journalist who wants to help. Together they uncover shocking secrets. 
        The truth threatens powerful people in the city. John must decide whether to expose the corruption or protect his family. 
        In the end, justice prevails but at a great personal cost.
        """
        
        let summary = manager.generateSummary(from: longPlot, maxSentences: 3)
        
        XCTAssertNotNil(summary, "Summary should not be nil for valid plot")
        
        if let summary = summary {
            // Count sentences in summary
            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = summary
            let sentenceCount = tokenizer.tokens(for: summary.startIndex..<summary.endIndex).count
            
            XCTAssertLessThanOrEqual(sentenceCount, 3, "Summary should have at most 3 sentences")
            XCTAssertFalse(summary.isEmpty, "Summary should not be empty")
            XCTAssertLessThan(summary.count, longPlot.count, "Summary should be shorter than original")
        }
    }
    
    func testGenerateSummaryFromShortPlot() {
        let shortPlot = "A simple story about friendship."
        
        let summary = manager.generateSummary(from: shortPlot, maxSentences: 3)
        
        XCTAssertNotNil(summary, "Summary should not be nil for short plot")
        XCTAssertEqual(summary, shortPlot, "Short plot should be returned unchanged")
    }
    
    func testGenerateSummaryFromEmptyPlot() {
        let emptyPlot = ""
        
        let summary = manager.generateSummary(from: emptyPlot, maxSentences: 3)
        
        XCTAssertNil(summary, "Summary should be nil for empty plot")
    }
    
    func testGenerateSummaryFromVeryShortPlot() {
        let veryShortPlot = "Too short"
        
        let summary = manager.generateSummary(from: veryShortPlot, maxSentences: 3)
        
        // Should return original text when less than 50 characters
        XCTAssertEqual(summary, veryShortPlot, "Very short plot should be returned unchanged")
    }
    
    // MARK: - Sentence Count Variations
    
    func testGenerateSummaryWithCustomSentenceCount() {
        let plot = """
        First sentence about a hero. Second sentence about a villain. Third sentence about a conflict. 
        Fourth sentence about resolution. Fifth sentence about the ending.
        """
        
        let summary1 = manager.generateSummary(from: plot, maxSentences: 1)
        let summary2 = manager.generateSummary(from: plot, maxSentences: 2)
        
        XCTAssertNotNil(summary1, "1-sentence summary should not be nil")
        XCTAssertNotNil(summary2, "2-sentence summary should not be nil")
        
        if let summary1 = summary1, let summary2 = summary2 {
            let tokenizer1 = NLTokenizer(unit: .sentence)
            tokenizer1.string = summary1
            let count1 = tokenizer1.tokens(for: summary1.startIndex..<summary1.endIndex).count
            
            let tokenizer2 = NLTokenizer(unit: .sentence)
            tokenizer2.string = summary2
            let count2 = tokenizer2.tokens(for: summary2.startIndex..<summary2.endIndex).count
            
            XCTAssertLessThanOrEqual(count1, 1, "1-sentence summary should have at most 1 sentence")
            XCTAssertLessThanOrEqual(count2, 2, "2-sentence summary should have at most 2 sentences")
        }
    }
    
    // MARK: - Caching Tests
    
    func testGetCachedSummaryCreatesCache() {
        let plot = """
        A detective investigates a murder. The case becomes more complex. 
        Eventually, the truth is revealed. Justice is served.
        """
        let cacheKey = "movie_12345"
        
        let summary1 = manager.getCachedSummary(cacheKey: cacheKey, fullPlot: plot)
        let summary2 = manager.getCachedSummary(cacheKey: cacheKey, fullPlot: plot)
        
        XCTAssertNotNil(summary1, "First cached summary should not be nil")
        XCTAssertEqual(summary1, summary2, "Cached summary should be identical on second call")
    }
    
    func testGetCachedSummaryWithDifferentKeys() {
        let plot1 = "A story about love and loss. The characters grow and change."
        let plot2 = "A thriller about espionage. Secrets are uncovered."
        
        let summary1 = manager.getCachedSummary(cacheKey: "movie_1", fullPlot: plot1)
        let summary2 = manager.getCachedSummary(cacheKey: "movie_2", fullPlot: plot2)
        
        XCTAssertNotNil(summary1, "Summary 1 should not be nil")
        XCTAssertNotNil(summary2, "Summary 2 should not be nil")
        XCTAssertNotEqual(summary1, summary2, "Different cache keys should produce different summaries")
    }
    
    func testClearCache() {
        let plot = "A story with multiple sentences. Each sentence adds depth. The plot thickens."
        let cacheKey = "movie_99999"
        
        // Generate and cache summary
        let _ = manager.getCachedSummary(cacheKey: cacheKey, fullPlot: plot)
        
        // Clear cache
        manager.clearCache()
        
        // Next call should regenerate (can't directly test internal cache, but ensure no crash)
        let summary = manager.getCachedSummary(cacheKey: cacheKey, fullPlot: plot)
        XCTAssertNotNil(summary, "Summary should still be generated after cache clear")
    }
    
    // MARK: - Edge Cases
    
    func testGenerateSummaryWithSpecialCharacters() {
        let plot = """
        This plot contains "quotes" and special characters: @#$%^&*()! 
        It also has multiple sentences. Each with different punctuation? 
        Some sentences end with exclamation marks! Others are normal.
        """
        
        let summary = manager.generateSummary(from: plot, maxSentences: 2)
        
        XCTAssertNotNil(summary, "Summary with special characters should not be nil")
    }
    
    func testGenerateSummaryWithUnicodeCharacters() {
        let plot = """
        这是一个关于友谊的故事。角色们面对挑战。最终，他们取得了胜利。
        الحكاية تتحدث عن الشجاعة والأمل. القصة مليئة بالمغامرات.
        """
        
        let summary = manager.generateSummary(from: plot, maxSentences: 2)
        
        XCTAssertNotNil(summary, "Summary with Unicode characters should not be nil")
    }
    
    // MARK: - Premium Features (Not Yet Implemented)
    
    func testGeneratePersonalizedInsightReturnsNil() {
        let result = manager.generatePersonalizedInsight(contentID: "movie_123", watchHistory: ["movie_1", "movie_2"])
        
        XCTAssertNil(result, "Personalized insights should return nil (not yet implemented)")
    }
}
