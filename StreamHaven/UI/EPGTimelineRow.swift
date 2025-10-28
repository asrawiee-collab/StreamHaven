import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// A single channel row in the EPG timeline showing programs across time.
public struct EPGTimelineRow: View {
    let channel: Channel
    let startTime: Date
    let endTime: Date
    let timeSlotWidth: CGFloat
    let rowHeight: CGFloat
    
    @State private var programmes: [EPGEntry] = []
    
    public init(
        channel: Channel,
        startTime: Date,
        endTime: Date,
        timeSlotWidth: CGFloat = 200,
        rowHeight: CGFloat = 80
    ) {
        self.channel = channel
        self.startTime = startTime
        self.endTime = endTime
        self.timeSlotWidth = timeSlotWidth
        self.rowHeight = rowHeight
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Channel info column
            channelInfoView
                .frame(width: 150, height: rowHeight)
            
            // Programs timeline
            ZStack(alignment: .leading) {
                // Background time grid
                timeGridBackground
                
                // Program blocks
                programBlocks
                
                // Current time indicator
                if isCurrentTimeVisible {
                    currentTimeIndicator
                }
            }
            .frame(height: rowHeight)
        }
        .onAppear(perform: loadProgrammes)
        .onChange(of: startTime) { _ in loadProgrammes() }
        .onChange(of: endTime) { _ in loadProgrammes() }
    }
    
    private var channelInfoView: some View {
        HStack {
            // Channel logo or icon
            if let logoURL = channel.logoURL, let url = URL(string: logoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "tv")
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, height: 40)
            } else {
                Image(systemName: "tv")
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                // Now playing indicator
                if let nowProgramme = programmes.first(where: { isNowPlaying($0) }) {
                    Text(nowProgramme.title ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(platformSecondaryBackground)
    }
    
    private var timeGridBackground: some View {
        let totalDuration = endTime.timeIntervalSince(startTime)
        let slotCount = Int(totalDuration / 1800) // 30-minute slots
        
        return HStack(spacing: 0) {
            ForEach(0..<slotCount, id: \.self) { index in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: timeSlotWidth / 2)
                    .overlay(
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
    }
    
    private var programBlocks: some View {
        ForEach(programmes, id: \.objectID) { programme in
            programBlockView(for: programme)
        }
    }
    
    private func programBlockView(for programme: EPGEntry) -> some View {
        guard let progStart = programme.startTime,
              let progEnd = programme.endTime else {
            return AnyView(EmptyView())
        }
        
        // Calculate position and width
        let totalDuration = endTime.timeIntervalSince(startTime)
        let progStartOffset = max(0, progStart.timeIntervalSince(startTime))
        let progDuration = min(progEnd.timeIntervalSince(progStart), endTime.timeIntervalSince(max(progStart, startTime)))
        
        let xOffset = (progStartOffset / totalDuration) * timeSlotWidth * CGFloat(Int(totalDuration / 1800))
        let width = (progDuration / totalDuration) * timeSlotWidth * CGFloat(Int(totalDuration / 1800))
        
        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                Text(programme.title ?? "No Title")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                if let description = programme.descriptionText {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(progStart, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(4)
            .frame(width: max(50, width), height: rowHeight - 8, alignment: .topLeading)
            .background(isNowPlaying(programme) ? Color.accentColor.opacity(0.3) : Color.blue.opacity(0.2))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isNowPlaying(programme) ? Color.accentColor : Color.blue.opacity(0.5), lineWidth: 1)
            )
            .offset(x: xOffset)
        )
    }
    
    private var currentTimeIndicator: some View {
        let now = Date()
        let totalDuration = endTime.timeIntervalSince(startTime)
        let nowOffset = now.timeIntervalSince(startTime)
        let xOffset = (nowOffset / totalDuration) * timeSlotWidth * CGFloat(Int(totalDuration / 1800))
        
        return Rectangle()
            .fill(Color.red)
            .frame(width: 2, height: rowHeight)
            .offset(x: xOffset)
    }
    
    private var isCurrentTimeVisible: Bool {
        let now = Date()
        return startTime <= now && now <= endTime
    }
    
    private func isNowPlaying(_ programme: EPGEntry) -> Bool {
        guard let progStart = programme.startTime,
              let progEnd = programme.endTime else {
            return false
        }
        let now = Date()
        return progStart <= now && now < progEnd
    }
    
    private func loadProgrammes() {
        guard let context = channel.managedObjectContext else { return }
        
        programmes = EPGCacheManager.getProgrammes(
            for: channel,
            from: startTime,
            to: endTime,
            context: context
        )
    }

    private var platformSecondaryBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(NSColor.windowBackgroundColor)
        #else
        Color.gray.opacity(0.1)
        #endif
    }
}

#if DEBUG
struct EPGTimelineRow_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController(inMemory: true).container.viewContext
        let channel = Channel(context: context)
        channel.name = "HBO"
        channel.tvgID = "hbo"
        
        // Create sample programmes
        let now = Date()
        for i in 0..<6 {
            let entry = EPGEntry(context: context)
            entry.channel = channel
            entry.title = "Program \(i + 1)"
            entry.descriptionText = "Description for program \(i + 1)"
            entry.startTime = now.addingTimeInterval(TimeInterval(i * 1800))
            entry.endTime = now.addingTimeInterval(TimeInterval((i + 1) * 1800))
        }
        
        return EPGTimelineRow(
            channel: channel,
            startTime: now,
            endTime: now.addingTimeInterval(6 * 3600)
        )
        .environment(\.managedObjectContext, context)
        .previewLayout(.sizeThatFits)
    }
}
#endif
