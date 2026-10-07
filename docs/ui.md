# Interface

`app/assets/stylesheets`: `tokens.css`, `base.css`, `layout.css`, `components/`, `features/`.

Prunay has a small design system: a handful of tokens, about fifteen primitives, and a few
styles that belong to one screen only. A new page is built from the primitives. When a page
seems to need a new class, the first question is which primitive already does the job. The
second is whether the need is general, in which case the primitive changes and every screen
benefits.

## The stylesheets

`application.css` loads the files in order: the tokens, the base, the layout, then every file
in `components/` and every file in `features/`.

- **`components/`** holds the primitives. Nothing in them names a screen.
- **`features/`** holds what only one screen needs: the home layout, the energy-rating badge,
  the wizard's progress bar, the year statement's controls, the chart palette. A rule belongs
  here only when no other screen could use it.

Each file obeys the repository's comment caps. The reasoning lives here, not above the rules.

## Tokens

Every size, space and colour comes from `tokens.css`. A raw value in a rule (`13px`,
`0.625rem`, `#b91c1c`) is a drift: use the nearest token instead, or add a token if the scale
really lacks one.

**Type** has seven steps:

| Token | Size | Used for |
|:--|:--|:--|
| `--text-xs` | 12 px | labels above a value, notes, table headers |
| `--text-sm` | 14 px | secondary text, buttons, fields, tabs |
| `--text-base` | 16 px | body text, `h3` |
| `--text-lg` | 18 px | panel and modal titles, `h2` on mobile |
| `--text-xl` | 20 px | `h2`, key figures on mobile |
| `--text-2xl` | 24 px | `h1`, key figures |
| `--text-3xl` | 40 px | the landing page title only |

Headings take their size from their level, set in `base.css`. A component does not resize
an `h2`. If a title needs to look different, it is probably not an `h2`.

**Spacing** has five steps: `--space-1` (4 px), `--space-2` (8 px), `--space-3` (16 px),
`--space-4` (24 px), `--space-5` (32 px). Gaps inside a component use 1 to 3. Space
between blocks uses 4 or 5. Widths (a column of 22rem, a field of 7.5rem) are layout
sizes, not spacing, and stay in rem.

## Colour and its meaning

- **Primary blue** marks what can be acted on: the main button, the active tab, a
  highlighted panel, a focused field.
- **Green and red** say one thing only: the sign of an amount. `tone(amount)` returns
  `is-positive`, `is-negative` or nothing for zero. Use it on results that can go either way
  (cash flow, sale profit, the total of an addition). Do not use it on an input, a cost that
  is always positive, or to make a figure stand out. The rent is not green just because it is
  income.
- **A rate** is only coloured when it is negative: `rate_tone(rate)`. A positive return is
  the normal case, not news.
- **Red is also destructive**, through `.btn-danger`, and **errors**, through `.alert-danger`.
- **Amber** is for warnings (`.alert-warning`) and nothing else.
- **The charts** have their own palette, one colour per regime and one per budget item, in
  `features/charts.css`. It is data, not interface.

## Labels

A label is always visually secondary: grey, and never bolder than the value it names.
There are two forms:

- **Above a value** (`.label`): small, uppercase, grey. Used on key-figure panels, on card
  figures, in `detail-grid`, and on table headers, which share the same declaration.
- **Beside a value** (`.detail-label` in `.rows`): normal case and size, grey. Only a
  subtotal or total label is dark, because it names the result.

Form labels are grey too. A remark under a label is a `.note`, and never a new line in the
list.

## Amounts

- **Rounded to the euro** (`euros(amount)`) wherever a figure is read at a glance: cards,
  key figures, the regimes table, the projection table, chart labels, warnings.
- **To the cent** (`number_to_currency(amount)`) wherever the reader must be able to redo
  the arithmetic, or check it against a document: an addition in `.rows` (purchase, charges,
  the breakdown of where the money goes), the year statement, and the whole credit tab,
  which mirrors the bank's schedule.
- Within one list, every amount has the same precision.
- The locale separates thousands with a narrow no-break space and puts a no-break space
  before `€` and `%`, as the browser's `Intl.NumberFormat` does. An amount never breaks
  across two lines, and no rule needs to protect it.
- A table cell of figures carries `.num`: tabular digits, no wrapping, right alignment. The
  values of `.rows` already behave that way.

## Primitives

**Surfaces**

- `.panel` is the only framed surface: a list card, a key figure, a form, a chart, a list of
  lines. `.panel-highlight` gives it a blue border (the figure that matters most). Add
  `.panel-link` with a `.panel-link-target` link inside to make the whole panel clickable.
  `.panel-header`, `.panel-title`, `.panel-footer` and `.panel-corner` arrange its content.
  Inside a modal, a panel loses its frame on its own.
- `.stack` stacks children with an even gap.
- `.panel-grid` lays out cards and `.stat-grid` lays out key figures. Both drop to fewer
  columns on their own.

**Text**: `.label`, `.hint` (grey secondary text), `.intro` (a hint paragraph under a
heading, with space below), `.note`, `.figure` (the large number of a key figure), `.num`.

