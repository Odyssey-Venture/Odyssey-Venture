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

  uint256 public dividends = 10;
  uint256 public funds = 0;

  uint256 public constant APPROVAL_PERCENT = 50;

  address public withdrawTo = address(0);
  uint256 public withdrawExpires = 0;
  uint256 public withdrawAmount = 0;

  IterableMapping.Map private holdersMap;
  uint256 public lastIndex = 0;

  struct Holder { // UP TO 8 PACKED VARS @ 32
    uint32 added;
    uint32 claimed;
    uint32 shares;
    uint32 approved;
  }

  mapping (address => Holder) public holder;

  uint256 constant MINIMUMBALANCE = 1;
  uint256 public waitingPeriod = 1 hours;

  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastIndex, uint256 gasUsed);

  constructor(string memory name_, string memory symbol_) RewardsTracker() {
    name = name_;
    symbol = symbol_;
  }

  function approveWithdraw() external {
    require(balanceOf[msg.sender] > 0, "No shares");
    require(withdrawTo!=address(0), "No pending request");
    require(holder[msg.sender].approved==0, "Already approved");

    if (withdrawExpired()) return withdrawReset();

    holder[msg.sender].approved = stamp();

    if (withdrawApproved()) processWithdrawRequest();
  }

  function requestWithdraw(uint256 amount) external {
    require(balanceOf[msg.sender] > 0, "No shares");
    require(funds > amount, "Overdraft");
    require(withdrawExpires < block.timestamp, "Pending request active");

    withdrawReset();

    withdrawTo = msg.sender;
    withdrawAmount = amount;
    withdrawExpires = block.timestamp + 6 hours;
    holder[msg.sender].approved = stamp();

    // emit fundsrequest
  }

  function unapproveWithdraw() external {
    require(balanceOf[msg.sender] > 0, "No shares");
    require(holder[msg.sender].approved > 0, "Not approved");

    if (withdrawExpired() || msg.sender==withdrawTo) return withdrawReset();

    holder[msg.sender].approved = 0;
  }

  function getReport() public view returns (uint256 holderCount, uint256 totalShares, uint256 totalDividends) {
    holderCount = holdersMap.keys.length;
    totalShares = totalBalance;
    totalDividends = totalDistributed;
  }

  function getReportAccount(address account) public view returns (uint256 shares, uint256 dividendsEarned, uint256 dividendsClaimed) {
    shares = balanceOf[account];
    dividendsEarned = getAccumulated(account);
    dividendsClaimed = withdrawnRewards[account];
  }

  function getReportAccountAt(uint256 index) public view returns (address account, uint256 shares, uint256 dividendsEarned, uint256 dividendsClaimed) {
    require(index < holdersMap.keys.length, "Invalid value");

    account = holdersMap.keys[index];
    shares = balanceOf[account];
    dividendsEarned = getAccumulated(account);
    dividendsClaimed = withdrawnRewards[account];
  }

  function setHolders(address[] memory wallets, uint256[] memory amounts) external onlyOwner {
    require(totalBalance==0, "Shares already set.");
    require(wallets.length < 100, "100 wallets max");

    uint256 sum = 0;
    for (uint256 idx=0;idx<wallets.length;idx++) sum += amounts[idx];
    require(sum==1000, "1000 shares required");
    for (uint256 idx=0;idx<wallets.length;idx++) setBalance(wallets[idx], amounts[idx]);
  }

  function totalApproval() public view returns(uint256) {
    uint256 sum = 0;
    for (uint256 idx=0; idx<holdersMap.keys.length; idx++) {
      address account = holdersMap.keys[idx];
      if (holder[account].approved > 0) sum += balanceOf[holdersMap.keys[idx]];
    }
    return sum;
  }

  function processClaims(uint256 gas) external {
    uint256 keyCount = holdersMap.keys.length;
    if (keyCount == 0) return;

    uint256 pos = lastIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations < keyCount) {
      pos++;
      if (pos >= holdersMap.keys.length) pos = 0;
      address account = holdersMap.keys[pos];
      if (pushFunds(payable(account))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    lastIndex = pos;

    emit ClaimsProcessed(iterations, claims, lastIndex, gasUsed);
  }

  function withdrawFunds(address payable account) public override { // EMITS EVENT
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

  function distributeFunds(uint256 amount) internal override {
    uint256 share = amount.mul(dividends).div(100);
    funds += amount.sub(share);
    super.distributeFunds(share);
  }

  function setBalance(address account, uint256 newBalance) internal {
    if (newBalance >= MINIMUMBALANCE) {
      putBalance(account, newBalance);
      holdersMap.set(account, newBalance);
      holder[account].added = stamp();
    } else {
      putBalance(account, 0);
      holdersMap.remove(account);
    }
  }

  function stamp() private view returns (uint32) {
    return uint32(block.timestamp); // - 1231006505 seconds past BTC epoch
  }

  function processWithdrawRequest() internal {
    if (withdrawTo!=address(0) && withdrawAmount > 0 && withdrawAmount < funds) {
      funds -= withdrawAmount;
      (bool success,) = payable(withdrawTo).call{value: withdrawAmount, gas: 3000}("");
      if (!success) funds += withdrawAmount;
    }
    withdrawReset();
  }

  function pushFunds(address payable account) internal returns (bool) {
    if (!canClaim(holder[account].claimed) || getPending(account)==0) return false;

    super.withdrawFunds(account);

    holder[account].claimed = stamp();
    return true;
  }

  function withdrawApproved() private view returns(bool) {
    return totalApproval() >= totalBalance.mul(APPROVAL_PERCENT).div(100);
  }

  function withdrawExpired() private view returns(bool) {
    return (withdrawExpires > 0 && withdrawExpires < block.timestamp);
  }

  function withdrawReset() internal {
    if (withdrawTo == address(0)) return; // NOTHING TO RESET

    for (uint256 idx=0; idx<holdersMap.keys.length; idx++) {
      address account = holdersMap.keys[idx];
      if (holder[account].approved > 0) holder[account].approved = 0;
    }
    withdrawTo = address(0);
    withdrawAmount = 0;
    withdrawExpires = 0;
  }
}
