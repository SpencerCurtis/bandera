# Development Tools and Commands

This directory contains development-only tools and commands for the Bandera project.

## Available Commands

- `swift run App reset-admin` - Resets the admin user's password to 'password'
- `swift run App reset-password <email>` - Resets any user's password to 'password'
- `swift run App reset-password <email> -p <new_password>` - Resets any user's password to a custom value

## Development Routes

- `GET /dev/reset-password/:email` - Resets a user's password to 'password'
- `GET /dev/reset-password/:email?password=<new_password>` - Resets a user's password to a custom value
- `GET /dev/users` - Lists all users in the system

## Development Workflow

### Restarting the Application

Always use the restart script to restart the application during development:

```bash
./restart.sh
```

This script:
1. Kills any running instances of the App to free up port 8080
2. Starts a new instance of the application

The script helps prevent "Address already in use" errors that occur when port 8080 is already taken.

### Admin Login

After restarting, you can log in with:
- Email: admin@example.com
- Password: password

If you can't log in, reset the admin password:
```bash
swift run App reset-admin
```

Or use the browser route:
```
http://localhost:8080/dev/reset-password/admin@example.com
``` 