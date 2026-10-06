# Inputs

What the user answers, and what Prunay supposes until they answer otherwise. Only an answer
is stored. Everything derived from the answers is recomputed every time: notary fees, capital
borrowed, payment, schedule, projection, tax.

## The answers

A simulation is created in one of two ways:

- **Page by page**: property, purchase, credit, letting, annual charges. The credit page only
  opens when the purchase is financed by a loan. Nothing is saved before the last page, and
  each page validates only its own fields.
- **The quick form**: five answers (type, city, surface, price, rent). Everything else gets
  the value the full walk would have proposed. The rent may be left empty and is then
  proposed the same way.

Once the simulation exists, the user corrects each value in place, where the figure is read.
The full edit form is still there for changes that take several answers at once, such as
switching a cash purchase to a loan.

## The lots of a building

A whole building can be described lot by lot. Each answer stays on its own page: the
property page lists the lots and their surfaces, and the letting page asks each lot's rent,
provision for charges and months let. They are proposed the way they would be for a whole
property, the rent from the lot's own surface. The edit form splits them the same way
between its two groups.

As long as one lot is given, the building's own fields show what the lots add up to and
can't be typed: the sum of the surfaces, of the rents and of the charges, and the months let
averaged with each lot weighted by its rent, so that the total rent times those months is the
year's rent. The calculation itself goes lot by lot (see [projection](projection.md)). On the
simulation page the letting lists the lots in a table whose last line is these totals: they
can't be corrected in place, but each lot's own values can, like any other.

The quick form only asks for the whole, and divides a building on its own: under 100 m², two
halves; above, lots of 50 m² until less than 100 m² remain, which make the last lot (380 m²
gives six lots of 50 and one of 80). The twentieth lot, the most a building takes, keeps
whatever is left. A rent typed is shared by surface, the last lot taking the leftover cents;
left empty, each lot gets the rent proposed for its own surface, and the estimate shown in the
field is their sum.

Emptying the list goes back to answers typed for the whole building. Lots only belong to a
building: changing the property type drops them.

## Proposed amounts

The rent and most charges are proposed from a reference amount for 50 m², scaled by the
square root of the surface and rounded to 10 €. These are orders of magnitude for the user to
correct, not a calculation. The exceptions:

- **Flat, whatever the surface**: the accountant's fee.
- **Proposed at zero**: the letting agent and the rent guarantee, because neither can be
  assumed.
- **Furniture upkeep**: sized so that the furniture can be renewed every seven years, with
  ordinary upkeep on top (see the LMNP in [taxation](taxation.md)).
- **Outside an apartment**: no condominium fees are proposed (the user can still enter some),
  and the upkeep has a reference of its own in the account (1 500 € for 50 m² by default).
- **Down payment**: a tenth of the project cost, recomputed as the price is typed.

Every reference belongs to the user's account (`Assumptions`). Before the account changes
anything, no row exists and the defaults stand in for it.

## The market rent

In the hundred largest cities, the proposed rent comes from the Pierria barometer instead of
the reference amount: the city's price per m² multiplied by the surface. The barometer has
one column for small apartments, one for larger ones (the split is at 50 m²) and one for
houses. The data is a quarterly CSV versioned in `db/data`, refreshed with
`rake rent_reference:update`.

The barometer gives asking rents with charges included, so the provision for charges is
subtracted before the rent is proposed. Outside those cities, and for a parking space or a
whole building, the reference amount is used instead, so no figure is invented. On the quick
form, the estimate appears as a placeholder, never as a value, so a stale figure can't be
left behind.

## Economic conditions

There are four: rent growth, property value growth, inflation (applied to charges and costs)
and the household's marginal tax bracket. Each simulation keeps its own copy, taken from the
account's defaults when it is created. Changing the defaults later never rewrites a
projection that already exists.

The same tab holds the **purchase discount**: how much more the buyer thinks the property is
worth than what they paid. The market value (price + discount) is what the projection grows
over the years. Notary fees, capital borrowed, depreciation and the fiscal value of the
capital gain all stay based on the price actually paid. A discount is therefore a gain from
day one, and it is taxed as one.

Resale costs are the exception: they are read from the account every time, so changing them
recomputes every simulation.

## The letting

- The monthly rent is entered excluding charges and as for an unfurnished letting (the
  furnished regimes add their premium to it).
- The provision for charges is what the tenant repays on top of the rent.
- Letting starts one month after the purchase unless the user says otherwise. The first year
  only counts the months after that date, and the tenant only repays the provision for those
  months.
