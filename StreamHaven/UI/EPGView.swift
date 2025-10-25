import SwiftUI
import CoreData

/// A comprehensive Electronic Program Guide (EPG) view displaying a timeline grid of programs.
@MainActor
public struct EPGView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Channel.name, ascending: true)],
        animation: .default
    )
    private var channels: FetchedResults<Channel>
    
    @State private var currentDate = Date()
    @State private var selectedTimeSlot = Date()
    @State private var scrollOffset: CGFloat = 0
    
    private let timeSlotWidth: CGFloat = 200
    private let channelRowHeight: CGFloat = 80
    private let hoursToShow: Int = 6
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with time navigation
                headerView
                
                Divider()
                
                // EPG Grid
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        // Time slots header
                        timeSlotHeader
                        
                        // Channel rows with programs
                        ForEach(channels) { channel in
                            EPGTimelineRow(
                                channel: channel,
                                startTime: selectedTimeSlot,
                                endTime: selectedTimeSlot.addingTimeInterval(TimeInterval(hoursToShow * 3600)),
                                timeSlotWidth: timeSlotWidth,
                                rowHeight: channelRowHeight
                            )
                            
                            Divider()
                        }
                    }
                }
            }
        }
        .navigationTitle("TV Guide")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // Start at current time, rounded to nearest 30 minutes
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
            if let hour = components.hour, let minute = components.minute {
                let roundedMinute = (minute / 30) * 30
                if let roundedDate = calendar.date(from: DateComponents(
                    year: components.year,
                    month: components.month,
                    day: components.day,
                    hour: hour,
                    minute: roundedMinute
                )) {
                    selectedTimeSlot = roundedDate
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: moveToPreviousDay) {
                Label("Previous Day", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(selectedTimeSlot, style: .date)
                    .font(.headline)
                Text(selectedTimeSlot, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: moveToNextDay) {
                Label("Next Day", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            
            Button(action: moveToNow) {
                Text("Now")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var timeSlotHeader: some View {
        HStack(spacing: 0) {
            // Channel column spacer
            Color.clear
                .frame(width: 150, height: 40)
            
            // Time slots
            ForEach(0..<hoursToShow * 2, id: \.self) { index in
                let time = selectedTimeSlot.addingTimeInterval(TimeInterval(index * 1800)) // 30 min intervals
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(time, style: .time)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    if Calendar.current.component(.minute, from: time) == 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 2)
                    }
                }
                .frame(width: timeSlotWidth / 2, height: 40, alignment: .leading)
                .background(isCurrentTime(time) ? Color.accentColor.opacity(0.1) : Color.clear)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private func isCurrentTime(_ time: Date) -> Bool {
        let now = Date()
        return time <= now && now < time.addingTimeInterval(1800) // Within 30 min slot
    }
    
    private func moveToPreviousDay() {
        selectedTimeSlot = Calendar.current.date(byAdding: .day, value: -1, to: selectedTimeSlot) ?? selectedTimeSlot
    }
    
    private func moveToNextDay() {
        selectedTimeSlot = Calendar.current.date(byAdding: .day, value: 1, to: selectedTimeSlot) ?? selectedTimeSlot
    }
    
    private func moveToNow() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        if let hour = components.hour, let minute = components.minute {
            let roundedMinute = (minute / 30) * 30
            if let roundedDate = calendar.date(from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: hour,
                minute: roundedMinute
            )) {
                selectedTimeSlot = roundedDate
            }
        }
    }
}

#if DEBUG
struct EPGView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EPGView()
                .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
        }
    }
}
#endif
