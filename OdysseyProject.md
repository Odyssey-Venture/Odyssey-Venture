# OdysseyProject Features

OdysseyProject contract exists to provide oversight of project funds and functions,
and to repay seed investors for supplying startup funds and liquidity at launch.

## Officer Oversight

The contract defines 4 chief officer roles - 2 CEOS and 2 CFOs. These officers must
vote together to approve core project functions such as withdrawing funds or replacing
officers. This oversight mechanism is in place to ensure transparency at the highest
levels.

## Start Up Funds Repayment

The funds supplied to launch the Odyssey token will be repaid by diverting 9% of project
fees to the initial seed investors. This includes costs for initial development of the
NFT platform, smart contracts, and web sites, as well as hard dollar contributions to the
initial token liquidity. This amount will be distributed to investors proportionate to the
dollar amount invested by each to launch the token. _Once the repayment of 100% of initial
costs is complete, no more funds will be diverted to the repayment system._

As part of the repayment terms, seed investors must hold at least 10 million Odyssey tokens
in their tracked holder wallet. Dropping below the minimum will cease payments to the
investors account and proportionately increase payments to other investors. Repayments
missed while under the minimum should be considered lost.


## Officer Voting Functions

`*` In order to run these functions the caller must provide gas.

**Any disagreement between officers clears existing votes and restarts the process.**

`replaceContract`

Allows officers to vote to replace this project contract with a new one. Requires
all 4 officers to vote the same before changes take effect. When confirmed, the
Odyssey contract will be updated with the new project contract and all future
funds will be sent to the new address.

`replaceOfficer`

Allows officers to vote to replace another officer. Requires 3 officers to vote
with the same from/to addresses before changes take effect.

`requestFunds`

Allows officers to request funds from the contract. CEO requests require approval
by a CFO and vise versa. Approving officer must vote with same withdraw address/amount
before changes take effect.

`setMinimumBalance`

Allows any officer to change the minimum token requirement for seed investor loan
repayment. The initial value starts at 10m tokens and the amount can only be reduced.


## Investor Functions

`*` In order to run these functions the caller must provide gas.

`withdrawRewards` `*`

Allows an investor to manually withdraw pending claims.

`processClaims` `*`

Allows an investor to manually process pending claims for all investors.

`getReportAccount`

Displays summary report for a seed account.

* shares - investment in dollars
* dividendsEarned - amount paid back in BNB
* dividendsClaimed - amount claimed in BNB


## Public View Functions

`funds`

Displays the current BNB held by the project wallet.

`getReport`

Displays rewards system summary data

* holderCount - total investors tracked
* totalDollars - amount being repaid
* totalDividends - amount repaid so far in BNB

`minimumBalance`

Displays the minimum Odyssey token requirement for seed investor loan repayment.


## Owner Functions

`*` In order to run these functions the caller must provide gas.

`setHolders`

Allows owner to initialize the seed investors. Run the command with two arrays of
equal length that define the investor accounts and their seed dollar amounts.
This function can only be called once so get it right.

* `setHolders([_holder1_, _holder2_, ...], [_amount1_, _amount2_, ...])`

`setOfficers`

Allows owner to initialize the chief officers of the token. Run the command with
an array of wallets addresses to define the two CEO and two CFO accounts.
This function can only be called once so get it right.

* `setOfficers([_ceo1_, _ceo2_, _cfo1_, _cfo2_])`

`setToken`

Allows owner to initialize the Odyssey token contract address.
This function can only be called once so get it right.


## Disclaimer

This document attempts to accurately describe the functionality of the smart contract.
If any discrepancies arise between this document and the contract code, the code stands
as the canonical source of the truth.

***
