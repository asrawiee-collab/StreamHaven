import CoreData
import Foundation
@testable import StreamHaven

enum TestCoreDataModelBuilder {
    static let sharedModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let profile = NSEntityDescription()
        profile.name = "Profile"
        profile.managedObjectClassName = NSStringFromClass(Profile.self)

        let favorite = NSEntityDescription()
        favorite.name = "Favorite"
        favorite.managedObjectClassName = NSStringFromClass(Favorite.self)

        let watchHistory = NSEntityDescription()
        watchHistory.name = "WatchHistory"
        watchHistory.managedObjectClassName = NSStringFromClass(WatchHistory.self)

        let movie = NSEntityDescription()
        movie.name = "Movie"
        movie.managedObjectClassName = NSStringFromClass(Movie.self)

        let series = NSEntityDescription()
        series.name = "Series"
        series.managedObjectClassName = NSStringFromClass(Series.self)

        let season = NSEntityDescription()
        season.name = "Season"
        season.managedObjectClassName = NSStringFromClass(Season.self)

        let episode = NSEntityDescription()
        episode.name = "Episode"
        episode.managedObjectClassName = NSStringFromClass(Episode.self)

        let channel = NSEntityDescription()
        channel.name = "Channel"
        channel.managedObjectClassName = NSStringFromClass(Channel.self)

        let channelVariant = NSEntityDescription()
        channelVariant.name = "ChannelVariant"
        channelVariant.managedObjectClassName = NSStringFromClass(ChannelVariant.self)

        let epgEntry = NSEntityDescription()
        epgEntry.name = "EPGEntry"
        epgEntry.managedObjectClassName = NSStringFromClass(EPGEntry.self)

        let download = NSEntityDescription()
        download.name = "Download"
        download.managedObjectClassName = NSStringFromClass(Download.self)

        let playlistSource = NSEntityDescription()
        playlistSource.name = "PlaylistSource"
        playlistSource.managedObjectClassName = NSStringFromClass(PlaylistSource.self)

        let profileFavorites = makeToManyRelationship("favorites", deleteRule: .cascadeDeleteRule)
        let profileWatchHistory = makeToManyRelationship("watchHistory", deleteRule: .cascadeDeleteRule)
        let profilePlaylistSources = makeToManyRelationship("playlistSources", deleteRule: .cascadeDeleteRule)

        let favoriteProfile = makeToOneRelationship("profile", deleteRule: .nullifyDeleteRule)
        let favoriteMovie = makeToOneRelationship("movie", deleteRule: .nullifyDeleteRule)
        let favoriteSeries = makeToOneRelationship("series", deleteRule: .nullifyDeleteRule)
        let favoriteChannel = makeToOneRelationship("channel", deleteRule: .nullifyDeleteRule)

        let watchHistoryProfile = makeToOneRelationship("profile", deleteRule: .nullifyDeleteRule)
        let watchHistoryMovie = makeToOneRelationship("movie", deleteRule: .nullifyDeleteRule)
        let watchHistoryEpisode = makeToOneRelationship("episode", deleteRule: .nullifyDeleteRule)

        let movieWatchHistory = makeToOneRelationship("watchHistory", deleteRule: .nullifyDeleteRule)
        let movieFavorite = makeToOneRelationship("favorite", deleteRule: .nullifyDeleteRule)

        let seriesSeasons = makeToManyRelationship("seasons", deleteRule: .cascadeDeleteRule)
        let seriesFavorite = makeToOneRelationship("favorite", deleteRule: .nullifyDeleteRule)

        let seasonEpisodes = makeToManyRelationship("episodes", deleteRule: .cascadeDeleteRule)
        let seasonSeries = makeToOneRelationship("series", deleteRule: .nullifyDeleteRule)

        let episodeSeason = makeToOneRelationship("season", deleteRule: .nullifyDeleteRule)
        let episodeWatchHistory = makeToOneRelationship("watchHistory", deleteRule: .nullifyDeleteRule)

