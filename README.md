# odyssey
# Odyssey Token Features

Odyssey token features a unique system of rewards, micro-staking and fees to encourage
holding for extended periods. All accounts holding at least 15 million tokens are eligible
to automatically earn BNB rewards that increase over time based on their last sell.

## Total Supply, Max Wallet and Max Sell Amounts

* The contract has a fully minted final supply of 50 billion tokens.
* The contract has an unchangeable max wallet size of 5 billion tokens.
* The contract has an unchangeable max sell limit of 500 million tokens.

# Fees

**Transfers** between wallets are never subjected to any fees.

**Buys** are subjected to a 2% fee that is sent to the project wallet.

**Sells** are subjected to a fee of 5% to 12% determined by the internally calculated
market cap of the token. Sell fees are split between BNB rewards to holders, BNB
liquidity pairs locked in the contract, and the project wallet. Fees are designed to
boost liquidity and stabilize the token price while the market cap is low and accelerate
development of the project roadmap, while at the same time providing generous returns
to token holders. As the market cap rises, fees will adjust to reflect the success
of the token and reward diamond handed holders.

#### Selling fees by Market Cap in BNB `*`

```
Market Cap in BNB   Rewards   Liquidity   Project   Total   Swap Threshold
under   8,000 BNB        4%          4%        4%     12%       16M tokens
under  16,000 BNB        5%          3%        3%     11%       15M tokens
under  32,000 BNB        6%          2%        2%     10%       14M tokens
under  64,000 BNB        7%          1%        1%      9%       13M tokens
under 128,000 BNB        7%           -        1%      8%       12M tokens
under 256,000 BNB        6%           -        1%      7%       11M tokens
under 512,000 BNB        5%           -        1%      6%       10M tokens
over  512,000 BNB        4%           -        1%      5%        9M tokens
```

`*` The Market Cap in BNB is calculated when tokens are converted into BNB to fund the
rewards tracker. The calculated level must remain the same for *3 consecutive readings*
before the new fee level will take effect.

* The Market Cap in BNB is calculated as `BNB from sale * Total Supply / tokens sold`
* Fees and market cap can never be changed by the owner.
* Tokens from fees are converted to BNB at swap thresholds pre-defined by market cap.

## Rewards

Rewards tokens collected from sell fees are converted into BNB. Holders meeting the
minimum required balance will automatically earn a share of these rewards. Rewards are
earned proportionate to the holder's eligible tokens in the pool of all eligible tokens.
Any holder with the minimum balance will start with 40% of their tokens added to the pool
of tokens tracked. This amount will increased by 15% for each week the holder goes without
selling until 100% is reached and they are fully vested. Any reduction of tokens, either
by selling or transferring, will drop back to 40% and restart the vesting process.

* The percent of tokens eligible to earn rewards is `40% + 15% * weeks staked` capped at 100%.

### Claiming Rewards

Holders can choose to wait for rewards to be delivered as a small number of claims
are automatically processed during each transaction depending upon the gas available.
Claims are processed in a circular order from the first holder to the last. Periods
of low transactions will process less claims so manually claiming rewards is
an option.

Holders can use the `withdrawRewards` function to manually claim pending rewards once
per waiting period.

### Rewards Reporting

Holders can use the `getRewardsReport` function to view a summary report of the rewards tracker
to date.

Holders can use the `getRewardsReportAccount` function to get a summary report of their rewards to
date.

## Liquidity Funding

Liquidity tokens collected from sell fees are paired with BNB and converted into
LP tokens. These tokens will be sent to the contract address and locked there forever.
Liquidity fees may drop to zero if the market cap gets high enough. At that point,
no more funding will go to liquidity unless a drop in market cap dictates it.

Holders can use the `balanceOfLiquidity` function to view the balance of BNB:ODSY LP tokens
held by the contract.

## Project Funding

Project tokens collected from sell fees are converted into BNB and sent to the project
wallet to be used for marketing, utility development and discretionary spending.

## Contract Functions

### Public View Functions

`balanceOfLiquidity`

Displays balance of BNB:ODSY liquidity pair tokens held by the contract.

`getRewardsReport`

Displays rewards system summary data

* holderCount - total holders eligible for rewards
* stakingOn - is sell date staking active? true/false
* totalTokensTracked - total tokens tracked by rewards system
* totalTokensStaked - total tokens staked by rewards system
* totalRewardsPaid - total amount of BNB distributed by rewards system
* requiredBalance - minimum tokens required to qualify for rewards
* waitPeriodSeconds - waiting time between manual claims

`getRewardsReportAccount`

Displays summary report for a holder account in the rewards system.

* excluded - has holder been excluded from rewards
* indexOf - holder position in processing queue
* tokens - holder tokens tracker by rewards
* stakedPercent - percent of holders tokens currently staked for rewards
* stakedTokens - holder tokens staked by rewards system
* rewardsEarned - total rewards holder has earned
* rewardsClaimed - total rewards holder has claimed
* claimHours - hours since last claim

## Holder Only Functions

`*` In order to call these functions gas must provided.

`withdrawRewards`
Allows a holder to manually withdraw pending rewards and update their staking position in the rewards
system.

## Owner Functions

`*` In order to call these functions the owner must provide gas.

`openToPublic`

Allows owner to open the contract to the public. It cannot be undone.

* Contract is closed to the public until opened by the owner. This cannot be undone.
* When opened, the BNB and tokens held by the contract is converted to LP and sent to the owner to lock.
* After opening liquidity wallet is set to the contract address and will never change.

