// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import './RewardsTracker.sol';
import './IterableMapping.sol';

contract OdysseyProject is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;
  using IterableMapping for IterableMapping.Map;

  string public name;
  string public symbol;

  IterableMapping.Map private tokenHoldersMap;
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

  uint256 constant MINIMUMBALANCE = 1;
  uint256 public waitingPeriod = 1 hours;
  uint256 public totalTracked = 0;

  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastIndex, uint256 gasUsed);

  constructor(string memory name_, string memory symbol_) RewardsTracker() {
    name = name_;
    symbol = symbol_;
    holder[address(this)].excluded = stamp();
  }

  function getHolderCount() external view returns(uint256) {
    return tokenHoldersMap.keys.length;
  }

  function getReport() public view returns (uint256 holderCount,  uint256 totalBalance, uint256 totalRewardsPaid) {
    holderCount = tokenHoldersMap.keys.length;
    totalBalance = totalBalance;
    totalRewardsPaid = totalDistributed;
  }

  function getReportAccount(address account) public view returns (uint256 tokens, uint256 rewardsEarned, uint256 rewardsClaimed) {
    bool excluded = (holder[account].excluded > 0);
    tokens = excluded ? 0 : balanceOf[account];
    rewardsEarned = getAccumulated(account);
    rewardsClaimed = withdrawnRewards[account];
  }

  function setWallet(address account, uint256 percent) external onlyOwner {
    require(balanceOf[account]!=percent, 'Value unchanged');
    require(totalBalance.add(percent)<=100, 'Value invalid');

    setBalance(account, percent);
  }

  function processClaims(uint256 gas) external onlyOwner {
    uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
    if (numberOfTokenHolders == 0) return;

    uint256 pos = lastIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    bool worthy = (address(this).balance > (1 ether / 100)); // ARE THERE ENOUGH FUNDS TO WARRANT ACTION

    while (gasUsed < gas && iterations < numberOfTokenHolders) {
      pos++;
      if (pos >= tokenHoldersMap.keys.length) pos = 0;
      address account = tokenHoldersMap.keys[pos];
      if (worthy && pushFunds(payable(account))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    lastIndex = pos;

    emit ClaimsProcessed(iterations, claims, lastIndex, gasUsed);
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
    require(canClaim(holder[account].claimed), 'Wait time active');
    require(getPending(account) > 0, 'No funds');

    holder[account].claimed = stamp();

    super.withdrawFunds(account);
  }

  // PRIVATE

  function canClaim(uint48 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= waitingPeriod;
  }

  function setBalance(address account, uint256 newBalance) internal onlyOwner {
    if (newBalance >= MINIMUMBALANCE) {
      putBalance(account, newBalance);
      tokenHoldersMap.set(account, newBalance);
    } else {
      putBalance(account, 0);
      tokenHoldersMap.remove(account);
    }
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
}
