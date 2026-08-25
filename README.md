# Prunay - Rental Investment Profitability Simulator

A Ruby on Rails 8 application to estimate the profitability of a rental real estate
investment.

> **Status:** architecture only. Authentication, the design system and the navigation
> shell are in place; the simulator itself is not implemented yet, so the dashboard is
> deliberately empty.

## Tech Stack

- **Ruby** 3.3 / **Rails** 8.0
- **PostgreSQL** 16
- **Hotwire** (Turbo + Stimulus)
- **Devise** for authentication
- **RSpec** for testing
- **Docker** + **Docker Compose**

## Quick Start

```bash
# Build and start the application
docker compose build
docker compose run --rm web rails db:prepare
docker compose run --rm web rails db:test:prepare
docker compose up
```

Open [http://localhost:3001](http://localhost:3001) in your browser.

> The ports are 3001 (web) and 5434 (PostgreSQL) rather than the Rails defaults, so
> Prunay and Milly can run side by side on the same machine.

### Demo Account

- **Email:** demo@prunay.app
- **Password:** password123

## Running Tests

```bash
docker compose run --rm web bundle exec rspec
```

## What Exists Today

- **Authentication:** sign up, sign in, sign out, forgotten password, "remember me".
  Every controller is behind `authenticate_user!` by default (`ApplicationController`);
  the public landing page is the single explicit opt-out.
- **Account page** (`/mon-compte`): identity and password change.
- **Landing page:** the public shop window, for visitors.
- **Dashboard:** the home page of a signed-in user, and the place the simulator will
  take. Empty for now, and it says so.

## Project Structure

```
app/
├── controllers/        # ApplicationController (auth guard), Pages, Dashboard, Users::Registrations
├── models/             # User
├── views/              # ERB templates with Hotwire (layout, navbar, devise, landing, dashboard)
├── javascript/         # Stimulus controllers
└── assets/             # CSS design system
config/
├── locales/fr.yml      # French translations
├── routes.rb           # Application routes
└── database.yml        # Database configuration
db/
├── migrate/            # Database migrations
└── seeds.rb            # Demo account
spec/
├── models/             # Model unit tests
├── requests/           # Request/integration tests
└── factories/          # FactoryBot factories
```

## Data Model

- **User** (firstname, lastname, email) — the only table so far.
