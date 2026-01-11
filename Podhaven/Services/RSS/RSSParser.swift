import Foundation

/// Protocol for RSS feed parsing
protocol RSSParserProtocol: Sendable {
    func parseFeed(from url: URL) async throws -> ParsedFeed
    func parseFeed(from data: Data) throws -> ParsedFeed
}

/// Parsed podcast feed data
struct ParsedFeed: Sendable {
    let title: String
    let author: String?
    let description: String?
    let artworkURL: String?
    let link: String?
    let language: String?
    let categories: [String]
    let episodes: [ParsedEpisode]
}

/// Parsed episode data
struct ParsedEpisode: Sendable {
    let guid: String
    let title: String
    let description: String?
    let audioURL: String
    let publishDate: Date?
    let duration: TimeInterval?
    let fileSize: Int64?
    let episodeNumber: Int?
    let seasonNumber: Int?
    let artworkURL: String?
}

/// RSS Feed Parser using XMLParser
final class RSSParser: NSObject, RSSParserProtocol, @unchecked Sendable {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func parseFeed(from url: URL) async throws -> ParsedFeed {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw RSSParserError.networkError
        }
        
        return try parseFeed(from: data)
    }
    
    func parseFeed(from data: Data) throws -> ParsedFeed {
        let delegate = RSSParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        
        guard parser.parse() else {
            throw RSSParserError.parsingFailed(parser.parserError)
        }
        
        guard let feed = delegate.feed else {
            throw RSSParserError.invalidFeed
        }
        
        return feed
    }
}

// MARK: - Parser Delegate

private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    var feed: ParsedFeed?
    
    private var currentElement = ""
    private var currentText = ""
    
    // Feed level
    private var feedTitle = ""
    private var feedAuthor: String?
    private var feedDescription: String?
    private var feedArtworkURL: String?
    private var feedLink: String?
    private var feedLanguage: String?
    private var feedCategories: [String] = []
    
    // Episode level
    private var episodes: [ParsedEpisode] = []
    private var isInItem = false
    private var itemGuid: String?
    private var itemTitle = ""
    private var itemDescription: String?
    private var itemAudioURL: String?
    private var itemPubDate: Date?
    private var itemDuration: TimeInterval?
    private var itemFileSize: Int64?
    private var itemEpisodeNumber: Int?
    private var itemSeasonNumber: Int?
    private var itemArtworkURL: String?
    
    // MARK: - XMLParserDelegate
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        
        switch elementName {
        case "item":
            isInItem = true
            resetItemState()
            
        case "enclosure":
            if isInItem {
                itemAudioURL = attributeDict["url"]
                if let length = attributeDict["length"] {
                    itemFileSize = Int64(length)
                }
            }
            
        case "itunes:image":
            if let href = attributeDict["href"] {
                if isInItem {
                    itemArtworkURL = href
                } else {
                    feedArtworkURL = href
                }
            }
            
        case "itunes:category":
            if let category = attributeDict["text"] {
                feedCategories.append(category)
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isInItem {
            handleItemElement(elementName, text: text)
        } else {
            handleFeedElement(elementName, text: text)
        }
        
        if elementName == "item" {
            finalizeCurrentItem()
            isInItem = false
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        feed = ParsedFeed(
            title: feedTitle,
            author: feedAuthor,
            description: feedDescription,
            artworkURL: feedArtworkURL,
            link: feedLink,
            language: feedLanguage,
            categories: feedCategories,
            episodes: episodes
        )
    }
    
    // MARK: - Private Helpers
    
    private func handleFeedElement(_ element: String, text: String) {
        switch element {
        case "title":
            if feedTitle.isEmpty { feedTitle = text }
        case "itunes:author", "author":
            feedAuthor = text
        case "description", "itunes:summary":
            if feedDescription == nil { feedDescription = text }
        case "link":
            feedLink = text
        case "language":
            feedLanguage = text
        default:
            break
        }
    }
    
    private func handleItemElement(_ element: String, text: String) {
        switch element {
        case "guid":
            itemGuid = text
        case "title":
            itemTitle = text
        case "description", "itunes:summary", "content:encoded":
            if itemDescription == nil || element == "content:encoded" {
                itemDescription = text.strippingHTML()
            }
        case "pubDate":
            itemPubDate = parseDate(text)
        case "itunes:duration":
            itemDuration = parseDuration(text)
        case "itunes:episode":
            itemEpisodeNumber = Int(text)
        case "itunes:season":
            itemSeasonNumber = Int(text)
        default:
            break
        }
    }
    
    private func resetItemState() {
        itemGuid = nil
        itemTitle = ""
        itemDescription = nil
        itemAudioURL = nil
        itemPubDate = nil
        itemDuration = nil
        itemFileSize = nil
        itemEpisodeNumber = nil
        itemSeasonNumber = nil
        itemArtworkURL = nil
    }
    
    private func finalizeCurrentItem() {
        guard let audioURL = itemAudioURL, !itemTitle.isEmpty else { return }
        
        let episode = ParsedEpisode(
            guid: itemGuid ?? audioURL,
            title: itemTitle,
            description: itemDescription,
            audioURL: audioURL,
            publishDate: itemPubDate,
            duration: itemDuration,
            fileSize: itemFileSize,
            episodeNumber: itemEpisodeNumber,
            seasonNumber: itemSeasonNumber,
            artworkURL: itemArtworkURL
        )
        episodes.append(episode)
    }
    
    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return ISO8601DateFormatter().date(from: string)
    }
    
    private func parseDuration(_ string: String) -> TimeInterval? {
        // Handle HH:MM:SS, MM:SS, or just seconds
        let components = string.split(separator: ":").compactMap { Int($0) }
        
        switch components.count {
        case 1:
            return TimeInterval(components[0])
        case 2:
            return TimeInterval(components[0] * 60 + components[1])
        case 3:
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        default:
            return nil
        }
    }
}

// MARK: - Errors

enum RSSParserError: LocalizedError {
    case networkError
    case parsingFailed(Error?)
    case invalidFeed
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Failed to download feed"
        case .parsingFailed(let error):
            return "Failed to parse feed: \(error?.localizedDescription ?? "Unknown error")"
        case .invalidFeed:
            return "Invalid podcast feed"
        }
    }
}

// MARK: - String Extensions

private extension String {
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        
        // Fallback: simple regex strip
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
