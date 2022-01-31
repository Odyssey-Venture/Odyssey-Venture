// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SafeMathInt.sol";
import "./SafeMathUint.sol";

contract RewardsTracker is Ownable {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  uint256 constant internal MAGNIFIER = 2**128;
  uint256 internal magnifiedBalanceOf;
  uint256 public totalBalance = 0;
  uint256 public totalDistributed;
  string public name;
  string public symbol;

  mapping(address => int256) internal magnifiedCorrections;
  mapping(address => uint256) internal withdrawnRewards;
  mapping (address => uint256) public balanceOf;

  event FundsDistributed(address indexed from, uint256 amount);
  event FundsReceived(address indexed from, uint amount);
  event SetRewardToken(address indexed from, address indexed to);

  constructor(string memory name_, string memory symbol_) {
    name = name_;
    symbol = symbol_;
  }

  receive() external payable {
    emit FundsReceived(msg.sender, msg.value);
    distributeFunds();
  }

  function getAccumulated(address account) public view returns(uint256) {
    return magnifiedBalanceOf.mul(balanceOf[account]).toInt256Safe().add(magnifiedCorrections[account]).toUint256Safe() / MAGNIFIER;
  }

  function getPending(address account) public view returns(uint256) {
    return getAccumulated(account).sub(withdrawnRewards[account]);
  }

  function getWithdrawn(address account) external view returns(uint256) {
    return withdrawnRewards[account];
  }

  // PRIVATE

  function changeBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf[account];
    balanceOf[account] = newBalance;
    if (newBalance > currentBalance) {
      uint256 increaseAmount = newBalance.sub(currentBalance);
      increaseBalance(account, increaseAmount);
      totalBalance += increaseAmount;
    } else if(newBalance < currentBalance) {
      uint256 reduceAmount = currentBalance.sub(newBalance);
      decreaseBalance(account, reduceAmount);
      totalBalance -= reduceAmount;
    }
  }

  function decreaseBalance(address account, uint256 value) internal {
    magnifiedCorrections[account] = magnifiedCorrections[account].add((magnifiedBalanceOf.mul(value)).toInt256Safe());
  }

  function distributeFunds() internal {
    require(totalBalance > 0);
    uint256 amount = msg.value;
    if (amount > 0) {
      magnifiedBalanceOf = magnifiedBalanceOf.add((amount).mul(MAGNIFIER) / totalBalance);
      totalDistributed = totalDistributed.add(amount);
      emit FundsDistributed(msg.sender, amount);
    }
  }

  function increaseBalance(address account, uint256 value) internal {
    magnifiedCorrections[account] = magnifiedCorrections[account].sub((magnifiedBalanceOf.mul(value)).toInt256Safe());
  }

  function processWithdraw(address payable user) internal returns (uint256) {
    uint256 rewards = getPending(user);
    if (rewards <= 0) return 0;
    withdrawnRewards[user] = withdrawnRewards[user].add(rewards);
    (bool success,) = user.call{value: rewards, gas: 3000}("");
    if (!success) {
      withdrawnRewards[user] = withdrawnRewards[user].sub(rewards);
      return 0;
    }
    return rewards;
  }
}
