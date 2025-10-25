//
//  WatchlistsView.swift
//  StreamHaven
//
//  Created on October 25, 2025.
//

import SwiftUI

// MARK: - Main Watchlists View

struct WatchlistsView: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @EnvironmentObject var profileManager: ProfileManager
    
    @State private var showingCreateSheet = false
    @State private var selectedWatchlist: Watchlist?
    
    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if watchlistManager.watchlists.isEmpty {
                    EmptyWatchlistsView(showingCreateSheet: $showingCreateSheet)
                        .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(watchlistManager.watchlists, id: \.objectID) { watchlist in
                            NavigationLink(
                                destination: WatchlistDetailView(watchlist: watchlist)
                            ) {
                                WatchlistCard(watchlist: watchlist)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("My Watchlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateWatchlistSheet(isPresented: $showingCreateSheet)
                    .environmentObject(watchlistManager)
                    .environmentObject(profileManager)
            }
            .onAppear {
                if let profile = profileManager.currentProfile {
                    watchlistManager.loadWatchlists(for: profile)
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyWatchlistsView: View {
    @Binding var showingCreateSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Watchlists Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first watchlist to organize your favorite movies and shows")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { showingCreateSheet = true }) {
                Label("Create Watchlist", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Watchlist Card

struct WatchlistCard: View {
    let watchlist: Watchlist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 120)
                
                VStack {
                    Image(systemName: watchlist.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    Text("\(watchlist.itemCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            
            Text(watchlist.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text("\(watchlist.itemCount) item\(watchlist.itemCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Create Watchlist Sheet

struct CreateWatchlistSheet: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @EnvironmentObject var profileManager: ProfileManager
    
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var selectedIcon: String = "list.bullet"
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    let availableIcons = [
        "list.bullet", "star.fill", "heart.fill", "bookmark.fill",
        "film.fill", "tv.fill", "sparkles", "flame.fill",
        "eye.fill", "clock.fill", "calendar", "folder.fill"
    ]
    
    let iconColumns = [
        GridItem(.adaptive(minimum: 60), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Watchlist Name")) {
                    TextField("Enter name", text: $name)
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .white : .blue)
                                    .frame(width: 60, height: 60)
                                    .background(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createWatchlist()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createWatchlist() {
        guard let profile = profileManager.currentProfile else {
            errorMessage = "No profile selected"
            showError = true
            return
        }
        
        do {
            try watchlistManager.createWatchlist(
                name: name.trimmingCharacters(in: .whitespaces),
                icon: selectedIcon,
                profile: profile
            )
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Watchlist Detail View

struct WatchlistDetailView: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @Environment(\.managedObjectContext) private var context
    
    let watchlist: Watchlist
    
    @State private var items: [WatchlistItem] = []
    @State private var editMode: EditMode = .inactive
    @State private var showingRenameSheet = false
    @State private var showingIconPicker = false
    
    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if items.isEmpty {
                EmptyWatchlistDetailView()
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(items, id: \.objectID) { item in
                        WatchlistItemCard(item: item, watchlist: watchlist)
                            .environmentObject(watchlistManager)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(watchlist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingRenameSheet = true }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Button(action: { showingIconPicker = true }) {
                        Label("Change Icon", systemImage: "photo")
                    }
                    
                    if !items.isEmpty {
                        Button(role: .destructive, action: clearWatchlist) {
                            Label("Clear All", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameWatchlistSheet(watchlist: watchlist, isPresented: $showingRenameSheet)
                .environmentObject(watchlistManager)
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(watchlist: watchlist, isPresented: $showingIconPicker)
                .environmentObject(watchlistManager)
        }
        .onAppear {
            loadItems()
        }
        .onChange(of: watchlist.updatedAt) { _ in
            loadItems()
        }
    }
    
    private func loadItems() {
        items = watchlistManager.getItems(for: watchlist)
    }
    
    private func clearWatchlist() {
        do {
            try watchlistManager.clearWatchlist(watchlist)
            loadItems()
        } catch {
            print("Failed to clear watchlist: \(error)")
        }
    }
}

// MARK: - Empty Watchlist Detail

struct EmptyWatchlistDetailView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Empty Watchlist")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add movies, shows, or episodes from their detail pages")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Watchlist Item Card

struct WatchlistItemCard: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @Environment(\.managedObjectContext) private var context
    
    let item: WatchlistItem
    let watchlist: Watchlist
    
    @State private var title: String = ""
    @State private var posterURL: String?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let posterURL = posterURL, let url = URL(string: posterURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 220)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 220)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showDeleteConfirmation = true }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
                    Spacer()
                }
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            HStack {
                if let contentType = item.itemContentType {
                    Text(contentType.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            loadItemInfo()
        }
        .alert("Remove from Watchlist", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                removeItem()
            }
        } message: {
            Text("Are you sure you want to remove this item from the watchlist?")
        }
    }
    
    private func loadItemInfo() {
        title = item.getTitle(context: context)
        posterURL = item.getPosterURL(context: context)
    }
    
    private func removeItem() {
        do {
            try watchlistManager.removeFromWatchlist(item, watchlist: watchlist)
        } catch {
            print("Failed to remove item: \(error)")
        }
    }
}

// MARK: - Rename Watchlist Sheet

struct RenameWatchlistSheet: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @EnvironmentObject var profileManager: ProfileManager
    
    let watchlist: Watchlist
    @Binding var isPresented: Bool
    @State private var name: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Name")) {
                    TextField("Enter name", text: $name)
                }
            }
            .navigationTitle("Rename Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        renameWatchlist()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = watchlist.name
            }
        }
    }
    
    private func renameWatchlist() {
        guard let profile = profileManager.currentProfile else { return }
        
        do {
            try watchlistManager.renameWatchlist(
                watchlist,
                newName: name.trimmingCharacters(in: .whitespaces),
                profile: profile
            )
            isPresented = false
        } catch {
            print("Failed to rename watchlist: \(error)")
        }
    }
}

// MARK: - Icon Picker Sheet

struct IconPickerSheet: View {
    @EnvironmentObject var watchlistManager: WatchlistManager
    @EnvironmentObject var profileManager: ProfileManager
    
    let watchlist: Watchlist
    @Binding var isPresented: Bool
    @State private var selectedIcon: String = ""
    
    let availableIcons = [
        "list.bullet", "star.fill", "heart.fill", "bookmark.fill",
        "film.fill", "tv.fill", "sparkles", "flame.fill",
        "eye.fill", "clock.fill", "calendar", "folder.fill"
    ]
    
    let iconColumns = [
        GridItem(.adaptive(minimum: 60), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: iconColumns, spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: { selectedIcon = icon }) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(selectedIcon == icon ? .white : .blue)
                                .frame(width: 60, height: 60)
                                .background(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Change Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateIcon()
                    }
                }
            }
            .onAppear {
                selectedIcon = watchlist.icon
            }
        }
    }
    
    private func updateIcon() {
        guard let profile = profileManager.currentProfile else { return }
        
        do {
            try watchlistManager.updateIcon(watchlist, icon: selectedIcon, profile: profile)
            isPresented = false
        } catch {
            print("Failed to update icon: \(error)")
        }
    }
}