`processRewardsClaims`

Allows owner to manually process pending token claims and update staking positions
in the rewards system.

`setAutomatedMarketMakerPair`

Allows owner to add new LP pairs to the token. Necessary to support additional token
features in the future.

`setFeeless`

Allows owner to add/remove accounts from paying fees on transactions. Necessary to
support additional token features in the future.

`setGasLimit`

Allows owner to change the amount of gas used during auto-processing of claims.

* Gas for auto-processing defaults to 300,000 wei and can be changed to a value
between 250,000 and 750,000 wei.

`setPresale`

Allows owner to add/remove accounts from the presale list that allows transferring
tokens before the contract is public.

`setProjectWallet`

Allows owner to change the address project funds are sent to.

`setRewardsExcludedAddress`

Allows owner to remove accounts from participating in rewards. Necessary to support
additional token features in the future.

`setRewardsMinimumBalance`

* The minimum required balance defaults to 15 million and can be changed to any value
between 1 and 15 million.

`setRewardsTracker`

Allows owner to switch the rewards tracker contract.

* Rewards tracker can be locked for 3 months (TODO).

`setRewardsWaitingPeriod`

Allows owner to set the time between manual reward claims.

* The waiting period between claims defaults to 6 hours and can be changed to any
value between 1 and 24 hours.

`setStaking`

Allows owner to enable/disable the last sell date staking option of the rewards system.

## Disclaimer

This document attempts to accurately describe the functionality of the smart contract.
If any discrepancies arise between this document and the contract code, the code stands
as the canonical source of the truth.

***

## Deploying Token on Remix
### 1. Flatten OdysseyProject.sol and compile

Using Remix, flatten and save the OdysseyProject.sol file. This will contain the
sources of all 3 tokens - Odyssey, OdysseyRewards and OdysseyProject. Be sure to
set the IUniswapV2Router02 to the correct Pancakeswap address for the network.
Use the following settings on Remix to compile:

* compiler: `v0.8.11+commit.d7f03943`
* optimize: `true`
* runs: `200`
* evmVersion: `spuriousDragon`

### 2. Deploy OdysseyProject token.

From the deploy tab, select `OdysseyProject - OdysseyProject_flat.sol` from the
contract droplist and click deploy. Approve the transactions on metamask and after
a few seconds you should see the new contract under `Deployed Contracts`.

### 3. Verify OdysseyProject token on bscscan.

Go to the contract on bscscan `https://testnet.bscscan.com/verifyContract?a=_project_address_`
and verify the source. Enter the following settings:

* compiler type: `solidity (single file)`
* compiler version: `v0.8.11+commit.d7f03943`
* open source license type: `mit`

Agree to terms and continue to next page. Enter the following settings:

* optimization: `yes`
* solidity contract code: copy/paste entire `OdysseyProject_flat.sol` into text area
* misc settings / runs: `200`
* misc settings / evmVersion: `spuriousDragon`

Prove you are not a robot and click `Verify and Publish`

### 4. Deploy Odyssey token.

From the deploy tab, select `Odyssey - OdysseyProject_flat.sol` from the contract
droplist and click deploy. Approve the transactions on metamask and after
a few seconds you should see the new contract under `Deployed Contracts`.

### 5. Verify Odyssey token on bscscan.

Repeat step 3 but this time verifying the Odyssey token using the same `OdysseyProject_flat.sol`
source file.

### 6. Link Odyssey and OdysseyProject tokens.

From either remix or bscscan contract tab, run the following commands on each contract:

  * Odyssey: `setProjectWallet(_project_address_)`
  * OdysseyProject: `setToken(_odyssey_address_)`

### 7. Establish OdysseyProject CEO/CFOs

The project wallet requires 4 chief officers to operate. Run the following command
with an array of addresses of the officers wallets to define the CEO and CFO accounts:

* OdysseyProject: `setOfficers([_ceo1_, _ceo2_, _cfo1_, _cfo2_])`

This action can only be done once so double check. After this is set, changing officers
will require going through the voting process using the addresses supplied.

### 8. Establish OdysseyProject Seed Investors

The project wallet requires seed investors and amounts to pay back loans. Run the
following command with two arrays of equal length to define the investor accounts
and their seed dollar amounts.

* OdysseyProject: `setHolders([_holder1_, _holder2_, ...], [_amount1_, _amount2_, ...])`

This action can only be done once ever so quadruple check the two arrays line up correctly.
The amounts supplied should be dollar amounts with no decimals.

### 9. Supply initial liquidity to Odyssey token

Send the contract BNB and tokens to be paired as initial liquidty in PanCakeSwap. The
LP tokens generated will be sent to the owner after creation to be locked.

From metamask, send initial liquidity BNB to the contract.

From either remix or bscscan contract tab, run the following commands:

  * Odyssey: `transfer(to: _odyssey_address_, amount: _half_final_supply_)`

### 10. Open contract to public

Run the following command to open the contract to public trading.

* Odyssey: `openToPublic()`

This action can only be done once ever and cannot be undone. Choose wisely.

### 11. Verify OdysseyRewards contract

Repeat step 3 but this time verifying the OdysseyRewards contract using the same `OdysseyProject_flat.sol`
source file. You will need to provide the constructor arguments `("OdysseyRewards", "ODSYRV1")` in
ABI-encoded format. The encoded data is provided below:

* Constructor Arguments ABI-encoded: `00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000e4f6479737365795265776172647300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000074f44535952563100000000000000000000000000000000000000000000000000`
