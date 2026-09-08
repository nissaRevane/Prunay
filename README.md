# Prunay - Rental Investment Profitability Simulator

A Ruby on Rails 8 application to estimate the profitability of a rental real estate
investment.

> **Status:** first simulator. A simulation describes a property, its purchase, how it is
> financed — outright or on credit — its letting, its annual charges and the tax the rents
> cost, projected over thirty years, under four tax regimes read side by side: the
> micro-foncier, the foncier réel, the micro-BIC and the LMNP.

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
- **Account page** (`/mon-compte`): identity, password change, and the JSON export of the
  whole account (`/export`) — the economic conditions and every simulation, written in the
  exact shape `db/seeds.rb` reads back, so an export can re-feed a database. The password is
  never exported: Devise only keeps a digest, and a random one takes its place.
- **Landing page:** the public shop window, for visitors.
- **Simulations** (`/simulations`, and the home page of a signed-in user): the full CRUD,
  grouped by purchase year in the same accordion Milly uses for its bilans. There is no
  dashboard above the list: the brand leads to it, and the top menu carries only what the
  brand does not — the default economic conditions, the single general setting.
- **Creation page by page** (`/simulations/new`, which opens `/simulations/new/property`):
  the property, the purchase, the credit *if there is one*, the letting, the annual charges.
  Nothing is written to the database before the last page — the answers accumulate in the
  session, and each page validates only its own fields (see the validation contexts named
  after `Simulation::STEPS`). The credit page is conditional: it only opens for a purchase
  whose box is ticked (`Simulation::STEP_CONDITIONS`), so the walk is four pages long for a
  purchase paid outright and five for a purchase financed by a loan — the progress bar reads
  `Simulation#steps`, never the constant. The pages only help someone discovering the form:
  correcting a figure afterwards happens where the figure is read.
- **Correcting a simulation in place:** every answer the user gave is a click away on the
  tab that shows it — the value turns into the field that asked for it, and the field saves
  itself as soon as it changes (`inline_edit_controller.js`). No edit button, no save
  button. The server answers with the whole page (`simulations/_detail`, replaced by a Turbo
  Stream), because everything on it is derived and one corrected figure remakes ten; a
  refused value leaves the page as it was and answers with the message alone. The single
  form of `/simulations/:id/edit` remains, reachable from the list, for what one field
  cannot express on its own: turning a purchase paid outright into a purchase financed by a
  credit takes five answers at once.
- **Amounts proposed from the answers already given:** the rent and most of the annual
  charges are pre-filled from a reference amount for 50 m², scaled by the square root of
  the surface and rounded to the nearest ten euros — orders of magnitude to correct, not a
  calculation. Three of them do not follow the surface at all: an accountant's fee is flat,
  and a letting agent or a rent guarantee is proposed at zero because neither can be
  assumed.
- **The credit** (`AmortizationSchedule`): the down payment is asked for on the purchase
  page — proposed at a tenth of the project cost, recomputed in the browser as the price is
  typed — and the credit page asks only for a rate, a duration and the borrower's insurance
  premium. Everything else is derived: the capital borrowed is the project cost less the
  down payment, and the monthly payment comes out of the constant-annuity formula
  `M = C × i / (1 − (1 + i)^−n)`, rounded to the cent. The schedule that follows is Milly's — interest on the outstanding capital,
  principal for the rest, the last payment settling the rounding residue — but read the
  other way round: Milly copies a payment already negotiated, Prunay computes the payment
  that a rate and a duration imply. Repayment starts on the fifth that follows the signature
  (`Simulation::LOAN_PAYMENT_DAY`): the fifth of the month of the deed when it is signed
  between the 1st and the 5th, the fifth of the month after when it is signed later. The
  table is a tab of its own on the simulation page.
- **The borrower's insurance** (`loan_insurance`): a bank does not lend without it, so the
  credit page asks for the premium it charges every month, proposed at a ten-thousandth of
  the capital borrowed (`Simulation::DEFAULT_LOAN_INSURANCE_DIVISOR` — 0.12 % a year) and
  corrected as soon as the loan offer states the real figure. The
  premium is the same from the first payment to the last: it is read on the capital
  borrowed on day one, not on the outstanding capital, and it repays none of it. It sits in
  its own column of the schedule, adds itself to what the bank actually debits each month,
  and is counted apart from the interest — what the credit costs is the two together.
- **The economic conditions** (`EconomicConditions`): three annual rates that make a
  simulation age — what the rents gain each year (1 % by default), what the property gains in
  value (1 %), and the inflation that weighs on the charges (2 %). They live in two places.
  `/conditions-economiques`, reachable from the top menu, holds a user's defaults; nothing is
  written there until he changes something, and until then the page opens on what Prunay
  assumes. Every simulation then carries its own copy of the three, taken from those defaults
  the day it is created — correcting the defaults afterwards never rewrites a projection
  already read. None of the creation pages asks for them: they are corrected, once the
  simulation exists, from a tab of its own on the simulation page, one rate at a time like
  every other value, and the page comes back on that tab (`?tab=economic_conditions`).
