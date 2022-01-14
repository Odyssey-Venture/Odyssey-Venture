// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SafeMathInt.sol";
import "./SafeMathUint.sol";
import "./DividendPayingTokenInterface.sol";
import "./DividendPayingTokenOptionalInterface.sol";

contract DividendPayingToken is Ownable, DividendPayingTokenInterface, DividendPayingTokenOptionalInterface {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  uint256 constant internal magnitude = 2**128;
  uint256 internal magnifiedDividendPerShare;
  address public dividendToken = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); // BUSD
  uint256 public totalBalance = 0;
  uint256 public totalDividendsDistributed;

  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;
  mapping (address => uint256) public balanceOf;

  event SetDividendToken(address indexed previousValue, address indexed newValue);

  receive() external payable {
    distributeDividends();
  }

  constructor () {}

  function accumulativeDividendOf(address _owner) public view override returns(uint256) {
    return magnifiedDividendPerShare.mul(balanceOf[_owner]).toInt256Safe().add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
  }

  function distributeDividends() public override payable {
    require(totalBalance > 0);
    uint256 amount = msg.value;
    if (amount > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add((amount).mul(magnitude) / totalBalance);
      emit DividendsDistributed(msg.sender, amount);
      totalDividendsDistributed = totalDividendsDistributed.add(amount);
    }
  }

  function dividendOf(address _owner) public view override returns(uint256) {
    return withdrawableDividendOf(_owner);
  }

  function setDividendToken(address newToken) external virtual onlyOwner {
    address oldToken = dividendToken;
    dividendToken = newToken;
    emit SetDividendToken(oldToken, newToken);
  }

  function withdrawDividend() public virtual override {
    withdrawDividendOfUser(payable(msg.sender));
  }

  function withdrawableDividendOf(address _owner) public view override returns(uint256) {
    return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
  }

  function withdrawnDividendOf(address _owner) public view override returns(uint256) {
    return withdrawnDividends[_owner];
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
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account].add((magnifiedDividendPerShare.mul(value)).toInt256Safe());
  }

  function increaseBalance(address account, uint256 value) internal {
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account].sub((magnifiedDividendPerShare.mul(value)).toInt256Safe());
  }

  function withdrawDividendOfUser(address payable user) internal returns (uint256) {
    uint256 dividends = withdrawableDividendOf(user);
    if (dividends > 0) {
      withdrawnDividends[user] = withdrawnDividends[user].add(dividends);
      emit DividendWithdrawn(user, dividends);
      bool success = IERC20(dividendToken).transfer(user, dividends);
      if (!success) {
        withdrawnDividends[user] = withdrawnDividends[user].sub(dividends);
        return 0;
      }
      return dividends;
    }
    return 0;
  }


}
