# Credit

`Loan` and `AmortizationSchedule`.

## The loan

The credit page asks for three things: a rate, a duration and the insurance premium. The
capital borrowed is derived: the project cost minus the down payment. Furniture is never
borrowed. The monthly payment follows the constant-annuity formula, rounded to the cent:

    M = C × i / (1 − (1 + i)^−n)

The schedule works like Milly's: interest on the outstanding capital, principal for the
rest, and the last payment settles the rounding residue. The difference is the direction:
Milly copies a payment already negotiated, while Prunay computes the payment that a rate and
a duration imply.

Repayment starts on the 5th after the signature: the 5th of the same month if the deed is
signed between the 1st and the 5th, otherwise the 5th of the following month.

## Borrower's insurance

The premium is monthly. It is proposed as a yearly rate of the capital borrowed and corrected
once the loan offer gives the real figure. It is computed on the capital borrowed on day one,
not on the outstanding capital, so it stays the same until the last payment and repays none
of the capital. It has its own column in the schedule and adds to the monthly debit. The cost
of the credit is interest plus insurance.

## Early repayment

When the property is sold before the loan's term, the bank charges 3 % of the capital
repaid, capped at six months of interest. Below a 6 % rate the cap always applies, which
comes to half the rate applied to what is still owed. The fee falls to zero in the year the
loan is paid off.