**Lines**: `.rows` holds `.detail-item` elements, each a `.detail-label` and a
`.detail-value`. `.detail-subtotal` and `.detail-total` close an addition, and in a
`.columns` layout the totals of neighbouring panels line up. `.detail-breakdown` indents
the calculation of a line under it. `.detail-grid` lays out the same items as a grid of
cards, label above value. The parameters, the breakdown, the credit and the year statement
all use these classes. Do not create another row style.

**Actions**

- `.btn` plus one variant: `.btn-primary`, `.btn-outline` or `.btn-danger`. `.btn-sm` and
  `.btn-lg` change the size. A disabled `.btn` fades and takes no click.
- `.icon-btn` is a square button for a glyph: ‹ › ×. It is used to close a modal, to step
  through a carousel or a year, and to dismiss a message. `.icon-btn-inline` drops the frame
  and takes the size of the text, for a glyph that sits in a dense row, such as a lot's ×.
  `.stepper` groups arrows around a value.
- `.chip` is a toggle: a radio inside a label (the type filter), or a button with
  `aria-pressed` (the statement's detail switch). `.chip-group` lines chips up, and
  `.chip-group-scroll` lets them scroll on one line on mobile.
- `.actions` is the row of buttons at the end of a form or a page.

**Structure**: `.page-header` (the `h1` and at most one action), `.section` and
`.section-header` (an `h2` and its control: a stepper or a button), `.subsection-title`,
`.columns` and `.column`, `.tabs` and `.tab`, `.modal` (`.modal-narrow`, `.modal-header`,
`.modal-title`, `.modal-actions`, `.modal-body`) on a native `<dialog>`, and `.table` inside
`.table-scroll`. Inside a panel, a table loses its frame and lines up with the panel's rows;
its `tfoot` is a subtotal.

**Feedback**: `.alert` (`-success`, `-danger`, `-warning`, and `.alerts` for a list of them),
`.empty-state`, and `.help`, the question mark whose explanation shows on hover or focus.

**Forms**: `.form`, `.form-group`, `.form-row` with `.form-group-half`, `.form-control`,
`.form-check`, `.form-fieldset`, `.form-static` (a computed amount shaped like a field),
`.assumption-grid` and `.assumption-field` (a label and a short field on one line), and the
inline editing classes.

## Primary and destructive actions

- A page has at most one `.btn-primary`: the action the page exists for (create, continue,
  save). Everything else is `.btn-outline`. A page with nothing to create or save, such as the
  simulation page, has no primary button.
- A destructive action is never primary and never a solid block of colour. `.btn-danger` is
  red on white, and inside `.actions` it moves to the end of the row, away from the other
  buttons. It always asks for confirmation (`turbo_confirm`).

## Mobile

The app must work at 375 px. There is one breakpoint for phones, `max-width: 768px`, and one
for wide layouts, `min-width: 900px`. Each component handles its own small screen, in its own
file, so a page never needs to.

What already happens on its own:

- The gutter drops to 16 px, panels tighten, `h2` drops one step, key figures drop to
  `--text-xl`.
- Headers wrap: `.page-header`, `.section-header` and `.actions` send their controls to the
  next line instead of squeezing the title. For a long button label, give the short version
  with `.hide-on-mobile` and `.show-on-mobile`, as the list page does.
- `.form-row` stacks its halves when they don't fit. Fields use 16 px text so iOS does not
  zoom on focus.
- `.tabs` stay on one line and scroll. The regime dropdown is placed by `tabs_controller`, so
  the scroll does not clip it.
- A table scrolls inside `.table-scroll`. Its cells never wrap, and its first column stays in
  place.
- A chart keeps a readable width inside `.chart-plot` and scrolls.
- The `.help` explanation opens as a bar at the bottom of the screen.
- The wizard's progress bar only names the current step.

After changing a screen, check it at 375 px. The page itself must never scroll sideways.

## Building or changing a screen

1. Start from the primitives. Page title in `.page-header`, blocks in `.section`, framed
   content in `.panel`, figures in `.rows` or a `.stat-grid`, buttons in `.actions`.
2. Before writing a class, search `components/` for the need: "a box", "a row with a number
   on the right", "a small grey text". It is almost always there.
3. If a primitive is missing something every screen would want, change the primitive. If
   only this screen needs it, add a rule to `features/` and name it after the screen.
4. Never style a class that only exists as a test hook. A spec selects by primitive and
   structure (`.simulation-card .panel-footer dd`), or by a name that carries no style.
5. Colour by sign with `tone`, round with `euros`, and never pick a text colour by hand.
6. Any visible text goes through `config/locales/fr.yml`.

Drifts that tend to creep back in:

- A new `-card`, `-box` or `-panel` class that redoes the border, radius and shadow of
  `.panel`.
- A local `font-size` or `margin` in rem outside the scales.
- A second primary button on a page, or a solid red button.
- Green used to decorate a positive figure that is not a signed result.
- A `@media` rule in a screen's file that patches a primitive instead of fixing it.
- An `.x[hidden] { display: none }` rule: `base.css` already makes `hidden` win everywhere.