- **The taxation** (`Taxation`): four regimes, each a tab of the simulation page and a
  projection of its own — the same property, the same rents, the same charges, and the tax
  alone to separate them. What they share sits on `Taxation::Regime`: the marginal bracket of
  the household (0, 11, 30, 41 or 45 %, chosen with the other assumptions of the simulation,
  30 % by default) and the social charges, which no bracket governs — a household the scale
  does not reach still owes them — what `#total` names is that income tax and nothing else.
  Only the assessment, the allowance, the social rate and the charges the regime pays of its
  own — `#own_charge_lines`, which the projection adds to the charges of the year — are each
  regime's own. What the two furnished regimes share sits on `Taxation::Bic`.
  - **The micro-foncier** (`Taxation::MicroFoncier`), for a bare letting: the assessment is
    the year's rent excluding charges — the provision for charges the tenant repays is
    collected with the rent but is not a revenue, it settles an expense — reduced by the flat
    30 % allowance that stands in for every deductible charge. 17.2 % of social charges.
  - **The foncier réel** (`Taxation::FoncierReel`), the same letting declared for real: no
    allowance, but the year's charges and the interest of the loan — the insurance premium
    included — deducted from that same rent. A deficit is not carried forward: a year that
    gained nothing owes nothing, and nothing passes to the next. 17.2 % of social charges.
  - **The micro-BIC** (`Taxation::MicroBic`), for a furnished letting: a furnished rent is not
    a property income but a commercial receipt, and it shows three times. The assessment
    counts the provision for charges, which the two foncier regimes leave out, and the
    allowance is half the receipts. The social charges are 18.6 % and not 17.2: the 2026
    social security financing act raised the CSG on capital income to 10.6 % and spared
    property income and property capital gains alone. A furnished letting also owes the CFE,
    which the property income never pays: it is not a tax on the income but a tax on the
    premises, and it is counted as a charge of the year, above the pre-tax result, not with
    the income tax. Its real base is the rental value the commune assesses, and, that being
    out of reach, Prunay takes 30 % of one monthly rent — the rent of the year, so the tax
    follows its growth. A real regime would deduct it from its assessment; the micro-BIC has
    only its flat allowance, which already stands in for every charge, the CFE included. It
    is not asked of the user. The 77 700 € ceiling of receipts above which the regime closes
    is not checked, and a furnished letting is supposed to bring the same rent and cost the
    same charges as a bare one — what the tabs compare is the tax, not the letting.
  - **The LMNP** (`Taxation::Lmnp`), the same furnished letting declared for real: the receipts
    of the micro-BIC, the 18.6 % and the CFE, but no allowance at all — the charges, the CFE
    itself, the accountant and the interest of the loan are deducted for what they cost, and
    on top of them the depreciation of the building, the only expense the taxman admits without
    a payment. Prunay depreciates 80 % of the price paid — the land does not wear out — over 25
    years, from the first year let to the twenty-fifth: a flat plan where the taxman expects one
    per component, and the works and the notary fees, which really are depreciated too, are left
    out. Neither the deficit nor the excess of depreciation is carried forward: a year that
    gained nothing owes nothing, and nothing passes to the next — the real regime defers the
    excess indefinitely, which is precisely what makes the LMNP pay no tax for years. The
    accountant is the one charge a single regime pays: it is asked of the user like the others
    (500 € by default, `accounting_fees`), kept out of `ANNUAL_CHARGES` since no other regime
    owes it (`Simulation::REGIME_CHARGES`), and weighs on the LMNP's cash flow alone.

  The parameters tab lists the CFE and the accountant with the annual charges, each noted as
  the regime's own and left out of their total, and details the calculation line by line; the
  tax weighs on the cash flow of every year of the projection. The depreciation appears
  nowhere but in the detail of the tax: it lowers the assessment and never the cash flow.
  The resale of a year is taxed apart (`Taxation::CapitalGain`), under the regime of private
  individuals: the gain is what the price of that year gets above the fiscal value of the
  property — the price paid, the notary fees, and from the sixth year the flat 15 % of works
  the taxman assumes without an invoice, the real works being the other, exclusive option that
  Prunay does not simulate. It bears 19 % of income tax and 17.2 % of social charges, each on
  what its own allowance for the years held leaves it: nothing for five years, then 6 % a year
  until the gain escapes the income tax after twenty-two, and 1.65 % then 9 % a year until it
  escapes the social charges after thirty. The surtax on gains above 50 000 € is not
  simulated. The sale view of a year's statement deducts that tax right after the price of the
  property, before the bank is cleared.
  Selling costs something before it is taxed (`SaleCosts`): the mandatory diagnostics, a flat
  400 € whatever the property, putting it back in order, 500 € for 50 m² and the square root of
  the surface from there — twice the surface is not twice the work. No agency: the property is
  supposed to be sold between individuals. The costs are deducted from the price in the sale
  view, above the capital gain tax, and they inflate year by year like every other expense of
  the projection. They do not lower the taxable gain: only an agency commission would, and
  works only against invoices Prunay does not simulate.
  Clearing the loan before its term costs one more thing, and it is the bank's, not the sale's
  (`Loan#early_repayment_fee`): 3 % of the capital repaid, capped at six months of its
  interest — under 6 % a year the cap is what applies, so it is half the rate on what is still
  owed. The sale view deducts it right after the capital, and it falls to nothing the year the
  loan is cleared.
