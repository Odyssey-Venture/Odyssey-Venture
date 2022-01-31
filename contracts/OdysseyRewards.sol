// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "./RewardsTracker.sol";
import "./IterableMapping.sol";

contract OdysseyRewards is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;
  using IterableMapping for IterableMapping.Map;

  IterableMapping.Map private tokenHoldersMap;
  uint256 public lastProcessedIndex;

  mapping (address => bool) public excludedAddresses;
  mapping (address => uint256) public lastClaimTimes;

  uint256 public claimWaitingPeriod = 6 hours;
  uint256 public minimumBalance = 10_000_000; // must hold 10,000,000+ tokens
  uint256 public minimumBalanceExtended; // EXTENDED TO 10e18
  address constant ZERO = 0x0000000000000000000000000000000000000000;

  event ClaimWaitingPeriodChanged(uint256 indexed from, uint256 indexed to);
  event ClaimedRewards(address indexed account, uint256 amount, bool indexed automatic);
  event ExcludedFromRewards(address indexed account, bool isExcluded);
  event MinimumBalanceChanged(uint256 indexed from, uint256 indexed to);
  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastIndex, uint256 gasUsed);

  constructor() RewardsTracker("OdysseyRewards", "ODSYRV1") {
    excludedAddresses[address(this)] = true;
    minimumBalanceExtended = minimumBalance * 1 ether;
  }

  function getAccountInfo(address accoont) public view returns (address account, int256 index, int256 iterationsUntilProcessed, uint256 pendingRewards, uint256 totalRewards, uint256 lastClaimTime, uint256 nextClaimTime, uint256 secondsUntilAutoClaimAvailable) {
    account = accoont;
    index = tokenHoldersMap.getIndexOfKey(account);
    iterationsUntilProcessed = -1;
    if (index >= 0) {
      if (uint256(index) > lastProcessedIndex) {
        iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
      } else {
        uint256 processesUntilEndOfArray = (tokenHoldersMap.keys.length > lastProcessedIndex) ? tokenHoldersMap.keys.length.sub(lastProcessedIndex) : 0;
        iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
      }
    }

    pendingRewards = getPending(account);
    totalRewards = getAccumulated(account);
    lastClaimTime = lastClaimTimes[account];
    nextClaimTime = (lastClaimTime > 0) ? lastClaimTime.add(claimWaitingPeriod) : 0;
    secondsUntilAutoClaimAvailable = (nextClaimTime > block.timestamp) ? nextClaimTime.sub(block.timestamp) : 0;
  }

  function getAccountInfoAtIndex(uint256 index) external view returns (address, int256, int256, uint256, uint256, uint256, uint256, uint256) {
    if (index >= tokenHoldersMap.size()) return (ZERO, -1, -1, 0, 0, 0, 0, 0);

    address account = tokenHoldersMap.getKeyAtIndex(index);
    return getAccountInfo(account);
  }

  function getHolderCount() external view returns(uint256) {
    return tokenHoldersMap.keys.length;
  }

  function processClaim(address payable account, bool automatic) public onlyOwner returns (bool) {
    uint256 amount = processWithdraw(account);
    if (amount > 0) {
      lastClaimTimes[account] = block.timestamp;
      emit ClaimedRewards(account, amount, automatic);
    }
    return (amount > 0);
  }

  function processClaims(uint256 gas) external onlyOwner {
    if (address(this).balance < 1 ether) return; // SAVE GAS, ONLY PROCESS AFTER CONTRACT HAS SOMETHING WORTH SPLITTING

    uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
    if (numberOfTokenHolders == 0) return;

    uint256 _lastProcessedIndex = lastProcessedIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations < numberOfTokenHolders) {
      _lastProcessedIndex++;
      if (_lastProcessedIndex >= tokenHoldersMap.keys.length) _lastProcessedIndex = 0;
      address account = tokenHoldersMap.keys[_lastProcessedIndex];
      if (canAutoClaim(lastClaimTimes[account]) && processClaim(payable(account), true)) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    lastProcessedIndex = _lastProcessedIndex;

    emit ClaimsProcessed(iterations, claims, lastProcessedIndex, gasUsed);
  }

  function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    if (excludedAddresses[account]) return;
    if (newBalance >= minimumBalanceExtended) { // * 10e18
      changeBalance(account, newBalance);
      tokenHoldersMap.set(account, newBalance);
    } else {
      changeBalance(account, 0);
      tokenHoldersMap.remove(account);
    }
    processClaim(account, true);
  }

  function setClaimWaitingPeriod(uint256 secondsBetweenClaims) external onlyOwner {
    require(secondsBetweenClaims != claimWaitingPeriod, "OdysseyRewards: Value already set");
    require(secondsBetweenClaims >= 1 hours && secondsBetweenClaims <= 1 days, "OdysseyRewards: claimWaitingPeriod must be between 1 and 24 hours");
    emit ClaimWaitingPeriodChanged(claimWaitingPeriod, secondsBetweenClaims);
    claimWaitingPeriod = secondsBetweenClaims;
  }

  function setExcludedAddress(address account, bool exclude) external onlyOwner {
    require(excludedAddresses[account] != exclude, "OdysseyRewards: Value already set");

    excludedAddresses[account] = exclude;
    emit ExcludedFromRewards(account, exclude);
  }

  function setMinimumBalance(uint256 newBalance) external onlyOwner {
    require(newBalance != minimumBalance, "OdysseyRewards: Value already set");
    emit MinimumBalanceChanged(minimumBalance, newBalance);
    minimumBalance = newBalance;
    minimumBalanceExtended = minimumBalance * 1 ether; // EXTENDED TO 10e18 // * 10e18
  }

  // PRIVATE

  function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= claimWaitingPeriod;
  }
}