        let channelFavorite = makeToOneRelationship("favorite", deleteRule: .nullifyDeleteRule)
        let channelVariants = makeToManyRelationship("variants", deleteRule: .cascadeDeleteRule)
        let channelEPGEntries = makeToManyRelationship("epgEntries", deleteRule: .cascadeDeleteRule)

        let channelVariantChannel = makeToOneRelationship("channel", deleteRule: .nullifyDeleteRule)
        let epgEntryChannel = makeToOneRelationship("channel", deleteRule: .nullifyDeleteRule)


        let downloadMovie = makeToOneRelationship("movie", deleteRule: .nullifyDeleteRule)
        let downloadEpisode = makeToOneRelationship("episode", deleteRule: .nullifyDeleteRule)



        let playlistSourceProfile = makeToOneRelationship("profile", deleteRule: .nullifyDeleteRule)

        profile.properties = [
            makeStringAttribute("name"),
            makeBoolAttribute("isAdult"),
            makeStringAttribute("cloudKitRecordName"),
            makeDateAttribute("modifiedAt"),
            makeStringAttribute("sourceMode"),
            profileFavorites,
            profileWatchHistory,
            profilePlaylistSources
        ]

        favorite.properties = [
            makeDateAttribute("favoritedDate"),
            makeStringAttribute("cloudKitRecordName"),
            makeDateAttribute("modifiedAt"),
            favoriteProfile,
            favoriteMovie,
            favoriteSeries,
            favoriteChannel
        ]

        watchHistory.properties = [
            makeFloatAttribute("progress"),
            makeDateAttribute("watchedDate"),
            makeStringAttribute("cloudKitRecordName"),
            makeDateAttribute("modifiedAt"),
            watchHistoryProfile,
            watchHistoryMovie,
            watchHistoryEpisode
        ]

        movie.properties = [
            makeStringAttribute("posterURL"),
            makeStringAttribute("rating"),
            makeDateAttribute("releaseDate"),
            makeStringAttribute("summary"),
            makeStringAttribute("genres"),
            makeStringAttribute("streamURL"),
            makeStringAttribute("previewURL"),
            makeStringAttribute("title"),
            makeStringAttribute("imdbID"),
            makeStringAttribute("stableID"),
            makeUUIDAttribute("sourceID"),
            makeInt16Attribute("releaseYearValue"),
            makeBoolAttribute("hasBeenWatched"),
            makeInt16Attribute("watchProgressPercent", isOptional: false, defaultValue: 0),
            makeBoolAttribute("isFavorite"),
            makeDateAttribute("lastWatchedDate"),
            movieWatchHistory,
            movieFavorite
        ]

        series.properties = [
            makeStringAttribute("posterURL"),
            makeStringAttribute("rating"),
            makeDateAttribute("releaseDate"),
            makeStringAttribute("summary"),
            makeStringAttribute("genres"),
            makeStringAttribute("title"),
            makeStringAttribute("previewURL"),
            makeStringAttribute("stableID"),
            makeUUIDAttribute("sourceID"),
            makeInt16Attribute("releaseYearValue"),
            makeInt32Attribute("totalEpisodeCount"),
            makeInt16Attribute("seasonCount", isOptional: false, defaultValue: 0),
            makeBoolAttribute("isFavorite"),
            makeInt32Attribute("unwatchedEpisodeCount"),
            seriesSeasons,
            seriesFavorite
        ]

        season.properties = [
            makeInt16Attribute("seasonNumber", isOptional: false, defaultValue: 0),
            makeStringAttribute("summary"),
            seasonEpisodes,
            seasonSeries
        ]

        episode.properties = [
            makeInt16Attribute("episodeNumber", isOptional: false, defaultValue: 0),
            makeStringAttribute("summary"),
            makeStringAttribute("title"),
            makeStringAttribute("streamURL"),
            makeDoubleAttribute("introStartTime"),
            makeDoubleAttribute("introEndTime"),
            makeDoubleAttribute("creditStartTime"),
            makeBoolAttribute("hasIntroData"),
            episodeSeason,
            episodeWatchHistory
        ]

