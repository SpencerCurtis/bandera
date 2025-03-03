# Bandera

Bandera is a feature flag service built with Swift and Vapor, designed to help you manage feature flags for your applications.

## Features

- **Feature Flag Management**: Create, update, and delete feature flags
- **User-Specific Overrides**: Set different flag values for specific users
- **Multiple Flag Types**: Support for boolean, string, number, and JSON flag types
- **Real-time Updates**: WebSocket support for real-time flag changes
- **Authentication**: JWT-based authentication with role-based access control
- **API & Dashboard**: RESTful API and web dashboard for flag management

## Architecture

Bandera follows a clean architecture approach with the following components:

- **Models**: Core domain entities (FeatureFlag, User, etc.)
- **Controllers**: Handle HTTP requests and responses
- **Services**: Implement business logic
- **Repositories**: Handle data access and persistence
- **DTOs**: Data Transfer Objects for API requests and responses
- **Middleware**: Request processing and authentication

## Getting Started

### Prerequisites

- Swift 6.0 or higher
- Docker and Docker Compose (for containerized deployment)
- PostgreSQL (for production) or SQLite (for development)

### Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/bandera.git
   cd bandera
   ```

2. Build and run the project:
   ```bash
   swift build
   swift run
   ```

3. The application will be available at `http://localhost:8080`

### Docker Deployment

1. Build and start the containers:
   ```bash
   docker compose build
   docker compose up app
   ```

2. Run migrations:
   ```bash
   docker compose run migrate
   ```

3. The application will be available at `http://localhost:8080`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_HOST` | Database hostname | `localhost` |
| `DATABASE_NAME` | Database name | `vapor_database` |
| `DATABASE_USERNAME` | Database username | `vapor_username` |
| `DATABASE_PASSWORD` | Database password | `vapor_password` |
| `JWT_SECRET` | Secret key for JWT signing | `your-default-secret` |
| `REDIS_HOST` | Redis hostname | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_PASSWORD` | Redis password | `null` |

## API Documentation

### Authentication

- `POST /auth/register`: Register a new user
- `POST /auth/login`: Login and get JWT token
- `POST /auth/logout`: Logout and invalidate token

### Feature Flags

- `GET /feature-flags`: Get all feature flags for the authenticated user
- `POST /feature-flags`: Create a new feature flag
- `PUT /feature-flags/:id`: Update a feature flag
- `DELETE /feature-flags/:id`: Delete a feature flag
- `GET /feature-flags/user/:userId`: Get all feature flags for a specific user

### Dashboard

- `GET /dashboard`: Web dashboard for feature flag management

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 