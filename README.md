# Prunay - Rental Investment Profitability Simulator

A Ruby on Rails 8 application to estimate the profitability of a rental real estate
investment.

> **Status:** first simulator. A simulation describes a property, its purchase, its
> letting and its annual charges, projected over thirty years. No loan and no tax yet —
> everything else is there to receive them.

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
- **Simulations** (`/simulations`, and the home page of a signed-in user): the full CRUD,
  grouped by purchase year in the same accordion Milly uses for its bilans. There is no
  dashboard above the list and therefore no top menu: the brand leads to the only page
  there would be to put in one.
- **Creation in four pages** (`/simulations/new`, which opens `/simulations/new/property`):
  the property, the purchase, the letting, the annual charges. Nothing is written to the
  database before the last page — the answers accumulate in the session, and each page
  validates only its own fields (see the validation contexts named after
  `Simulation::STEPS`). Editing, by contrast, is a single form: the four pages only help
  someone discovering the form.
- **Amounts proposed from the surface:** the rent and the four annual charges are
  pre-filled from a reference amount for 50 m², scaled by the square root of the surface
  and rounded to the nearest ten euros — orders of magnitude to correct, not a calculation.
- **The projection:** thirty lines, one per anniversary of the purchase, each carrying the
  year's rent, its charges, its cash flow and the capital still immobilized. The
  immobilized capital starts at the price *plus the initial works*, and the annual rent
  counts only the months actually let.

## Project Structure

```
app/
├── controllers/        # ApplicationController (auth guard), Pages, Simulations,
│                       # Simulations::Steps (the four-page creation), Users::Registrations
├── models/             # User, Simulation
├── views/              # ERB templates with Hotwire (layout, navbar, devise, landing, simulations)
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

- **User** (firstname, lastname, email)
- **Simulation** — belongs to a user, and has no name of its own: it reads as
  "Appartement à Nantes", from its type and its city.
  - *the property:* property_type, address, city, energy_rating, surface, condominium
  - *the purchase:* purchase_price, initial_works, purchase_date
  - *the letting:* monthly_rent, occupancy_months, rental_type
  - *the annual charges:* property_tax, maintenance, insurance, other_charges

  The thirty-year projection is derived, never stored: see `Simulation#projection` and its
  `Year` struct, where the column a loan will add has its place waiting.
