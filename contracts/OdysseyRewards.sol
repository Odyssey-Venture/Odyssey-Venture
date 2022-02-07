// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "./RewardsTracker.sol";
import "./IterableMapping.sol";

contract OdysseyRewards is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;
  using IterableMapping for IterableMapping.Map;

  string public name;
  string public symbol;

  IterableMapping.Map private tokenHoldersMap;
  uint256 public lastIndex = 0;

  mapping (address => bool) public isExcluded;
  mapping (address => uint256) public lastClaimAt;

  uint256 public minimumBalance = 10_000_000; // must hold 10,000,000+ tokens
  uint256 public minimumBalanceExtended; // EXTENDED TO 10e18
  uint256 public waitingPeriod = 6 hours;

  // event ClaimedRewards(address indexed account, uint256 amount, bool automatic);
  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastIndex, uint256 gasUsed);
  event IsExcludedChanged(address indexed account, bool excluded);
  event MinimumBalanceChanged(uint256 from, uint256 to);
  event WaitingPeriodChanged(uint256 from, uint256 to);

  constructor(string memory name_, string memory symbol_) RewardsTracker() {
    name = name_;
    symbol = symbol_;
    isExcluded[address(this)] = true;
    minimumBalanceExtended = minimumBalance * 1 ether;
  }

  function getHolderCount() external view returns(uint256) {
    return tokenHoldersMap.keys.length;
  }

  function getSettings() public view returns (uint256 rewardsDistributed, uint256 minBalance, uint256 waitPeriodSeconds, uint256 holderCount, uint256 nextIndex) {
    rewardsDistributed = totalDistributed;
    minBalance = minimumBalance;
    waitPeriodSeconds = waitingPeriod;
    holderCount = tokenHoldersMap.keys.length;
    nextIndex = lastIndex;
  }

  function getReport(address account) public view returns (bool accountExcluded, uint256 accountIndex, uint256 nextIndex, uint256 trackedBalance, uint256 totalRewards, uint256 claimedRewards, uint256 pendingRewards, uint256 lastClaimTime, uint256 nextClaimTime, uint256 secondsRemaining) {
    accountExcluded = isExcluded[account];
    accountIndex = accountExcluded ? 0 : tokenHoldersMap.getIndexOfKey(account).toUint256Safe();
    nextIndex = accountExcluded ? 0 : lastIndex;
    trackedBalance = balanceOf[account];
    totalRewards = getAccumulated(account);
    claimedRewards = withdrawnRewards[account];
    pendingRewards = totalRewards.sub(claimedRewards);
    lastClaimTime = accountExcluded ? 0 : lastClaimAt[account];
    nextClaimTime = accountExcluded ? 0 : (lastClaimTime > 0) ? lastClaimTime.add(waitingPeriod) : 0;
    secondsRemaining = accountExcluded ? 0 : (nextClaimTime > block.timestamp) ? nextClaimTime.sub(block.timestamp) : 0;
  }

  function processClaims(uint256 gas) external onlyOwner {
    if (address(this).balance < 1 ether) return; // SPLIT AT MIN 1 BSD

    uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
    if (numberOfTokenHolders == 0) return;

    uint256 pos = lastIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations < numberOfTokenHolders) {
      pos++;
      if (pos >= tokenHoldersMap.keys.length) pos = 0;
      address account = tokenHoldersMap.keys[pos];
      if (pushFunds(payable(account))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    lastIndex = pos;

    emit ClaimsProcessed(iterations, claims, lastIndex, gasUsed);
  }

  function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    if (isExcluded[account]) return;

    if (newBalance >= minimumBalanceExtended) { // * 10e18
      putBalance(account, newBalance);
      tokenHoldersMap.set(account, newBalance);
      // PUSH FUNDS TO ACCOUNT W/EVENT
      if (getPending(account) <= 0) return;
      lastClaimAt[account] = block.timestamp;
      super.withdrawFunds(account);
    } else {
      putBalance(account, 0);
      tokenHoldersMap.remove(account);
    }
  }

  function setExcludedAddress(address account) external onlyOwner {
    require(isExcluded[account]==false, "Value unchanged");

    isExcluded[account] = true;
    putBalance(account, 0);
    tokenHoldersMap.remove(account);
    emit IsExcludedChanged(account, true);
  }

  // NEEDED TO REESTABLISH BALANCE WHEN INCLUDING SINCE EXCLUDING ZEROES IT OUT
  function setIncludedAddress(address account, uint256 balance) external onlyOwner {
    require(isExcluded[account]==true, "Value unchanged");

    isExcluded[account] = false;
    if (balance > 0) {
      putBalance(account, balance);
      tokenHoldersMap.set(account, balance);
    }
    emit IsExcludedChanged(account, false);
  }

  function setMinimumBalance(uint256 newBalance) external onlyOwner {
    require(newBalance != minimumBalance, "Value unchanged");

    emit MinimumBalanceChanged(minimumBalance, newBalance);
    minimumBalance = newBalance;
    minimumBalanceExtended = minimumBalance * 1 ether; // EXTENDED TO 10e18 // * 10e18
  }

  function setWaitingPeriod(uint256 inSeconds) external onlyOwner {
    require(inSeconds != waitingPeriod, "Value unchanged");
    require(inSeconds >= 1 hours && inSeconds <= 1 days, "Value invalid");

    emit WaitingPeriodChanged(waitingPeriod, inSeconds);
    waitingPeriod = inSeconds;
  }

  function withdrawFunds(address payable account) public override { // EMITS EVENT
    require(canClaim(lastClaimAt[account]), "Wait time active");
    require(getPending(account) > 0, "No funds");

    lastClaimAt[account] = block.timestamp;
    super.withdrawFunds(account);
  }

  // PRIVATE

  function canClaim(uint256 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= waitingPeriod;
  }

  function pushFunds(address payable account) internal returns (bool) {
    if (!canClaim(lastClaimAt[account]) || getPending(account)==0) return false;

    super.withdrawFunds(account);
    lastClaimAt[account] = block.timestamp;
    return true;
  }
}
