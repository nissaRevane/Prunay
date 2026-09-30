# Prunay

A simulator for the profitability of a rental property investment. You describe a property,
its purchase, its financing, its letting and its charges, and Prunay projects it over thirty
years under the four French tax regimes, side by side: micro-foncier, foncier réel, micro-BIC
and LMNP.

Rails 8 · Ruby 3.3 · PostgreSQL 16 · Hotwire · Devise · RSpec · Docker

## Quick start

```bash
docker compose build
docker compose run --rm web rails db:prepare db:test:prepare
docker compose up
```

Open [http://localhost:3001](http://localhost:3001) and sign in with `demo@prunay.app` /
`password123`. The ports are 3001 (web) and 5434 (PostgreSQL), so Prunay can run next to
Milly on the same machine.

## Tests

```bash
docker compose run --rm web bundle exec rspec
```

## Deployment

Kamal on a single VPS (`config/deploy.yml`), triggered by GitHub Actions.

## How the numbers are computed

The rules, the modelling choices and what is deliberately left out are in [`docs/`](docs):

- [Inputs](docs/inputs.md): what the user answers, and what Prunay proposes in their place
- [Credit](docs/credit.md): the loan, its insurance, its early repayment
- [Taxation](docs/taxation.md): the four regimes, the LMNP depreciation, the capital gain
- [Projection](docs/projection.md): the thirty years, the resale, the rate of return