- **The projection:** thirty lines, one per anniversary of the purchase. The table carries
  five columns and no commentary — the year, its month, its rent, its cash flow and the
  capital still immobilized. The charges, the tax and the annuity weigh on the cash flow
  without a column of their own: they are what the parameters tab is for, and a table one
  reads to decide is not a table that explains itself. The rent column and the year's statement
  read the way the regime declares: excluding charges under the two foncier regimes, where the
  provision the tenant repays is neither a revenue nor a deductible charge, and charges included
  under the two furnished regimes, which declare it and deduct the whole charges in return — either reading
  leaves the same pre-tax result, the provision moving on both sides at once.
  The statement is read twice over: a summary of one line per amount, and, behind the Détail
  button of its header, the calculation of each of those lines folded under it — the rent at the
  month, every charge indexed as the year bears it, the interest apart from the insurance
  premium, the assessment down to the two rates that strike it, and, on the sale view, what the
  costs are made of, how the fiscal value leaves or leaves no gain, and what the years have
  already given back of the investment. Beside the labels that need one, a question mark holds
  a sentence of explanation on hover: what the line covers and what it deliberately leaves out.
  The annual rent counts only the months actually
  let, and the annuity — the insurance premium included — is read from the schedule year by
  year: twelve payments while the loan runs, what is left of it the year it is cleared,
  nothing after. What is immobilized on day one is what actually leaves the buyer's pocket —
  the whole project when it is paid outright, the down payment alone when a credit finances
  the rest, since the capital borrowed is repaid by the annuities the projection already
  deducts. Neither the rents nor the charges are the same on every line: the first year
  carries the amounts as they were typed — it describes the twelve months that follow the
  purchase — and each year after compounds them by its rate. Under the table, two totals: the
  cash flow accumulated over the horizon, and what the property is then worth — the purchase
  price alone compounded, since neither the notary fees nor the works are resold.

## Project Structure

```
app/
├── controllers/        # ApplicationController (auth guard), Pages, Simulations,
│                       # Simulations::Steps (the four-page creation), EconomicConditions and
│                       # Simulations::EconomicConditions, Users::Registrations
├── models/             # User, Simulation, EconomicConditions, Loan, Projection,
│                       # AmortizationSchedule, Taxation
├── views/              # ERB templates with Hotwire (layout, navbar, devise, landing, simulations)
├── javascript/         # Stimulus controllers
└── assets/             # CSS design system
config/
├── locales/fr.yml      # French translations
├── routes.rb           # Application routes
└── database.yml        # Database configuration
db/
├── migrate/            # Database migrations
├── seed_data.json      # The demo account, in the export format
└── seeds.rb            # Reads seed_data.json, idempotent
spec/
├── models/             # Model unit tests
├── requests/           # Request/integration tests
└── factories/          # FactoryBot factories
```

## Data Model

- **User** (firstname, lastname, email) — has at most one **EconomicConditions**, the
  defaults every simulation he creates inherits: rent_growth_rate, property_growth_rate,
  inflation_rate and marginal_tax_rate. The row only exists once he has changed something;
  `EconomicConditions.for` stands in for it until then.
- **Simulation** — belongs to a user, and has no name of its own: it reads as
  "Appartement à Nantes", from its type and its city.
  - *the property:* property_type, address, city, energy_rating, surface
  - *the purchase:* purchase_price, initial_works, purchase_date
  - *the financing:* credit, down_payment, loan_rate, loan_duration_years, loan_insurance —
    the capital borrowed, the monthly payment and the amortization schedule are derived from
    them, never stored (like the notary fees)
  - *the letting:* monthly_rent (excluding charges, the only taxable part), monthly_charges
    (the provision the tenant repays on top of it) and occupancy_months
  - *the annual charges*, grouped by what generates them (`Simulation::CHARGE_GROUPS`, from
    which `ANNUAL_CHARGES` derives — a charge is added to a group and nowhere else):
    - *owning the property:* property_tax, insurance, maintenance, condominium_fees
    - *letting it:* management_fees, rent_guarantee
    - *the furnished letting:* accounting_fees — the accountant of the LMNP, which
      `REGIME_CHARGES` keeps out of `ANNUAL_CHARGES`: the regime pays it, not the property
    - *the rest:* other_charges
  - *the economic conditions:* rent_growth_rate, property_growth_rate, inflation_rate and
    marginal_tax_rate — the same four columns as `EconomicConditions`, copied from the user's
    defaults at the creation and corrected afterwards for this simulation alone

  The thirty-year projection is derived, never stored: see `Simulation#projection` and its
  `Year` struct, the tax of the year included.
