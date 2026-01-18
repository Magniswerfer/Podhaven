# API Documentation

Complete API reference for iOS app integration and other external clients.

## Table of Contents

- [Authentication](#authentication)
- [Profile](#profile)
- [Podcasts](#podcasts)
- [Episodes](#episodes)
- [Progress](#progress)
- [Queue](#queue)
- [Playlists](#playlists)
- [Stats](#stats)
- [Cron Jobs (Internal)](#cron-jobs-internal)

## Authentication

All API endpoints (except authentication endpoints) require authentication via API key.
Include the API key in the Authorization header:

```
Authorization: Bearer <api_key>
```

### POST /api/auth/register

Create a new user account and receive an API key.

**Authentication:** Not required

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "optional_password" // Optional, min 8 characters
}
```

**Response (201):**

```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "apiKey": "your_api_key_here"
  }
}
```

**Error Responses:**
- **400:** Invalid request data
- **409:** User with this email already exists

---

### POST /api/auth/login

Authenticate and receive your API key.

**Authentication:** Not required

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "optional_password" // Optional if account has no password
}
```

**Response (200):**

```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "apiKey": "your_api_key_here"
  }
}
```

**Error Responses:**
- **400:** Invalid request data
- **401:** Invalid email or password

---

## Profile

### GET /api/profile

Get the current user's profile information.

**Authentication:** Required

**Response (200):**

```json
{
  "id": "uuid",
  "email": "user@example.com",
  "apiKey": "abc12345****wxyz",
  "fullApiKey": "abc12345...full_key_here...wxyz",
  "defaultSettings": {
    "episodeFilter": "all",
    "episodeSort": "newest",
    "dateFormat": "MM/DD/YYYY"
  },
  "createdAt": "2025-01-01T00:00:00Z",
  "hasPassword": true
}
```

**Note:** `apiKey` is masked for display, `fullApiKey` contains the complete key for copying.

---

### PATCH /api/profile

Update user profile settings (default episode filter, sort, and date format).

**Authentication:** Required

**Request Body:**

```json
{
  "defaultSettings": {
    "episodeFilter": "all" | "unplayed" | "uncompleted" | "in-progress", // Optional
    "episodeSort": "newest" | "oldest", // Optional
    "dateFormat": "MM/DD/YYYY" | "DD/MM/YYYY" | "YYYY-MM-DD" // Optional
  }
}
```

**Response (200):**

```json
{
  "success": true,
  "defaultSettings": {
    "episodeFilter": "unplayed",
    "episodeSort": "newest",
    "dateFormat": "DD/MM/YYYY"
  }
}
```

**Error Responses:**
- **400:** Invalid request data

---

### POST /api/profile/change-password

Change the user's password.

**Authentication:** Required

**Request Body:**

```json
{
  "currentPassword": "old_password", // Required if user already has a password
  "newPassword": "new_password_min_8_chars"
}
```

**Response (200):**

```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

**Error Responses:**
- **400:** Invalid request data / Current password is required
- **401:** Current password is incorrect

---

### POST /api/profile/regenerate-api-key

Generate a new API key for the user. This invalidates the old API key.

**Authentication:** Required

**Response (200):**

```json
{
  "success": true,
  "apiKey": "new_api_key_here",
  "message": "API key regenerated successfully. Please update any applications using the old key."
}
```

**Warning:** After calling this endpoint, you must use the new API key for all subsequent requests. The old key will no longer work.

---

### POST /api/profile/reset-subscriptions

Delete all subscriptions, queue items, playlists, favorites, and listening history for the user. This action cannot be undone.

**Authentication:** Required

**Response (200):**

```json
{
  "success": true,
  "message": "All subscriptions and related data have been reset",
  "deleted": {
    "subscriptions": 5,
    "queue": 10,
    "history": 100,
    "favorites": 20,
    "playlists": 3,
    "playlistItems": 25
  }
}
```

**Warning:** This is a destructive operation that permanently deletes all user data except the account itself.

---

## Podcasts

### GET /api/podcasts

Get all podcasts the user is subscribed to.

**Authentication:** Required

**Response (200):**

```json
{
  "podcasts": [
    {
      "id": "uuid",
      "title": "Podcast Title",
      "description": "Description",
      "feedUrl": "https://...",
      "artworkUrl": "https://...",
      "author": "Author Name",
      "subscribedAt": "2025-01-01T00:00:00Z",
      "episodeCount": 100,
      "customSettings": {}
    }
  ]
}
```

---

### POST /api/podcasts/subscribe

Subscribe to a podcast by RSS feed URL.

**Authentication:** Required

**Request Body:**

```json
{
  "feedUrl": "https://example.com/feed.xml"
}
```

**Response (201):**

```json
{
  "podcast": {
    "id": "uuid",
    "title": "Podcast Title",
    "subscribedAt": "2025-01-01T00:00:00Z",
    "episodeCount": 100
  }
}
```

**Error Responses:**
- **400:** Invalid request data
- **409:** Already subscribed to this podcast

---

### DELETE /api/podcasts/{id}

Unsubscribe from a podcast.

**Authentication:** Required

**Response (200):**

```json
{
  "success": true
}
```

**Error Responses:**
- **404:** Subscription not found

---

### GET /api/podcasts/search

Search for podcasts on iTunes.

**Authentication:** Required

**Query Parameters:**
- **q** (required): Search query
- **limit** (optional): Results limit (1-200, default: 50)

**Example:**

```
GET /api/podcasts/search?q=tech&limit=20
```

**Response (200):**

```json
{
  "results": [
    {
      "title": "Podcast Title",
      "feedUrl": "https://...",
      "artworkUrl": "https://...",
      "author": "Author Name"
    }
  ],
  "count": 20
}
```

---

### POST /api/podcasts/{id}/refresh

Force refresh a podcast feed to fetch new episodes.

**Authentication:** Required

**Response (200):**

```json
{
  "success": true,
  "episodesAdded": 5
}
```

**Error Responses:**
- **404:** Subscription not found
- **500:** Failed to refresh feed

---

### PATCH /api/podcasts/{id}/settings

Update subscription-specific settings (episode filter and sort preferences).

**Authentication:** Required

**Request Body:**

```json
{
  "episodeFilter": "all" | "unplayed" | "uncompleted" | "in-progress", // Optional
  "episodeSort": "newest" | "oldest" // Optional
}
```

**Response (200):**

```json
{
  "success": true,
  "customSettings": {
    "episodeFilter": "unplayed",
    "episodeSort": "newest"
  }
}
```

---

## Episodes

### GET /api/episodes

Get episodes from subscribed podcasts with filtering and pagination.

**Authentication:** Required

**Query Parameters:**
- **podcastId** (optional): Filter by podcast UUID
- **limit** (optional): Results per page (1-100, default: 20)
- **offset** (optional): Pagination offset (default: 0)
- **fromDate** (optional): ISO datetime string - filter episodes published after
- **toDate** (optional): ISO datetime string - filter episodes published before
- **filter** (optional): "all" | "unplayed" | "uncompleted" | "in-progress" (default: "all")
- **sort** (optional): "newest" | "oldest" (default: "newest")

**Example:**

```
GET /api/episodes?podcastId=uuid&limit=50&filter=unplayed&sort=newest
```

**Response (200):**

```json
{
  "episodes": [
    {
      "id": "uuid",
      "title": "Episode Title",
      "description": "Description",
      "audioUrl": "https://...",
      "publishedAt": "2025-01-01T00:00:00Z",
      "durationSeconds": 3600,
      "artworkUrl": "https://...",
      "podcast": {
        "id": "uuid",
        "title": "Podcast Title",
        "artworkUrl": "https://..."
      },
      "progress": {
        "positionSeconds": 1200,
        "durationSeconds": 3600,
        "completed": false
      }
    }
  ],
  "total": 100,
  "limit": 20,
  "offset": 0
}
```

**Note:** The `progress` field will be `null` if the episode hasn't been started.

---

### GET /api/episodes/{id}

Get detailed information about a specific episode.

**Authentication:** Required

**Response (200):**

```json
{
  "id": "uuid",
  "title": "Episode Title",
  "description": "Full description",
  "audioUrl": "https://...",
  "publishedAt": "2025-01-01T00:00:00Z",
  "durationSeconds": 3600,
  "artworkUrl": "https://...",
  "podcast": {
    "id": "uuid",
    "title": "Podcast Title",
    "artworkUrl": "https://..."
  },
  "progress": {
    "positionSeconds": 1200,
    "durationSeconds": 3600,
    "completed": false,
    "lastUpdatedAt": "2025-01-01T00:00:00Z"
  }
}
```

**Error Responses:**
- **403:** Not subscribed to this podcast
- **404:** Episode not found

---

## Progress

### GET /api/progress

Get all listening progress records.

**Authentication:** Required

**Response (200):**

```json
{
  "progress": [
    {
      "id": "uuid",
      "episodeId": "uuid",
      "positionSeconds": 1200,
      "durationSeconds": 3600,
      "completed": false,
      "lastUpdatedAt": "2025-01-01T00:00:00Z",
      "episode": {
        "id": "uuid",
        "title": "Episode Title",
        "podcast": {
          "id": "uuid",
          "title": "Podcast Title"
        }
      }
    }
  ]
}
```

---

### POST /api/progress

Bulk update listening progress for multiple episodes (up to 100 at once).

**Authentication:** Required

**Request Body:**

```json
{
  "updates": [
    {
      "episodeId": "uuid",
      "positionSeconds": 1200,
      "durationSeconds": 3600, // Optional
      "completed": false // Optional
    }
  ]
}
```

**Response (200):**

```json
{
  "results": [
    {
      "episodeId": "uuid",
      "success": true,
      "progress": { ... }
    },
    {
      "episodeId": "uuid",
      "success": false,
      "error": "Episode not found"
    }
  ]
}
```

---

### PUT /api/progress/{episode_id}

Update listening progress for a single episode.

**Authentication:** Required

**Request Body:**

```json
{
  "positionSeconds": 1200,
  "durationSeconds": 3600,
  "completed": false
}
```

**Response (200):**

```json
{
  "progress": {
    "id": "uuid",
    "episodeId": "uuid",
    "positionSeconds": 1200,
    "durationSeconds": 3600,
    "completed": false,
    "lastUpdatedAt": "2025-01-01T00:00:00Z"
  }
}
```

**Error Responses:**
- **400:** Invalid request data
- **403:** Not subscribed to this podcast
- **404:** Episode not found

---

## Queue

### GET /api/queue

Get the user's listening queue, ordered by position.

**Authentication:** Required

**Response (200):**

```json
{
  "queue": [
    {
      "id": "uuid",
      "episodeId": "uuid",
      "position": 0,
      "episode": {
        "id": "uuid",
        "title": "Episode Title",
        "audioUrl": "https://...",
        "podcast": {
          "id": "uuid",
          "title": "Podcast Title"
        },
        "progress": {
          "positionSeconds": 0,
          "completed": false
        }
      }
    }
  ]
}
```

---

### POST /api/queue

Add an episode to the end of the queue.

**Authentication:** Required

**Request Body:**

```json
{
  "episodeId": "uuid"
}
```

**Response (201):**

```json
{
  "queueItem": { ... },
  "queue": [ ... ]
}
```

**Error Responses:**
- **400:** Invalid request data
- **403:** Not subscribed to this podcast
- **404:** Episode not found
- **409:** Episode already in queue

---

### PUT /api/queue

Reorder queue items by updating their positions.

**Authentication:** Required

**Request Body:**

```json
{
  "items": [
    {
      "id": "queue_item_uuid",
      "position": 0
    },
    {
      "id": "queue_item_uuid",
      "position": 1
    }
  ]
}
```

**Response (200):**

```json
{
  "queue": [ ... ]
}
```

---

### DELETE /api/queue

Clear all items from the queue. Optionally preserve the currently playing episode.

**Authentication:** Required

**Query Parameters:**
- **currentEpisodeId** (optional): Preserve this episode in the queue

**Example:**

```
DELETE /api/queue?currentEpisodeId=uuid
```

**Response (200):**

```json
{
  "success": true,
  "queue": [ ... ]
}
```

---

### DELETE /api/queue/{id}

Remove a specific item from the queue.

**Authentication:** Required

**Response (200):**

```json
{
  "success": true
}
```

**Error Responses:**
- **403:** Unauthorized (not your queue item)
- **404:** Queue item not found

---

### POST /api/queue/play-next

Add an episode to play immediately after the currently playing episode.

**Authentication:** Required

**Request Body:**

```json
{
  "episodeId": "uuid",
  "currentEpisodeId": "uuid"
}
```

**Response (201):**

```json
{
  "queueItem": { ... },
  "queue": [ ... ]
}
```

---

## Playlists

### GET /api/playlists

Get all playlists created by the user.

**Authentication:** Required

**Response (200):**

```json
{
  "playlists": [
    {
      "id": "uuid",
      "name": "My Playlist",
      "description": "Description",
      "createdAt": "2025-01-01T00:00:00Z",
      "updatedAt": "2025-01-01T00:00:00Z",
      "_count": {
        "items": 10
      }
    }
  ]
}
```

---

### POST /api/playlists

Create a new playlist.

**Authentication:** Required

**Request Body:**

```json
{
  "name": "My Playlist",
  "description": "Optional description"
}
```

**Response (201):**

```json
{
  "playlist": {
    "id": "uuid",
    "name": "My Playlist",
    "description": "Description",
    "_count": {
      "items": 0
    }
  }
}
```

---

### GET /api/playlists/{id}

Get a playlist with all its items.

**Authentication:** Required

**Response (200):**

```json
{
  "playlist": {
    "id": "uuid",
    "name": "My Playlist",
    "items": [
      {
        "id": "uuid",
        "position": 0,
        "podcast": { ... },
        "episode": {
          "id": "uuid",
          "title": "Episode Title",
          "podcast": { ... }
        }
      }
    ]
  }
}
```

**Error Responses:**
- **403:** Forbidden (not your playlist)
- **404:** Playlist not found

---

### PUT /api/playlists/{id}

Update playlist name and/or description.

**Authentication:** Required

**Request Body:**

```json
{
  "name": "Updated Name",
  "description": "Updated description"
}
```

**Response (200):**

```json
{
  "playlist": {
    "id": "uuid",
    "name": "Updated Name",
    "description": "Updated description",
    "_count": {
      "items": 10
    }
  }
}
```

---

### DELETE /api/playlists/{id}

Delete a playlist and all its items.

**Authentication:** Required

**Response (200):**

```json
{
  "success": true
}
```

---

### POST /api/playlists/{id}/items

Add a podcast or episode to a playlist.

**Authentication:** Required

**Request Body:**

```json
{
  "podcastId": "uuid",
  "episodeId": "uuid",
  "position": 0
}
```

**Note:** Either `podcastId` or `episodeId` must be provided. `position` is optional and defaults to the end.

**Error Responses:**
- **400:** Invalid request data (must provide podcastId or episodeId)
- **409:** Item already in playlist

---

### PUT /api/playlists/{id}/items/{itemId}

Update the position of an item in a playlist.

**Authentication:** Required

**Request Body:**

```json
{
  "position": 2
}
```

**Response (200):**

```json
{
  "item": {
    "id": "uuid",
    "position": 2,
    "podcast": { ... },
    "episode": {
      "id": "uuid",
      "title": "Episode Title",
      "podcast": { ... }
    }
  }
}
```

---

### DELETE /api/playlists/{id}/items/{itemId}

Remove an item from a playlist.

**Authentication:** Required

**Response (200):**

```json
{
  "success": true
}
```

---

## Stats

### GET /api/stats/dashboard

Get dashboard statistics including listening time, completed episodes, and more.

**Authentication:** Required

**Response (200):**

```json
{
  "stats": {
    "totalListeningTimeSeconds": 36000,
    "totalEpisodesCompleted": 50,
    "totalEpisodesInProgress": 10,
    "totalPodcastsSubscribed": 5
  }
}
```

---

### GET /api/stats/wrapped

Get year-end wrapped statistics for a specific year.

**Authentication:** Required

**Query Parameters:**
- **year** (optional): Year to get stats for (default: current year)

**Example:**

```
GET /api/stats/wrapped?year=2024
```

**Response (200):**

```json
{
  "stats": {
    "year": 2024,
    "totalListeningTimeSeconds": 360000,
    "topPodcasts": [ ... ],
    "topEpisodes": [ ... ]
  }
}
```

---

## Cron Jobs (Internal)

These endpoints are for internal use only (scheduled tasks). They require a CRON_SECRET header
and should not be called by iOS applications.

### POST /api/cron/refresh-feeds

Refresh all podcast feeds. Called automatically every 6 hours.

**Authentication:** CRON_SECRET required

---

### POST /api/cron/cleanup

Run daily cleanup tasks. Called automatically once per day.

**Authentication:** CRON_SECRET required

---

## Error Responses

All endpoints may return the following error responses:

- **400:** Bad Request - Invalid request data or validation error
- **401:** Unauthorized - Missing or invalid API key
- **403:** Forbidden - Access denied (e.g., not subscribed to podcast)
- **404:** Not Found - Resource not found
- **409:** Conflict - Resource already exists or conflict occurred
- **500:** Internal Server Error - Server error

Error responses follow this format:

```json
{
  "error": "Error message",
  "details": { ... } // Optional, may contain validation errors
}
```

---

## Base URL

For production, use your deployed API base URL. For development:

```
http://localhost:3000
```

---

## Notes

- All timestamps are in ISO 8601 format (UTC)
- UUIDs are used for all IDs
- Pagination uses `limit` and `offset` parameters
- All endpoints return JSON
- Content-Type header should be `application/json` for POST/PUT/PATCH requests
