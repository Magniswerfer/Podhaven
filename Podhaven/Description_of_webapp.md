# Podcast Sync Service

A full-stack podcast synchronization service built with Next.js 14+, PostgreSQL,
Prisma, and TypeScript. Provides API endpoints for iOS app integration and a
web-based player interface.

## Features

### Core Features

- **Podcast Management**: Subscribe to podcasts via RSS feed URL or iTunes search
- **Episode Sync**: Automatic RSS feed parsing and episode management
- **Progress Tracking**: Sync listening progress across devices
- **Queue Management**: Build and manage your listening queue
- **Playlists**: Create and organize custom playlists with episodes or entire podcasts
- **Statistics**: Track listening time, top podcasts, and generate year-end wrapped data
- **Background Jobs**: Automatic feed refresh and cleanup tasks

### Web Application

**Audio Player**
- Play/pause, skip forward/backward (15 seconds)
- Seek through episodes with progress bar
- Volume control with percentage display
- Playback speed: 0.5x, 0.75x, 1x, 1.25x, 1.5x, 1.75x, 2x
- Mini player persists at bottom while browsing
- Smart resume with "Continue" or "Start Over" options

**Dashboard**
- Listening statistics overview (time, completed, in-progress, subscribed)
- Recently played episodes with quick play
- New episodes from subscribed podcasts

**Podcast Management**
- Search and subscribe via iTunes or RSS URL
- Per-podcast filter and sort settings
- Manual feed refresh
- Bulk add podcast to playlist

**Episode Browsing**
- Filter: All, Unplayed, Uncompleted, In Progress
- Sort: Newest or Oldest first
- Visual progress indicators and status
- Quick actions: play, add to queue/playlist, mark as played

**Queue**
- View and reorder listening queue
- Add episodes to play next
- Clear queue with optional current episode preservation

**Playlists**
- Create, edit, and delete playlists
- Add episodes or entire podcasts
- Reorder items within playlists
- Play playlist from any item

**Profile & Settings**
- API key management (view, copy, regenerate)
- Default filter/sort preferences
- Date format selection (MM/DD/YYYY, DD/MM/YYYY, YYYY-MM-DD)
- Password management
- Reset all subscriptions and data

**User Interface**
- Dark theme with responsive design
- Mobile-optimized layouts
- Confirmation modals for destructive actions
- Loading states and toast notifications

## Tech Stack

- **Framework**: Next.js 14+ (App Router)
- **Database**: PostgreSQL (via Docker)
- **ORM**: Prisma
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **UI Components**: Headless UI, Heroicons

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Docker and Docker Compose (for PostgreSQL)

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd podcast-service
```

2. Install dependencies:

```bash
npm install
```

3. Set up environment variables:

```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Start PostgreSQL database:

```bash
docker-compose up -d
```

5. Run database migrations:

```bash
npx prisma migrate dev
```

6. Generate Prisma client:

```bash
npx prisma generate
```

7. Start the development server:

```bash
npm run dev
```

The application will be available at `http://localhost:3000`.

## API Endpoints

See [API.md](./API.md) for complete API documentation with request/response examples.

### Authentication

- `POST /api/auth/register` - Create a new user account
- `POST /api/auth/login` - Authenticate and get API key

### Profile

- `GET /api/profile` - Get user profile and settings
- `PATCH /api/profile` - Update default settings
- `POST /api/profile/change-password` - Change password
- `POST /api/profile/regenerate-api-key` - Generate new API key
- `POST /api/profile/reset-subscriptions` - Delete all user data

### Podcasts

- `GET /api/podcasts` - List user's subscribed podcasts
- `POST /api/podcasts/subscribe` - Subscribe to a podcast by feed URL
- `DELETE /api/podcasts/{id}` - Unsubscribe from a podcast
- `GET /api/podcasts/search?q=query` - Search iTunes for podcasts
- `POST /api/podcasts/{id}/refresh` - Force refresh podcast feed
- `PATCH /api/podcasts/{id}/settings` - Update per-podcast settings

