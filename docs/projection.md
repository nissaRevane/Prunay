# Projection

`Projection`, one per tax regime: thirty years, one per anniversary of the purchase.

## A year

- **Growth**: the first year uses the amounts as entered, which describe the twelve months
  after the purchase. Each later year compounds them: rent by rent growth, charges and costs
  by inflation.
- **Rent**: only the months actually let count.
- **Unfurnished vs furnished**: the rent is read excluding charges under the unfurnished
  regimes and including charges under the furnished ones. Both give the same result before
  tax.
- **Annuity**: read from the schedule, insurance included. Twelve payments while the loan
  runs, the remainder in the year it is paid off, nothing after.
- **Cash flow**: the charges, the tax and the annuity all come out of it. Depreciation lowers
  the tax base but never the cash flow.

## Capital immobilized

Day one counts what actually leaves the buyer's pocket: the whole project if paid in cash,
the down payment alone with a loan (the annuities already repay the capital borrowed). Under
a furnished regime, the furniture is added in both cases. The projection's final value only
grows the price and the discount, since neither the notary fees nor the works are resold.

## Resale in a given year

The sale view deducts, in this order:

1. **Resale costs** (`SaleCosts`): a flat amount for mandatory diagnostics, plus a
   refurbishment that grows with the square root of the surface (twice the surface isn't
   twice the work). Both grow with inflation. The sale is assumed to be between individuals,
   so there's no agency fee. The costs don't lower the taxable gain: only an agency fee or
   invoiced works would, and Prunay simulates neither.
2. **The capital gain tax** (see [taxation](taxation.md)).
3. **The outstanding capital and the early repayment fee** (see [credit](credit.md)).

## Internal rate of return

The IRR for each year uses the cash flows the operation would have had if it had stopped
that year:

- the day-one outlay;
- every year's cash flow;
- the resale proceeds, added to the last year.

It is the annual rate that brings their present value to zero, found by bisection since there
is no closed form. The signature day has no rate, having only one cash flow, and neither does
an operation that never pays anything back. It is the one figure on which the four regimes
compare directly.

## Comparison and list

- **Comparison**: two server-rendered SVG charts, each with the four regimes on the same
  axes, 31 points each:
  - the capital still immobilized, which crosses zero when the operation has paid for itself;
  - the profit a resale would leave that year.

  Both scales always include zero, because the crossing is what the reader looks for.
- **List of simulations**: each property is ranked by its best exit, the highest IRR across
  every regime and every resale year.
