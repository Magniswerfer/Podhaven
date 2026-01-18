# iOS Application Feature Implementation Plan

This document outlines a phased plan to implement features described in
`Description_of_webapp.md` into the native Podhaven iOS application. The plan is
structured into milestones, assuming the current project structure and
foundational features (basic playback, subscription) are already in place.

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Database**: SwiftData
- **Concurrency**: Swift Concurrency (Async/Await)
- **Architecture**: As described in `README.md` (Service-oriented,
  Protocol-based API client)

## Design Principles

- **UI Aesthetic**: All new UI components and views should adhere to the
  existing "Liquid Glass" design. This includes the consistent use of materials
  (e.g., `.thinMaterial`), background blurs, vibrancy, and soft shadows to
  maintain a cohesive, modern, and translucent interface.

---

## Milestone 1: Robust Sync & Advanced Playback

This phase focuses on making the synchronization more robust and adding advanced
playback features from the web app that are currently missing in the iOS client.

### 1.1. Enhance `AudioPlayerService`

- [x] Implement "Smart Resume": Automatically continue playback from the last
      position. Provide a "Start Over" option via a context menu on long-press.
- [x] Implement a sleep timer accessible from the `NowPlayingView`.

### 1.2. Refine `PodcastDetailView`

- [x] Add filtering controls to the episode list (All, Unplayed, In Progress)
      based on `Episode.isPlayed` and `Episode.playbackPosition`.
- [x] Add sorting controls (Newest, Oldest) based on `Episode.publishDate`.
- [x] Implement UI to manage per-podcast settings by calling
      `PATCH /api/podcasts/{id}/settings`.

---
## Milestone 2: Dashboard & Statistics
This phase introduces a central "home" screen that provides an at-a-glance overview of the user's listening habits.
### 2.1. API Client Implementation
- [x] Add `getDashboardStats()` method to `PodcastServiceAPIClient` to call `GET /api/stats/dashboard`.
- [x] Add `getNewEpisodes()` method to `PodcastServiceAPIClient` that calls `GET /api/episodes` with appropriate date and sorting filters.
### 2.2. Dashboard View
- [x] Create a new `DashboardView.swift` and add it as the primary tab in the app.
- [x] Design and implement a view to display key stats from the API: Total Listening Time, Completed Episodes, etc.
- [x] Add a "Recently Played" section that shows the last few episodes with progress.
- [x] Add a "New Episodes" section that lists new episodes from all subscriptions.
---

## Milestone 3: Queue & Playlist Management

This phase implements the powerful organization features for managing what to
listen to next.

### 3.1. Queue Management

- [ ] **API**: Implement all Queue endpoints in `PodcastServiceAPIClient`:
      `GET`, `POST`, `PUT`, `DELETE /api/queue`, `DELETE /api/queue/{id}`, and
      `POST /api/queue/play-next`.
- [ ] **UI**: Create a `QueueView.swift` accessible from the `NowPlayingView` or
      a main tab.
- [ ] **Functionality**:
  - [ ] Display the user's queue.
  - [ ] Implement drag-and-drop reordering which calls `PUT /api/queue`.
  - [ ] Add "Add to Play Next" and "Add to Queue" actions to the context menu in
        `EpisodeRow`.
  - [ ] Implement a "Clear Queue" button.

### 3.2. Playlist Management

- [ ] **API**: Implement all Playlist endpoints in `PodcastServiceAPIClient`
      (`GET`, `POST`, `PUT`, `DELETE` for both playlists and playlist items).
- [ ] **UI**:
  - [ ] Create a `PlaylistsView.swift` to list all user-created playlists.
  - [ ] Create a `PlaylistDetailView.swift` to show items within a playlist.
- [ ] **Functionality**:
  - [ ] Allow users to create, edit, and delete playlists.
  - [ ] Add an "Add to Playlist" action to the `EpisodeRow` context menu,
        presenting a list of playlists.
  - [ ] Allow adding an entire podcast to a playlist from `PodcastDetailView`.
  - [ ] Implement drag-and-drop reordering for items within
        `PlaylistDetailView`.

---
## Milestone 4: Settings & Profile Management

This phase builds out the user settings area to match the web app's comprehensive options.

### 4.1. API Client Implementation
- [ ] Implement `getProfile()`, `updateProfile()`, `changePassword()`, `regenerateApiKey()`, and `resetSubscriptions()` methods in `PodcastServiceAPIClient`.

### 4.2. Enhance `SettingsView`
- [ ] Display the user's email and a masked API key.
- [ ] Add buttons to copy the full API key and to regenerate it (with a confirmation alert).
- [ ] Create a form to manage default settings (episode filter, sort order, date format) that calls `PATCH /api/profile`.
- [ ] Create a "Change Password" view/modal.
- [ ] Add a "Danger Zone" section with a "Reset All Data" button that calls `POST /api/profile/reset-subscriptions` after a confirmation dialog.
---

## Milestone 5: UI/UX Polish & Advanced Features

This final phase focuses on refining the user experience and adding advanced
statistical features.

### 5.1. Statistics

- [ ] **API**: Implement `getWrappedStats(year:)` method in
      `PodcastServiceAPIClient` to call `GET /api/stats/wrapped`.
- [ ] **UI**: Create a `StatsView.swift` (or "Wrapped" view) to present yearly
      listening data, including top podcasts and total listening time.

### 5.2. UI/UX Refinements

- [ ] Implement global loading states (e.g., a spinner during a full sync) and
      error notifications (e.g., toast messages for network errors).
- [ ] Review all views for consistent design and layout.
- [ ] Ensure all destructive actions (Unsubscribe, Delete Playlist, Reset Data)
      use a confirmation alert (`.alert`).
- [ ] Add a download manager view to show active and completed downloads.
- [ ] In `EpisodeRow`, improve the download button to handle the full lifecycle:
  - `arrow.down.circle`: Tap to start download.
  - `stop.circle`: Show progress, tap to cancel.
  - `checkmark.circle.fill`: Indicates downloaded, tap to delete local file.
  - `exclamationmark.circle`: Tap to retry failed download.

---
