// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "./RewardsTracker.sol";

contract OdysseyRewards is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;

  string public name;
  string public symbol;

  struct Holder {
    uint256 index;
    uint256 tokens;
    uint32 added;
    uint32 bought;
    uint32 claimed;
    uint32 excluded;
    uint32 sold;
    uint32 percent;
  }

  uint256 public holders = 0;
  uint256 public currentHolder = 0;
  mapping (uint256 => address) public holderAt;
  mapping (address => Holder) public holder;

  uint256 public minimumBalance = 15_000_000 ether; // must hold 15,000,000+ tokens
  uint256 public waitingPeriod = 6 hours;
  bool public isStakingOn = false;
  uint256 public totalTracked = 0;

  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastRecord, uint256 gasUsed);
  event ExcludedChanged(address indexed account, bool excluded);
  event MinimumBalanceChanged(uint256 from, uint256 to);
  event StakingChanged(bool from, bool to);
  event WaitingPeriodChanged(uint256 from, uint256 to);

  constructor(string memory name_, string memory symbol_) RewardsTracker() {
    name = name_;
    symbol = symbol_;
    holder[address(this)].excluded = stamp();
  }

  function getReport() external view returns (uint256 holderCount, bool stakingOn, uint256 totalTokensTracked, uint256 totalTokensStaked, uint256 totalRewardsPaid, uint256 requiredBalance, uint256 waitPeriodSeconds) {
    holderCount = holders;
    stakingOn = isStakingOn;
    totalTokensTracked = totalTracked;
    totalTokensStaked = totalBalance;
    totalRewardsPaid = totalDistributed;
    requiredBalance = minimumBalance;
    waitPeriodSeconds = waitingPeriod;
  }

  function getReportAccount(address key) public view returns (address account, uint256 index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    account = key;
    excluded = (holder[account].excluded > 0);
    index = excluded ? 0 : holder[account].index;
    tokens = excluded ? 0 : holder[account].tokens;
    stakedPercent = excluded ? 0 : holder[account].percent;
    stakedTokens = excluded ? 0 : balanceOf[account];
    rewardsEarned = getAccumulated(account);
    rewardsClaimed = withdrawnRewards[account];
    claimHours = excluded ? 0 : ageInHours(holder[account].claimed);
  }

  function getReportAccountAt(uint256 indexOf) public view returns (address account, uint256 index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    require(indexOf > 0 && indexOf <= holders, "Value invalid");

    return getReportAccount(holderAt[indexOf]);
  }

  function processClaims(uint256 gas) external onlyOwner {
    if (holders==0) return;

    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations < holders) {
      bool worthy = (address(this).balance > (1 ether / 10)); // ENOUGH FUNDS TO WARRANT PUSHING?
      // IF WORTHY 1 LOOP COST MAX ~65_000 GAS, UNWORTHY MAX ~8_500 GAS
      if (gasLeft < (worthy ? 65_000 : 8_500)) break; // EXIT IF NOT ENOUGH TO PROCESS THIS ITERATION TO AVOID OOG ERROR

      currentHolder = (currentHolder % holders) + 1;
      address account = holderAt[currentHolder];
      updatedWeightedBalance(account);
      if (worthy && pushFunds(payable(account))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    emit ClaimsProcessed(iterations, claims, currentHolder, gasUsed);
  }

  function setExcludedAddress(address account) external onlyOwner {
    require(holder[account].excluded==0, "Value unchanged");

    holder[account].excluded = stamp();
    putBalance(account, 0);
    holderRemove(account);
    emit ExcludedChanged(account, true);
  }

  // NEEDED TO REESTABLISH BALANCE WHEN INCLUDING SINCE EXCLUDING ZEROES IT OUT
  function setIncludedAddress(address account, uint256 balance) external onlyOwner {
    require(holder[account].excluded>0, "Value unchanged");

    holder[account].excluded = 0;

    if (balance > 0) {
      holderSet(account, balance);
      putWeighted(account);
    }
    emit ExcludedChanged(account, false);
  }

  function setMinimumBalance(uint256 newBalance) external onlyOwner {
    require(newBalance != minimumBalance, "Value unchanged");

    emit MinimumBalanceChanged(minimumBalance, newBalance);
    minimumBalance = newBalance;
  }

  function setWaitingPeriod(uint256 inSeconds) external onlyOwner {
    require(inSeconds != waitingPeriod, "Value unchanged");
    require(inSeconds >= 1 hours && inSeconds <= 1 days, "Value invalid");

    emit WaitingPeriodChanged(waitingPeriod, inSeconds);
    waitingPeriod = inSeconds;
  }

  function setStaking(bool setting) external onlyOwner {
    require(isStakingOn!=setting, "Value unchanged");
    isStakingOn = setting;
    emit StakingChanged(!setting, setting);
  }

  function trackBuy(address payable account, uint256 newBalance) external onlyOwner {
    if (holder[account].excluded > 0) return;

    if (holder[account].added==0) holder[account].added = stamp();
    holder[account].bought = stamp();
    setBalance(account, newBalance);
  }

  function trackSell(address payable account, uint256 newBalance) external onlyOwner {
    if (holder[account].excluded > 0) return;

    holder[account].sold = stamp();
    setBalance(account, newBalance);
  }

  function withdrawFunds(address payable account) public override onlyOwner { // EMITS EVENT
    require(getPending(account) > 0, "No funds");
    require(canClaim(holder[account].claimed), "Wait time active");

    updatedWeightedBalance(account);
    holder[account].claimed = stamp();
    super.withdrawFunds(account);
  }

  // PRIVATE

  function ageInHours(uint32 stamped) private view returns (uint32) {
    return stamped==0 ? 0 : (stamp() - stamped) / 1 hours;
  }

  function ageInWeeks(uint32 stamped) private view returns (uint32) {
    return ageInHours(stamped) / 24 / 7;
  }

  function canClaim(uint48 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= waitingPeriod;
  }

  function holderSet(address key, uint256 val) private {
    if (holder[key].index==0) {
      holders++;
      holderAt[holders] = key;
      holder[key].index = holders;
    }
    holder[key].tokens = val;
  }

  function holderRemove(address key) private {
    if (holder[key].index==0) return;

    // COPY LAST ROW INTO SLOT BEING DELETED
    holder[holderAt[holders]].index = holder[key].index;
    holderAt[holder[key].index] = holderAt[holders];

    delete holderAt[holders];
    holders--;
    holder[key].index = 0;
  }

  function setBalance(address payable account, uint256 newBalance) private {
    if (newBalance < minimumBalance) { // BELOW MIN DOES NOT QUALIFY
      totalTracked -= holder[account].tokens;
      putBalance(account, 0);
      holderRemove(account); // REMOVE FROM ARRAY TO THIN STORAGE
      return;
    }

    if (newBalance > holder[account].tokens) {
      totalTracked += newBalance.sub(holder[account].tokens);
    } else if(newBalance < holder[account].tokens) {
      totalTracked -= holder[account].tokens.sub(newBalance);
    }

    holderSet(account, newBalance);
    putWeighted(account);

    if (getPending(account) <= 0) return; // NOTHING PENDING WE ARE DONE HERE
    // PUSH FUNDS TO ACCOUNT W/EVENT AND UPDATE CLAIMED STAMP
    holder[account].claimed = stamp();
    super.withdrawFunds(account);
  }

  function stakePercent(address account) internal view returns (uint32) {
    if (!isStakingOn) return 100;
    uint32 stamped = holder[account].sold;
    if (stamped==0) stamped = holder[account].added;
    uint32 age = ageInWeeks(stamped);
    return (age > 4) ? 100 : 40 + 15 * age;
  }

  function stamp() private view returns (uint32) {
    return uint32(block.timestamp); // - 1231006505 seconds past BTC epoch
  }

  function pushFunds(address payable account) internal returns (bool) {
    if (!canClaim(holder[account].claimed) || getPending(account)==0) return false;

    super.withdrawFunds(account);

    holder[account].claimed = stamp();
    return true;
  }

  function putWeighted(address account) private {
    holder[account].percent = stakePercent(account);
    putBalance(account, weightedBalance(account));
  }

  function weightedBalance(address account) internal view returns (uint256) {
    uint256 balance = holder[account].tokens;
    if (!isStakingOn || balance==0 || holder[account].percent > 99) return balance;
    return balance.mul(holder[account].percent).div(100);
  }

  function updatedWeightedBalance(address account) internal {
    if (holder[account].percent==stakePercent(account)) return; // NO CHANGE
    putWeighted(account); // REWEIGHT TOKENS
  }
}
