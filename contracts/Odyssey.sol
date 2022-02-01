// contracts/Odsy.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "./OdysseyRewards.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Odyssey is ERC20, Ownable {
  using SafeMath for uint256;
  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;

  OdysseyRewards public odysseyRewards;

  address constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address constant ROUTER_PCSV2_MAINNET = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
  // address constant ROUTER_PCSV2_TESTNET = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
  uint256 constant FINAL_SUPPLY =  50_000_000_000 ether; // 50B FINAL SUPPLY / NO MINTING

  bool public isOpenToPublic = false;
  address public projectWallet;
  address public liquidityWallet;
  uint256 public accumulatedRewards = 0;
  uint256 public accumulatedProject = 0;
  uint256 public accumulatedLiquidity = 0;
  uint16 public feeLevel = 1;
  uint16 public feeToBuy = 2;
  uint16 public feeToSell = 12;
  uint16 public feeRewards = 6;
  uint16 public feeProject = 2;
  uint16 public feeLiquidity = 4;
  uint256 public gasLimit = 300_000; // GAS FOR REWARDS PROCESSING

  uint256 public maxWalletLimit = FINAL_SUPPLY.div(10); // MAX PER WALLET: 5_000_000_000 / 10%
  uint256 public maxSellAmount =  FINAL_SUPPLY.div(100); // MAX PER SELL: 500_000_000 / 1%
  uint256 public swapThreshold = maxSellAmount.div(5); // CONTRACT SWAPS TO BSD: 100_000_000

  // MAPPINGS
  mapping (address => bool) public autoMarketMakers; // Any transfer to these addresses are likely sells
  mapping (address => bool) private excludedFromFees; // exclude from all fees and maxes
  mapping (address => bool) private presaleWallets; // can trade in PreSale

  // EVENTS
  event ExcludedFromFees(address indexed account, bool isExcluded);
  event FeesChanged(uint256 marketCap, uint256 feeToBuy, uint256 feeToSell, uint256 feeRewards, uint256 feeProject, uint256 feeLiquidity);
  event FundsReceived(address indexed from, uint amount);
  event FundsSentToProject(uint256 amount);
  event FundsSentToRewards(uint256 amount);
  event GasLimitChanged(uint256 indexed from, uint256 indexed to);
  event LiquidityAdded(uint256 tokens, uint256 value);
  event LiquidityWalletChanged(address indexed from, address indexed to);
  event ProjectWalletChanged(address indexed from, address indexed to);
  event RewardsTrackerChanged(address indexed from, address indexed to);
  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed active);

  // INTERNAL VARS
  bool private swapping = false;

  // INITIALIZE CONTRACT
  constructor() ERC20("Odyssey", "$ODSY") {
    // SETUP PANCAKESWAP
    IUniswapV2Router02 router = IUniswapV2Router02(ROUTER_PCSV2_MAINNET); // IMMUTABLES UNREADABLE IN CONSTRUCTOR SO USE TMP VAR
    address pair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH()); // Create a uniswap pair for this new token
    uniswapV2Router = router;
    uniswapV2Pair = pair;
    autoMarketMakers[pair] = true;

    liquidityWallet = address(owner());
    projectWallet = 0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584;

    presaleWallets[owner()] = true;
    excludedFromFees[address(this)] = true;
    excludedFromFees[projectWallet] = true;
    excludedFromFees[liquidityWallet] = true;

    odysseyRewards = new OdysseyRewards();
    setDefaultRewardsExclusions();
    changeFees(2, 6, 2, 4);

    _mint(address(owner()), FINAL_SUPPLY);
  }

  receive() external payable onlyOwner {
    emit FundsReceived(msg.sender, msg.value);
  }

  function excludeFromFees(address account, bool exclude) external onlyOwner {
    require(excludedFromFees[account] != exclude, "Value unchanged");

    excludedFromFees[account] = exclude;
    emit ExcludedFromFees(account, exclude);
  }

  function isExcludedFromFees(address account) external view returns(bool) {
    return excludedFromFees[account];
  }

  function openToPublic() external onlyOwner { // ONCE LIVE YOU CANNOT GO BACK!!
    isOpenToPublic = true;
  }

  function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
    require(pair != uniswapV2Pair, "Value invalid");
    require(autoMarketMakers[pair] != value, "Value unchanged");
    autoMarketMakers[pair] = value;
    odysseyRewards.setExcludedAddress(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function setGasForProcessing(uint256 gas) external onlyOwner {
    require(gas >= 250_000 && gas <= 500_000, "Value invalid");
    require(gas != gasLimit, "Value unchanged");
    emit GasLimitChanged(gasLimit, gas);
    gasLimit = gas;
  }

  function setLiquidityWallet(address wallet) external onlyOwner {
    require(wallet != liquidityWallet, "Value unchanged");

    address oldWallet = liquidityWallet;
    liquidityWallet = wallet;
    if (oldWallet != address(this)) excludedFromFees[oldWallet] = false;
    excludedFromFees[wallet] = true;
    emit LiquidityWalletChanged(oldWallet, wallet);
  }

  function setMarketCap(uint256 marketCap) external onlyOwner {
    uint16 level = feeLevelFromMarketCap(marketCap);
    if (feeLevel == level) return;

    feeLevel = level;
    if (feeLevel == 1) changeFees(2, 6, 2, 4);
    else if (feeLevel == 2) changeFees(2, 5, 2, 3);
    else if (feeLevel == 3) changeFees(2, 4, 2, 2);
    else if (feeLevel == 4) changeFees(2, 3, 1, 2);
    else if (feeLevel == 5) changeFees(2, 2, 0, 2);
    else if (feeLevel == 6) changeFees(2, 1, 0, 1);
    emit FeesChanged(marketCap, feeToBuy, feeToSell, feeRewards, feeProject, feeLiquidity);
  }

  function setProjectWallet(address wallet) external onlyOwner {
    require(wallet != projectWallet, "Value unchanged");
    address oldWallet = projectWallet;
    projectWallet = wallet;
    excludedFromFees[oldWallet] = false;
    excludedFromFees[wallet] = true;
    emit ProjectWalletChanged(oldWallet, projectWallet);
  }

  function setRewardsTracker(address newTracker) external onlyOwner {
    address oldTracker = address(odysseyRewards);
    require(newTracker != oldTracker, "Value unchanged");

    OdysseyRewards newRewardsTracker = OdysseyRewards(payable(newTracker));

    require(newRewardsTracker.owner() == address(this), "Token must own tracker");

    odysseyRewards = newRewardsTracker;
    setDefaultRewardsExclusions();

    emit RewardsTrackerChanged(oldTracker, newTracker);
  }

  // FUNCTIONS DELEGATED TO RewardsTracker

  function getRewardsSettings() external view returns (uint256 rewardsDistributed, uint256 minBalance, uint256 claimWaitPeriodSeconds, uint256 holderCount, uint256 nextIndex) {
    return odysseyRewards.getSettings();
  }

  function getRewardsReport(address account) external view returns (bool accountExcluded, uint256 accountIndex, uint256 nextIndex, uint256 trackedBalance, uint256 totalRewards, uint256 claimedRewards, uint256 pendingRewards, uint256 lastClaimTime, uint256 nextClaimTime, uint256 secondsRemaining) {
    return odysseyRewards.getReport(account);
  }

  function processRewardsClaim() external returns(bool) {
    return odysseyRewards.processClaim(payable(msg.sender), false);
  }

  function processRewardsClaims() external onlyOwner {
    try odysseyRewards.processClaims(gasLimit) {} catch {}
  }

  function setRewardsClaimWaitingPeriod(uint256 waitSeconds) external onlyOwner {
    odysseyRewards.setClaimWaitingPeriod(waitSeconds);
  }

  function setRewardsExcludedAccount(address account, bool exclude) external onlyOwner{
    odysseyRewards.setExcludedAddress(account, exclude);
  }

  function setRewardsMinimumBalance(uint256 amount) external onlyOwner {
    require(amount >= 10_000_000 && amount <= 100_000_000, "Value invalid");

    odysseyRewards.setMinimumBalance(amount);
  }

  function _transfer(address from, address to, uint256 amount) internal override {
    require(from != address(0) && to != address(0), "Invalid address");
    require(amount > 0, "Value invalid");

    if (!isOpenToPublic && presaleWallets[from]) { // PRE-SALE WHITELIST - NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
      transferAndUpdateRewardsTracker(from, to, amount);
      return;
    }

    require(isOpenToPublic, "Trading closed");

    if (!swapping) {
      if (!autoMarketMakers[to]) require(balanceOf(to).add(amount) <= maxWalletLimit, "Wallet over limit");

      if (isTransfer(from, to)) { // NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
        transferAndUpdateRewardsTracker(from, to, amount);
        try odysseyRewards.processClaims(gasLimit) {} catch {}
        return; // NO TAXES SO SKIP ACCUMULATOR CHECKS
      }

      bool feePayer = !excludedFromFees[from] && !excludedFromFees[to];
      if (feePayer) { // RENDER UNTO CAESAR THE THINGS THAT ARE CAESAR'S
        uint256 taxTotal = 0;
        if (isSell(from, to)) {
          require(amount <= maxSellAmount, "Sell over limit");
          taxTotal = amount.mul(feeToSell).div(100);
          if (taxTotal > 0) {
            uint256 taxLiquidity = taxTotal.mul(feeLiquidity).div(feeToSell);
            uint256 taxProject = taxTotal.mul(feeProject).div(feeToSell);
            uint256 taxRewards = taxTotal.sub(taxProject.add(taxLiquidity));
            accumulatedLiquidity += taxLiquidity;
            accumulatedProject += taxProject;
            accumulatedRewards += taxRewards;
          }
        } else { // BUY
          taxTotal = amount.mul(feeToBuy).div(100);
          accumulatedProject += taxTotal;
        }
        if (taxTotal > 0) {
          super._transfer(from, address(this), taxTotal);
          amount -= taxTotal;
        }
      }

      if (!autoMarketMakers[from] && from!=liquidityWallet && to!=liquidityWallet) {
        swapping = true;
        processAccumulatedTokens();
        swapping = false;
      }
    }

    transferAndUpdateRewardsTracker(from, to, amount);

    if (!swapping) {
      try odysseyRewards.processClaims(gasLimit) {} catch {}
    }
  }

  // PRIVATE - ONLY CAN BE USED BY THIS CONTRACT

  function changeFees(uint16 buy, uint16 rewards, uint16 project, uint16 liquidity) private {
    (feeToBuy, feeRewards, feeProject, feeLiquidity) = (buy, rewards, project, liquidity);
    feeToSell = feeRewards + feeProject + feeLiquidity;
  }

  function feeLevelFromMarketCap(uint256 marketCap) private pure returns (uint16) {
    if (marketCap <   1_000_000) return 1;
    if (marketCap <   4_000_000) return 2;
    if (marketCap <  16_000_000) return 3;
    if (marketCap <  64_000_000) return 4;
    if (marketCap < 256_000_000) return 5;
    return 6;
  }

  // function isBuy(address from, address to) private view returns (bool) {
  //   return autoMarketMakers[from] && to != address(uniswapV2Router);
  // }

  function isSell(address from, address to) private view returns (bool) {
    return autoMarketMakers[to] && from != address(uniswapV2Router);
  }

  function isTransfer(address from, address to) private view returns (bool) {
    return (to != address(uniswapV2Router) && from != address(uniswapV2Router));
  }

  function processAccumulatedTokens() private {
    if (balanceOf(address(this)) > swapThreshold) swapAndAddLiquidity(swapThreshold);
    if (balanceOf(address(this)) > swapThreshold) swapAndSendToRewardsTracker(swapThreshold);
    if (balanceOf(address(this)) > swapThreshold) swapAndSendToProject(swapThreshold);
  }

  function setDefaultRewardsExclusions() private {
    odysseyRewards.setExcludedAddress(owner(), true);
    odysseyRewards.setExcludedAddress(uniswapV2Pair, true);
    odysseyRewards.setExcludedAddress(address(this), true);
    odysseyRewards.setExcludedAddress(address(uniswapV2Router), true);
    odysseyRewards.setExcludedAddress(projectWallet, true);
    odysseyRewards.setExcludedAddress(DEAD, true);
  }

  function swapAndAddLiquidity(uint256 tokens) private {
    if (accumulatedLiquidity < tokens) return; // NOT YET

    accumulatedLiquidity -= tokens;
    uint256 currentETH = address(this).balance;
    uint256 swapHalf = tokens.div(2);
    uint256 liquidHalf = tokens.sub(swapHalf);
    swapTokensForETH(swapHalf);
    uint256 swappedETH = address(this).balance.sub(currentETH);
    _approve(address(this), address(uniswapV2Router), liquidHalf);
    uniswapV2Router.addLiquidityETH{value: swappedETH}(address(this), liquidHalf, 0, 0, liquidityWallet, block.timestamp);
    emit LiquidityAdded(liquidHalf, swappedETH);
  }

  function swapAndSendToRewardsTracker(uint256 tokens) private {
    if (accumulatedRewards < tokens) return; // NOT YET

    accumulatedRewards -= tokens;
    uint256 currentETH = address(this).balance;
    swapTokensForETH(tokens);
    uint256 swappedETH = address(this).balance.sub(currentETH);
    if (swappedETH > 0) {
      (bool success,) = address(odysseyRewards).call{value: swappedETH}("");
      if (success) emit FundsSentToRewards(swappedETH);
    }
  }

  function swapAndSendToProject(uint256 tokens) private {
    if (accumulatedProject < tokens) return; // NOT YET

    accumulatedProject -= tokens;
    swapTokensForETH(tokens);
    uint256 currentETH = address(this).balance; // PROJECT SWEEPS UP ANY LINGERING FUNDS
    if (currentETH > 0) {
      (bool success,) = address(projectWallet).call{value: currentETH}("");
      if (success) emit FundsSentToProject(currentETH);
    }
  }

  function swapTokensForETH(uint256 tokens) private {
    address[] memory pair = new address[](2);
    pair[0] = address(this);
    pair[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokens);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokens, 0, pair, address(this), block.timestamp);
  }

  function transferAndUpdateRewardsTracker(address from, address to, uint256 amount) private {
    super._transfer(from, to, amount);
    try odysseyRewards.setBalance(payable(from), balanceOf(from)) {} catch {}
    try odysseyRewards.setBalance(payable(to), balanceOf(to)) {} catch {}
  }
}
