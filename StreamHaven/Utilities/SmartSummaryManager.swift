//
//  SmartSummaryManager.swift
//  StreamHaven
//
//  Created by StreamHaven Team
//  Provides AI-generated content summaries using Apple's NaturalLanguage framework
//

import Foundation
import NaturalLanguage
import os.log

/// Manages smart content summaries for movies and series
/// Free tier: 2-3 line summaries using NLSummarizer
/// Premium tier: Personalized "Why You'd Like This" insights (future)
@MainActor
public class SmartSummaryManager: ObservableObject {
    private let logger = Logger(subsystem: "com.streamhaven.app", category: "SmartSummaryManager")
    
    // MARK: - Summary Generation
    
    /// Generates a concise 2-3 line summary from movie/series plot text
    /// - Parameters:
    ///   - fullPlot: The complete plot description from TMDb or provider
    ///   - maxSentences: Maximum number of sentences (default: 3)
    /// - Returns: Summarized text or nil if summarization fails
    public func generateSummary(from fullPlot: String, maxSentences: Int = 3) -> String? {
        guard !fullPlot.isEmpty else {
            logger.warning("Cannot generate summary: empty plot text")
            return nil
        }
        
        // Validate plot length (need at least 50 characters for meaningful summarization)
        guard fullPlot.count >= 50 else {
            logger.info("Plot too short for summarization, returning original text")
            return fullPlot
        }
        
        // Create tokenizer to count sentences
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = fullPlot
        
        let sentenceRanges = tokenizer.tokens(for: fullPlot.startIndex..<fullPlot.endIndex)
        let sentenceCount = sentenceRanges.count
        
        logger.debug("Plot has \(sentenceCount) sentences, requesting \(maxSentences) sentence summary")
        
        // If already short enough, return original
        if sentenceCount <= maxSentences {
            return fullPlot
        }
        
        // Use NLSummarizer for extractive summarization (available iOS 16+, tvOS 16+)
        if #available(iOS 16.0, tvOS 16.0, *) {
            do {
                let summarizer = try NLSummarizer(unit: .sentence)
                summarizer.string = fullPlot
                
                // Request top N sentences
                let summaryRange = summarizer.summarySentences(count: maxSentences)
                
                guard !summaryRange.isEmpty else {
                    logger.warning("Summarizer returned empty results, falling back to truncation")
                    return truncateToSentences(fullPlot, count: maxSentences)
                }
                
                // Extract summary sentences in original order
                let summary = summaryRange
                    .sorted { $0.lowerBound < $1.lowerBound }
                    .map { String(fullPlot[$0]) }
                    .joined(separator: " ")
                
                logger.info("Generated \(summaryRange.count)-sentence summary from \(sentenceCount) sentences")
                return summary
                
            } catch {
                logger.error("NLSummarizer failed: \(error.localizedDescription)")
                return truncateToSentences(fullPlot, count: maxSentences)
            }
        } else {
            // Fallback for older OS versions: simple truncation
            logger.warning("NLSummarizer unavailable (iOS/tvOS < 16), using truncation fallback")
            return truncateToSentences(fullPlot, count: maxSentences)
        }
    }
    
    // MARK: - Fallback Methods
    
    /// Truncates text to first N sentences (fallback when NLSummarizer unavailable)
    private func truncateToSentences(_ text: String, count: Int) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        let sentenceRanges = Array(tokenizer.tokens(for: text.startIndex..<text.endIndex))
        
        guard !sentenceRanges.isEmpty else {
            return text
        }
        
        let selectedRanges = sentenceRanges.prefix(count)
        guard let lastRange = selectedRanges.last else {
            return text
        }
        
        return String(text[text.startIndex..<lastRange.upperBound])
    }
    
    // MARK: - Premium Features (Future)
    
    /// Generates personalized "Why You'd Like This" insights based on watch history
    /// Premium-only feature requiring subscription
    /// - Parameters:
    ///   - contentID: The movie/series ID
    ///   - watchHistory: User's viewing patterns
    /// - Returns: Personalized recommendation text
    public func generatePersonalizedInsight(contentID: String, watchHistory: [String]) -> String? {
        // TODO: Implement after premium subscription system
        // Will use:
        // 1. Genre preferences from watch history
        // 2. Actor/director preferences
        // 3. Rating patterns
        // 4. Collaborative filtering for "viewers like you also enjoyed..."
        logger.info("Personalized insights not yet implemented (premium feature)")
        return nil
    }
    
    // MARK: - Caching
    
    /// In-memory cache to avoid re-generating summaries
    private var summaryCache: [String: String] = [:]
    
    /// Retrieves cached summary or generates new one
    /// - Parameters:
    ///   - cacheKey: Unique identifier (e.g., "movie_12345" or "series_67890")
    ///   - fullPlot: Original plot text
    /// - Returns: Cached or newly generated summary
    public func getCachedSummary(cacheKey: String, fullPlot: String) -> String? {
        if let cached = summaryCache[cacheKey] {
            logger.debug("Returning cached summary for \(cacheKey)")
            return cached
        }
        
        guard let summary = generateSummary(from: fullPlot) else {
            return nil
        }
        
        summaryCache[cacheKey] = summary
        logger.debug("Cached new summary for \(cacheKey)")
        return summary
    }
    
    /// Clears summary cache (call on low memory warning)
    public func clearCache() {
        let count = summaryCache.count
        summaryCache.removeAll()
        logger.info("Cleared \(count) cached summaries")
    }
}