        channel.properties = [
            makeStringAttribute("logoURL"),
            makeStringAttribute("name"),
            makeStringAttribute("tvgID"),
            makeStringAttribute("stableID"),
            makeUUIDAttribute("sourceID"),
            makeInt32Attribute("variantCount"),
            makeBoolAttribute("hasEPG"),
            makeStringAttribute("currentProgramTitle"),
            makeDateAttribute("epgLastUpdated"),
            channelFavorite,
            channelVariants,
            channelEPGEntries
        ]

        channelVariant.properties = [
            makeStringAttribute("name"),
            makeStringAttribute("streamURL"),
            makeUUIDAttribute("sourceID"),
            channelVariantChannel
        ]

        epgEntry.properties = [
            makeStringAttribute("category"),
            makeStringAttribute("descriptionText"),
            makeDateAttribute("endTime"),
            makeDateAttribute("startTime"),
            makeStringAttribute("title"),
            epgEntryChannel
        ]


        download.properties = [
            makeStringAttribute("streamURL"),
            makeStringAttribute("contentTitle"),
            makeStringAttribute("contentType"),
            makeStringAttribute("status"),
            makeFloatAttribute("progress"),
            makeStringAttribute("filePath"),
            makeInt64Attribute("fileSize"),
            makeDateAttribute("downloadedAt"),
            makeDateAttribute("expiresAt"),
            makeStringAttribute("thumbnailURL"),
            makeStringAttribute("imdbID"),
            downloadMovie,
            downloadEpisode
        ]


        download.properties = [
            makeStringAttribute("streamURL"),
            makeStringAttribute("contentTitle"),
            makeStringAttribute("contentType"),
            makeStringAttribute("status"),
            makeFloatAttribute("progress"),
            makeStringAttribute("filePath"),
            makeInt64Attribute("fileSize"),
            makeDateAttribute("downloadedAt"),
            makeDateAttribute("expiresAt"),
            makeStringAttribute("thumbnailURL"),
            makeStringAttribute("imdbID"),
            downloadMovie,
            downloadEpisode
        ]

        playlistSource.properties = [
            makeUUIDAttribute("sourceID"),
            makeStringAttribute("name"),
            makeStringAttribute("sourceType"),
            makeStringAttribute("url"),
            makeStringAttribute("username"),
            makeStringAttribute("password"),
            makeBoolAttribute("isActive"),
            makeInt32Attribute("displayOrder"),
            makeDateAttribute("createdAt"),
            makeDateAttribute("lastRefreshed"),
            makeStringAttribute("lastError"),
            makeStringAttribute("metadata"),
            playlistSourceProfile
        ]

        profileFavorites.destinationEntity = favorite
        favoriteProfile.destinationEntity = profile
        profileFavorites.inverseRelationship = favoriteProfile
        favoriteProfile.inverseRelationship = profileFavorites

        profileWatchHistory.destinationEntity = watchHistory
        watchHistoryProfile.destinationEntity = profile
        profileWatchHistory.inverseRelationship = watchHistoryProfile
        watchHistoryProfile.inverseRelationship = profileWatchHistory

        profilePlaylistSources.destinationEntity = playlistSource
        playlistSourceProfile.destinationEntity = profile
        profilePlaylistSources.inverseRelationship = playlistSourceProfile
        playlistSourceProfile.inverseRelationship = profilePlaylistSources

        favoriteMovie.destinationEntity = movie
        movieFavorite.destinationEntity = favorite
        favoriteMovie.inverseRelationship = movieFavorite
        movieFavorite.inverseRelationship = favoriteMovie

        favoriteSeries.destinationEntity = series
        seriesFavorite.destinationEntity = favorite
        favoriteSeries.inverseRelationship = seriesFavorite
        seriesFavorite.inverseRelationship = favoriteSeries

