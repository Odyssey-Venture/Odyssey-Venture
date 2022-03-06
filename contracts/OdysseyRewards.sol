// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "./RewardsTracker.sol";

contract OdysseyRewards is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;

  string public name;
  string public symbol;

  struct HolderMap {
    address[] keys;
    mapping(address => uint) values;
    mapping(address => uint) indexOf;
    mapping(address => bool) inserted;
  }

  HolderMap private holderMap;
  uint256 public lastIndex = 0;

  struct Row { // PACKED MAX 8 VARS @ 32
    uint32 added;
    uint32 bought;
    uint32 claimed;
    uint32 excluded;
    uint32 sold;
    uint32 staked;
    uint32 percent;
    uint32 tbd;
  }

  mapping (address => Row) public holder;

  uint256 public minimumBalance = 15_000_000 ether; // must hold 15,000,000+ tokens
  uint256 public waitingPeriod = 6 hours;
  bool public isStakingOn = false;
  uint256 public totalTracked = 0;

  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastIndex, uint256 gasUsed);
  event ExcludedChanged(address indexed account, bool excluded);
  event MinimumBalanceChanged(uint256 from, uint256 to);
  event StakingChanged(bool from, bool to);
  event WaitingPeriodChanged(uint256 from, uint256 to);

  constructor(string memory name_, string memory symbol_) RewardsTracker() {
    name = name_;
    symbol = symbol_;
    holder[address(this)].excluded = stamp();
  }

  function getHolderCount() external view returns(uint256) {
    return holderMap.keys.length;
  }

  function getReport() external view returns (uint256 holderCount, bool stakingOn, uint256 totalTokensTracked, uint256 totalTokensStaked, uint256 totalRewardsPaid, uint256 requiredBalance, uint256 waitPeriodSeconds) {
    holderCount = holderMap.keys.length;
    stakingOn = isStakingOn;
    totalTokensTracked = totalTracked;
    totalTokensStaked = totalBalance;
    totalRewardsPaid = totalDistributed;
    requiredBalance = minimumBalance;
    waitPeriodSeconds = waitingPeriod;
  }

  function getReportAccount(address key) public view returns (address account, int index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    account = key;
    excluded = (holder[account].excluded > 0);
    index = excluded ? -1 : holderMapIndex(account);
    tokens = excluded ? 0 : unstakedBalanceOf(account);
    stakedPercent = excluded ? 0 : holder[account].percent;
    stakedTokens = excluded ? 0 : balanceOf[account];
    rewardsEarned = getAccumulated(account);
    rewardsClaimed = withdrawnRewards[account];
    claimHours = excluded ? 0 : ageInHours(holder[account].claimed);
  }

  function getReportAccountAt(uint256 indexOf) public view returns (address account, int index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    require(indexOf < holderMap.keys.length, "Value invalid");

    return getReportAccount(holderMap.keys[indexOf]);
  }

  function processClaims(uint256 gas) external onlyOwner {
    uint256 numberOfTokenHolders = holderMap.keys.length;
    if (numberOfTokenHolders == 0) return;

    uint256 pos = lastIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    bool worthy = (address(this).balance > (1 ether / 100)); // ARE THERE ENOUGH FUNDS TO WARRANT ACTION

    while (gasUsed < gas && iterations < numberOfTokenHolders) {
      pos++;
      if (pos >= holderMap.keys.length) pos = 0;
      address account = holderMap.keys[pos];
      updatedWeightedBalance(account);
      if (worthy && pushFunds(payable(account))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    lastIndex = pos;

    emit ClaimsProcessed(iterations, claims, lastIndex, gasUsed);
  }

  function setExcludedAddress(address account) external onlyOwner {
    require(holder[account].excluded==0, "Value unchanged");

    holder[account].excluded = stamp();
    putBalance(account, 0);
    holderMapRemove(account);
    emit ExcludedChanged(account, true);
  }

  // NEEDED TO REESTABLISH BALANCE WHEN INCLUDING SINCE EXCLUDING ZEROES IT OUT
  function setIncludedAddress(address account, uint256 balance) external onlyOwner {
    require(holder[account].excluded>0, "Value unchanged");

    holder[account].excluded = 0;

    if (balance > 0) {
      holderMapSet(account, balance);
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

  function ageInDays(uint32 stamped) private view returns (uint32) {
    return ageInHours(stamped) / 24;
  }

  function ageInHours(uint32 stamped) private view returns (uint32) {
    return stamped==0 ? 0 : (stamp() - stamped) / 1 hours;
  }

  function ageInWeeks(uint32 stamped) private view returns (uint32) {
    return ageInDays(stamped) / 7;
  }

  function canClaim(uint48 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= waitingPeriod;
  }

  function setBalance(address payable account, uint256 newBalance) private {
    if (newBalance < minimumBalance) { // BELOW MIN DOES NOT QUALIFY
      totalTracked -= unstakedBalanceOf(account);
      putBalance(account, 0);
      holderMapRemove(account); // REMOVE FROM ARRAY TO THIN STORAGE
      return;
    }

    if (newBalance > unstakedBalanceOf(account)) {
      totalTracked += newBalance.sub(unstakedBalanceOf(account));
    } else if(newBalance < unstakedBalanceOf(account)) {
      totalTracked -= unstakedBalanceOf(account).sub(newBalance);
    }

    holderMapSet(account, newBalance);
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
    uint256 balance = unstakedBalanceOf(account);
    if (!isStakingOn || balance==0 || holder[account].percent > 99) return balance;
    return balance.mul(holder[account].percent).div(100);
  }

  function updatedWeightedBalance(address account) internal {
    if (holder[account].percent==stakePercent(account)) return; // NO CHANGE
    putWeighted(account); // REWEIGHT TOKENS
  }

  // HOLDERMAP FUNCTIONS

  function unstakedBalanceOf(address key) internal view returns (uint) {
    return holderMap.values[key];
  }

  function holderMapIndex(address key) internal view returns (int) {
    if (!holderMap.inserted[key]) return -1;

    return int(holderMap.indexOf[key]);
  }

  function holderMapSet(address key, uint val) internal {
    if (holderMap.inserted[key]) {
      holderMap.values[key] = val;
    } else {
      holderMap.inserted[key] = true;
      holderMap.values[key] = val;
      holderMap.indexOf[key] = holderMap.keys.length;
      holderMap.keys.push(key);
    }
  }

  function holderMapRemove(address key) internal {
    if (!holderMap.inserted[key]) return;

    delete holderMap.inserted[key];
    delete holderMap.values[key];
    uint index = holderMap.indexOf[key];
    uint lastIdx = holderMap.keys.length - 1;
    address lastKey = holderMap.keys[lastIdx];
    holderMap.indexOf[lastKey] = index;
    delete holderMap.indexOf[key];
    holderMap.keys[index] = lastKey;
    holderMap.keys.pop();
  }
}