### Episodes

- `GET /api/episodes` - List episodes (paginated, filtered)
- `GET /api/episodes/{id}` - Get episode details

### Progress

- `GET /api/progress` - Get all listening progress
- `POST /api/progress` - Bulk update progress
- `PUT /api/progress/{episode_id}` - Update single episode progress

### Queue

- `GET /api/queue` - Get user's queue
- `POST /api/queue` - Add episode to queue
- `PUT /api/queue` - Reorder queue
- `DELETE /api/queue` - Clear queue
- `DELETE /api/queue/{id}` - Remove from queue
- `POST /api/queue/play-next` - Add episode to play next

### Playlists

- `GET /api/playlists` - List user's playlists
- `POST /api/playlists` - Create playlist
- `GET /api/playlists/{id}` - Get playlist with items
- `PUT /api/playlists/{id}` - Update playlist
- `DELETE /api/playlists/{id}` - Delete playlist
- `POST /api/playlists/{id}/items` - Add item to playlist
- `PUT /api/playlists/{id}/items/{itemId}` - Update item position
- `DELETE /api/playlists/{id}/items/{itemId}` - Remove item

### Stats

- `GET /api/stats/dashboard` - Get dashboard statistics
- `GET /api/stats/wrapped?year=2025` - Get year-end wrapped data

### Cron Jobs

- `POST /api/cron/refresh-feeds` - Refresh all podcast feeds (every 6 hours)
- `POST /api/cron/cleanup` - Daily cleanup tasks

## Authentication

All API endpoints (except auth endpoints) require authentication via API key:

```
Authorization: Bearer <api_key>
```

Get your API key by registering or logging in via the auth endpoints.

## Database Schema

The database includes the following models:

- **User**: User accounts with API keys and settings
- **Podcast**: Podcast metadata and feed information
- **Episode**: Individual podcast episodes
- **Subscription**: User podcast subscriptions with custom settings
- **ListeningHistory**: Playback progress tracking
- **Queue**: User's listening queue
- **Playlist**: User-created playlists
- **PlaylistItem**: Episodes or podcasts within playlists
- **Favorite**: Favorite episodes/podcasts

## Background Jobs

Configure cron jobs to automatically refresh feeds and perform cleanup:

### Vercel Cron (if deploying to Vercel)

Add to `vercel.json`:

```json
{
    "crons": [
        {
            "path": "/api/cron/refresh-feeds",
            "schedule": "0 */6 * * *"
        },
        {
            "path": "/api/cron/cleanup",
            "schedule": "0 2 * * *"
        }
    ]
}
```

### External Cron Service

Set `CRON_SECRET` environment variable and call endpoints with:

```
Authorization: Bearer <CRON_SECRET>
```

## Development

### Database Migrations

```bash
# Create a new migration
npx prisma migrate dev --name migration_name

# Apply migrations
npx prisma migrate deploy

# View database in Prisma Studio
npx prisma studio
```

### Type Generation

```bash
# Generate Prisma client
npx prisma generate
```

## Project Structure

```
podcast-service/
├── prisma/
│   └── schema.prisma          # Database schema
├── src/
│   ├── app/
│   │   ├── api/               # API routes
│   │   ├── login/             # Login page
│   │   ├── register/          # Registration page
│   │   ├── podcasts/          # Podcast pages
│   │   ├── discover/          # Discover page
│   │   ├── player/            # Full-screen player
│   │   ├── queue/             # Queue page
│   │   ├── playlists/         # Playlists pages
│   │   ├── stats/             # Stats page
│   │   ├── profile/           # Profile & settings
│   │   └── docs/              # API documentation
│   ├── components/            # React components
│   ├── lib/                   # Utility functions
│   └── types/                 # TypeScript types
└── docker-compose.yml         # PostgreSQL container
```

## License

MIT
