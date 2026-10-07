# Taxation

The four regimes apply to the same property, rents and charges. Only the tax differs, and
each regime has a tab and a projection of its own.

## Shared by every regime (`Taxation::Regime`)

- **Income tax**: the household's marginal bracket (0, 11, 30, 41 or 45 %).
- **Social charges**: due even when no bracket applies, and counted separately from income
  tax.
- **No deficit carried forward, under any regime.** A year with no gain owes nothing, and
  nothing passes to the next year.

Each regime defines its own taxable base, allowance, social charges rate and its own charges
(charges only that regime pays, which the projection adds to the year's charges).

## Unfurnished letting

The provision for charges is not income, since it covers an expense, so the base is the rent
excluding charges. Social charges are 17.2 %.

- **Micro-foncier**: a flat 30 % allowance replaces every deductible charge. Only open while
  the year's rent excluding charges stays within 15 000 € (art. 32 CGI); above it the regime
  isn't offered at all. The check reads the entered rent over the months let, so a rent that
  grows past the ceiling later keeps the regime, and the household's other rents aren't known.
- **Foncier réel**: no allowance. The year's charges and the loan interest, insurance
  included, are deducted.

## Furnished letting (`Taxation::Bic`)

A furnished rent is a business receipt, not property income, and that changes three things:

- **The base includes the provision for charges.** The whole charges are deducted in return,
  so the result before tax is the same either way.
- **Social charges are 18.6 %, not 17.2 %.** The 2026 social security financing act raised
  the CSG on capital income to 10.6 %, sparing only property income and property capital
  gains.
- **The CFE is due.** It is a tax on the premises, not on income, so it counts as a charge of
  the year, above the result before tax. Its real base (the rental value set by the commune)
  can't be known, so Prunay uses 30 % of one monthly rent of the year. It isn't asked of the
  user.

**Rent**: a furnished property lets for more than an unfurnished one. The entered rent gets a
5 % premium, which the receipts, the cash flow and the CFE all follow. The charges stay those
of an unfurnished letting.

**Furniture**: it is asked for on the purchase page and paid in cash at the signature, never
borrowed. It counts in the project cost, the initial outlay and the immobilized capital, but
only under the furnished regimes. Its upkeep is a charge of the year that grows with
inflation, and only the furnished regimes pay it.

- **Micro-BIC**: a 50 % allowance on receipts, which covers every charge, the CFE included.
  Only open while the year's receipts, the 5 % premium and the provision for charges
  included, stay within 77 700 € (art. 50-0 CGI); above it the regime isn't offered. The
  law only closes it after two years above the ceiling, which a constant rent makes moot.
  As with the micro-foncier, the household's other furnished lettings aren't known.
- **LMNP**: no allowance. The charges, the CFE, the accountant (the one charge that only this
  regime pays, and only its cash flow bears) and the loan interest are deducted at cost, plus
  depreciation.

**Professional status (LMP) isn't simulated.** A household whose furnished receipts pass
23 000 € a year *and* its other activity income (wages, BIC, BNC, BA) becomes a professional
letter: social contributions instead of social charges, a deficit set against total income,
a business capital gain. Prunay doesn't know the household's activity income, so above
23 000 € of receipts the two furnished tabs only warn that their figures may not hold. The
regimes stay offered: most households earn more than they let, and stay LMNP.

## LMNP depreciation (`Taxation::DepreciationPlan`)

Each component is depreciated on a straight line from the first year let. The first year
counts in full, with no prorating, and the last annuity settles the base to the cent.

| Component | Base | Years |
|:---|:---|:---|
| Building | price + notary fees, less 15 % for land (land doesn't wear out) | 32 |
| Initial works | as entered | 12 |
| Furniture | as entered | 7 |

The durations sit in the middle of the usual ranges.

**Renewal comes out of the upkeep.** No property is kept for thirty years without a new
boiler or kitchen, and no furniture without replacing it. Prunay reads this from the two
upkeep charges instead of asking for it: half of the property upkeep is heavy works, and four
fifths of the furniture upkeep is renewal. The whole amount leaves the cash flow in the year
it is paid, under every regime. Under the LMNP only, that share isn't deducted at once. Each
year opens a new tranche, over 12 years for works and 7 for furniture, at that year's price.
The deduction is delayed, not lost.

**Depreciation can't create a deficit.** It is capped at the result before depreciation. The
rest is carried forward with no time limit (art. 39 C CGI), component by component, to the
first year with room for it. This is why an LMNP pays no tax for years. The order of
deduction (building, then works, then furniture) is Prunay's choice, not the law's. It only
matters for the capital gain, and it errs towards giving more back.

## Capital gain on resale (`Taxation::CapitalGain`)

A resale is taxed under the regime for private individuals. The gain is the sale price minus
the fiscal value:

- **Fiscal value**: price paid + notary fees, plus from the sixth year a flat 15 % for works,
  which the tax office accepts without invoices. Prunay doesn't simulate the alternative
  (real works with invoices).
- **Under the LMNP**: the building depreciation actually deducted is subtracted from the
  fiscal value. The 2025 finance act adds it back into the gain; it is the price of the years
  that owed no tax on rent. What is not added back:
  - works depreciation, since the flat 15 % already stands for it;
  - furniture depreciation, since furniture is movable property;
  - depreciation still waiting in the carry-forward.
- **Rates**: 19 % income tax and 17.2 % social charges, each after its own allowance for the
  years held. For income tax: nothing for five years, then 6 % a year, fully exempt after 22
  years. For social charges: 1.65 % a year, then 9 % a year, fully exempt after 30 years.
- **Not simulated**: the surtax on gains above 50 000 €.
