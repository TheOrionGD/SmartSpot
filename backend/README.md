# SmartSpot Backend API

A complete REST API backend for SmartSpot location-based reminders, authentication, favorites, shared family groups, location intelligence visits, and productivity analytics.

## Features

- **Authentication & Security**: Register, Login, Security Question recovery, Password Reset, Profile updates, Change password, JWT tokens (30 days expiry), bcrypt password & security question answer hashing, Rate limiting, Helmet security headers.
- **Location Reminders**: Full CRUD (`GET`, `POST`, `PUT`, `DELETE`), completion toggle (`PATCH /complete`), archive toggle (`PATCH /archive`), bulk offline sync (`POST /sync`), filtering by category, completion, archive, and search query.
- **Favorites**: Manage favorite places (`GET`, `POST`, `PUT`, `DELETE`).
- **Family Groups**: Group creation with auto-generated 6-character invite codes, join group, add/remove group members, leave/delete group.
- **Location Visits Intelligence**: Log and retrieve location visits (`GET`, `POST`) to feed predictive recommendation engines.
- **Analytics & Statistics**: Comprehensive summary stats (`GET /api/analytics/statistics`).
- **Email Notifications**: Brevo SMTP integration for password change security alerts.

## Run Locally

```powershell
cd backend
npm install
Copy-Item .env.example .env
npm run dev
```

The API listens on port `3000` by default.

## Run Tests

Run the automated end-to-end API test suite:

```powershell
npm test
```

Run syntax check:

```powershell
npm run check
```

## Production Deployment

Set these environment variables on your hosting provider (e.g., Render, Railway, AWS, GCP, Heroku):

```text
NODE_ENV=production
PORT=3000
JWT_SECRET=<long-random-secret-key>
CORS_ORIGIN=https://your-flutter-app-domain.example
DB_FILE=./data/smartspot.json
BREVO_API_KEY=<brevo-api-key>
MAIL_FROM=godfrey.cs23@krct.ac.in
MAIL_FROM_NAME=SmartSpot Support
```

### Docker Deployment

```powershell
docker build -t smartspot-backend .
docker run -d --name smartspot-api -p 3000:3000 -v smartspot-data:/app/data `
  -e NODE_ENV=production `
  -e JWT_SECRET="replace-with-a-long-random-secret" `
  smartspot-backend
```

## Complete API Endpoint Reference

### Health
- `GET /health`

### Authentication & Profile (`/api/auth`)
- `POST /api/auth/register` - `{ name, email, password, securityQuestion, securityAnswer }`
- `POST /api/auth/login` - `{ email, password }`
- `POST /api/auth/security-question` - `{ email }`
- `POST /api/auth/reset-password` - `{ email, securityAnswer, newPassword }`
- `GET /api/auth/me` - *(Requires Auth)* Get current profile
- `PUT /api/auth/profile` - *(Requires Auth)* Update name or email
- `POST /api/auth/change-password` - *(Requires Auth)* `{ currentPassword, newPassword }`

### Reminders (`/api/reminders`)
*(All endpoints require Auth header: `Authorization: Bearer <token>`)*
- `GET /api/reminders` - Query params: `category`, `isCompleted`, `isArchived`, `search`
- `POST /api/reminders` - Create location reminder payload
- `GET /api/reminders/:id` - Get single reminder payload
- `PUT /api/reminders/:id` - Update reminder
- `DELETE /api/reminders/:id` - Delete reminder
- `PATCH /api/reminders/:id/complete` - `{ isCompleted: true/false }`
- `PATCH /api/reminders/:id/archive` - `{ isArchived: true/false }`
- `POST /api/reminders/sync` - `{ reminders: [...] }` Bulk offline sync

### Favorites (`/api/favorites`)
*(All endpoints require Auth header: `Authorization: Bearer <token>`)*
- `GET /api/favorites` - List user favorites
- `POST /api/favorites` - Save favorite place
- `PUT /api/favorites/:id` - Update favorite place
- `DELETE /api/favorites/:id` - Delete favorite place

### Family Groups (`/api/groups`)
*(All endpoints require Auth header: `Authorization: Bearer <token>`)*
- `GET /api/groups` - List user groups & membership
- `POST /api/groups` - `{ name }` Create group (returns inviteCode)
- `PUT /api/groups/:id` - `{ name }` Update group name
- `DELETE /api/groups/:id` - Delete group (owner) or leave group (member)
- `POST /api/groups/join` - `{ inviteCode }` Join group
- `POST /api/groups/:id/members` - `{ memberName }` Add member by name
- `DELETE /api/groups/:id/members/:memberName` - Remove member from group

### Location Visits & Intelligence (`/api/visits`)
*(All endpoints require Auth header: `Authorization: Bearer <token>`)*
- `GET /api/visits` - List recent location visits
- `POST /api/visits` - Log location visit

### Analytics & Statistics (`/api/analytics`)
*(Requires Auth header: `Authorization: Bearer <token>`)*
- `GET /api/analytics/statistics` - Summary stats (total, completed, pending, category breakdown, missed count)
