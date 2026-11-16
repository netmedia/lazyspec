# Acme Portal — Architecture

## Purpose
The building blocks of the portal and how they talk to each other.

## Requirements

### Requirement: Web app and API
The portal SHALL consist of a web front end and a REST API; the front end SHALL reach data only through the
API.

| Part | Technology | Hosting |
|---|---|---|
| Front end | React | Static web app |
| API | .NET 10 | App Service |
| Database | SQL Server | Azure SQL |
| E-mail | SMTP relay | Managed service |

#### Scenario: Data access
- **WHEN** the front end needs a customer's orders
- **THEN** it calls the API, never the database
