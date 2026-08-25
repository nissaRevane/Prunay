# Prunay - Rental Investment Profitability Simulator

A Ruby on Rails 8 application to estimate the profitability of a rental real estate
investment.

> **Status:** first simulator. A simulation describes a property, its purchase, how it is
> financed — outright or on credit — its letting and its annual charges, projected over
> thirty years. No tax yet — everything else is there to receive it.

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
- **Creation page by page** (`/simulations/new`, which opens `/simulations/new/property`):
  the property, the purchase, the credit *if there is one*, the letting, the annual charges.
  Nothing is written to the database before the last page — the answers accumulate in the
  session, and each page validates only its own fields (see the validation contexts named
  after `Simulation::STEPS`). The credit page is conditional: it only opens for a purchase
  whose box is ticked (`Simulation::STEP_CONDITIONS`), so the walk is four pages long for a
  purchase paid outright and five for a purchase financed by a loan — the progress bar reads
  `Simulation#steps`, never the constant. Editing, by contrast, is a single form: the pages
  only help someone discovering the form.
- **Amounts proposed from the answers already given:** the rent and most of the annual
  charges are pre-filled from a reference amount for 50 m², scaled by the square root of
  the surface and rounded to the nearest ten euros — orders of magnitude to correct, not a
  calculation. Three of them do not follow the surface at all: an accountant's fee is flat,
  and a letting agent or a rent guarantee is proposed at zero because neither can be
  assumed. Maintenance reads two references instead of one: doubled when no condominium
  already carries the façade, the roof and the common parts.
- **Charges asked for under a condition:** the condominium fees are only asked of a
  property in a condominium, and the business tax (CFE) and the accountant only of a
  furnished letting (`Simulation::CHARGE_CONDITIONS`). A charge whose condition falls away
  goes back to zero before the record is saved, so an amount the form no longer shows never
  weighs on the projection — and the simulation page details only the charges the property
  is actually asked for.
- **The credit** (`AmortizationSchedule`): the down payment is asked for on the purchase
  page — proposed at a tenth of the project cost, recomputed in the browser as the price is
  typed — and the credit page asks only for a rate and a duration. Everything else is
  derived: the capital borrowed is the project cost less the down payment, and the monthly
  payment comes out of the constant-annuity formula `M = C × i / (1 − (1 + i)^−n)`, rounded
  to the cent. The schedule that follows is Milly's — interest on the outstanding capital,
  principal for the rest, the last payment settling the rounding residue — but read the
  other way round: Milly copies a payment already negotiated, Prunay computes the payment
  that a rate and a duration imply. The table is a tab of its own on the simulation page.
- **The projection:** thirty lines, one per anniversary of the purchase, each carrying the
  year's rent, its charges, the annuity of its credit, its cash flow and the capital still
  immobilized. The annual rent counts only the months actually let, and the annuity is read
  from the schedule year by year: twelve payments while the loan runs, what is left of it the
  year it is cleared, nothing after. What is immobilized on day one is what actually leaves
  the buyer's pocket — the whole project when it is paid outright, the down payment alone
  when a credit finances the rest, since the capital borrowed is repaid by the annuities the
  projection already deducts.

## Project Structure

```
app/
├── controllers/        # ApplicationController (auth guard), Pages, Simulations,
│                       # Simulations::Steps (the four-page creation), Users::Registrations
├── models/             # User, Simulation, AmortizationSchedule
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
  - *the financing:* credit, down_payment, loan_rate, loan_duration_years — the capital
    borrowed, the monthly payment and the amortization schedule are derived from them, never
    stored (like the notary fees)
  - *the letting:* monthly_rent, occupancy_months, rental_type
  - *the annual charges*, grouped by what generates them (`Simulation::CHARGE_GROUPS`, from
    which `ANNUAL_CHARGES` derives — a charge is added to a group and nowhere else):
    - *owning the property:* property_tax, insurance, maintenance, condominium_fees
    - *letting it:* management_fees, rent_guarantee
    - *the furnished regime:* business_tax, accounting_fees
    - *the rest:* other_charges

  The thirty-year projection is derived, never stored: see `Simulation#projection` and its
  `Year` struct, where the column a tax will add has its place waiting.
