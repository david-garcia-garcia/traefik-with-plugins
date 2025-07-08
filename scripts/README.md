# Integration Tests

This directory contains Pester integration tests for the Traefik with Plugins setup.

## Test File

- `integration-tests.Tests.ps1` - Main Pester test file containing all integration tests

## Test Coverage

The integration tests cover the following areas:

### 1. Traefik API Tests
- API health check (`/ping`)
- Raw data endpoint (`/api/rawdata`)
- Router information (`/api/http/routers`)
- Service information (`/api/http/services`)
- Middleware information (`/api/http/middlewares`)

### 2. Service Endpoint Tests
- **Whoami Service** - Tests the `/whoami` endpoint
- **CrowdSec Service** - Tests the `/crowdsec` endpoint with CrowdSec bouncer plugin

### 3. Plugin Configuration Tests
- Verifies CrowdSec bouncer middleware is properly configured

### 4. Basic Routing Tests
- Path-based routing functionality
- 404 handling for unknown paths

### 5. Basic Performance Tests
- Response time checks for key endpoints

### 6. Header Tests
- Basic HTTP header validation

## Running the Tests

The tests are designed to be run via the main `Test-Integration.ps1` script in the project root:

```powershell
# Run all integration tests
./Test-Integration.ps1

# Run tests but leave Docker services running for debugging
./Test-Integration.ps1 -SkipDockerCleanup

# Run tests assuming services are already running
./Test-Integration.ps1 -SkipWait
```

## Test Configuration

The tests use the following endpoints:
- **Main Application**: `http://localhost:8000`
- **Traefik API**: `http://localhost:8080`

## Notes

- Tests include retry logic for improved reliability
- Tests are designed to be simple and focused on basic functionality
- Tests can be expanded as needed for additional plugin-specific functionality 