        favoriteChannel.destinationEntity = channel
        channelFavorite.destinationEntity = favorite
        favoriteChannel.inverseRelationship = channelFavorite
        channelFavorite.inverseRelationship = favoriteChannel

        watchHistoryMovie.destinationEntity = movie
        movieWatchHistory.destinationEntity = watchHistory
        watchHistoryMovie.inverseRelationship = movieWatchHistory
        movieWatchHistory.inverseRelationship = watchHistoryMovie

        watchHistoryEpisode.destinationEntity = episode
        episodeWatchHistory.destinationEntity = watchHistory
        watchHistoryEpisode.inverseRelationship = episodeWatchHistory
        episodeWatchHistory.inverseRelationship = watchHistoryEpisode

        seriesSeasons.destinationEntity = season
        seasonSeries.destinationEntity = series
        seriesSeasons.inverseRelationship = seasonSeries
        seasonSeries.inverseRelationship = seriesSeasons

        seasonEpisodes.destinationEntity = episode
        episodeSeason.destinationEntity = season
        seasonEpisodes.inverseRelationship = episodeSeason
        episodeSeason.inverseRelationship = seasonEpisodes

        channelVariants.destinationEntity = channelVariant
        channelVariantChannel.destinationEntity = channel
        channelVariants.inverseRelationship = channelVariantChannel
        channelVariantChannel.inverseRelationship = channelVariants

        channelEPGEntries.destinationEntity = epgEntry
        epgEntryChannel.destinationEntity = channel
        channelEPGEntries.inverseRelationship = epgEntryChannel
        epgEntryChannel.inverseRelationship = channelEPGEntries

        downloadMovie.destinationEntity = movie
        downloadEpisode.destinationEntity = episode


        downloadMovie.destinationEntity = movie
        downloadEpisode.destinationEntity = episode


        model.entities = [
            profile,
            favorite,
            watchHistory,
            movie,
            series,
            season,
            episode,
            channel,
            channelVariant,
            epgEntry,
            download,
            playlistSource
        ]

        return model
    }()

    private static func makeStringAttribute(_ name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = true
        return attribute
    }

    private static func makeDateAttribute(_ name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .dateAttributeType
        attribute.isOptional = true
        return attribute
    }

    private static func makeBoolAttribute(_ name: String, defaultValue: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .booleanAttributeType
        attribute.isOptional = false
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func makeFloatAttribute(_ name: String, defaultValue: Float = 0.0) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .floatAttributeType
        attribute.isOptional = false
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func makeDoubleAttribute(_ name: String, defaultValue: Double = 0.0) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .doubleAttributeType
        attribute.isOptional = false
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func makeInt16Attribute(_ name: String, isOptional: Bool = true, defaultValue: Int16 = 0) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .integer16AttributeType
        attribute.isOptional = isOptional
        if !isOptional {
            attribute.defaultValue = defaultValue
        }
        return attribute
    }

    private static func makeInt32Attribute(_ name: String, defaultValue: Int32 = 0) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .integer32AttributeType
        attribute.isOptional = false
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func makeUUIDAttribute(_ name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .UUIDAttributeType
        attribute.isOptional = true
        return attribute
    }

    private static func makeToOneRelationship(_ name: String, deleteRule: NSDeleteRule, isOptional: Bool = true) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.deleteRule = deleteRule
        relationship.isOptional = isOptional
        relationship.minCount = isOptional ? 0 : 1
        relationship.maxCount = 1
        return relationship
    }

    private static func makeToManyRelationship(_ name: String, deleteRule: NSDeleteRule, isOrdered: Bool = false) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.deleteRule = deleteRule
        relationship.isOptional = true
        relationship.minCount = 0
        relationship.maxCount = 0
        relationship.isOrdered = isOrdered
        return relationship
    }

    private static func makeInt64Attribute(_ name: String, defaultValue: Int64 = 0) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .integer64AttributeType
        attribute.isOptional = false
        attribute.defaultValue = defaultValue
        return attribute
    }
}
