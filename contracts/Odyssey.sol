// contracts/Odsy.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./ODSYDividendTracker.sol";

contract Odyssey is ERC20, Ownable {
  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;

  ODSYDividendTracker public odsyDividendTracker;
  address public odsyDividendToken;

  address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  address constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address constant ROUTER_PCSV2_MAINNET = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
  // address constant ROUTER_PCSV2_TESTNET = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
  uint256 constant FINAL_SUPPLY =  50_000_000_000 ether; // 50B FINAL SUPPLY / NO MINTING
  uint256 constant BEGIN_TRADING_AT = 1650168060; // Apr 17, 2022, 12:01:00 AM EST

  address public projectWallet;
  address public liquidityWallet;
  uint256 public accumulatedRewards = 0;
  uint256 public accumulatedProject = 0;
  uint256 public accumulatedLiquidity = 0;
  uint256 public maxWalletAmount = FINAL_SUPPLY / 100; // MAX 1% PER WALLET
  uint256 public maxSellAmount =  FINAL_SUPPLY / 1000; // MAX 0.1% SELL
  uint256 public swapThreshold = maxSellAmount; // CONTRACT WILL DISTRIBUTE ACCUMULATED FUND AT THIS THRESHOLD
  uint256 public lastMarketCap = 1000;
  uint256 public feeToBuy = 2;
  uint256 public feeToSell = 12;
  uint256 public feeRewards = 6;
  uint256 public feeProject = 2;
  uint256 public feeLiquidity = 4;
  uint256 public gasForProcessing = 300_000; // gas to process dividends

  // MAPPINGS
  mapping (address => bool) public autoMarketMakers; // Any transfer to these addresses are likely sells
  mapping (address => bool) private excludedFromFees; // exclude from all fees and maxes
  mapping (address => bool) private presaleWallets; // can trade in PreSale

  // EVENTS
  event ExcludedFromFees(address indexed account, bool isExcluded);
  event FeesChanged(uint256 marketCap, uint256 feeToBuy, uint256 feeToSell, uint256 feeRewards, uint256 feeProject, uint256 feeLiquidity);
  event LiquidityAdded(uint256 tokens, uint256 value);
  event LiquidityWalletChanged(address indexed previousValue, address indexed newValue);
  event ProcessedDividends(uint256 iterations, uint256 claims, uint256 lastIndex, bool indexed automatic, uint256 gas, address indexed processor);
  event ProjectWalletChanged(address indexed previousValue, address indexed newValue);
  event ReceivedFunds(address indexed from, uint amount);
  event SentFundsToDividendTracker(uint256 amount);
  event SentFundsToProject(uint256 amount);
  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed active);
  event SetDividendTracker(address indexed previousValue, address indexed newValue);
  event SetGasForProcessing(uint256 indexed previousValue, uint256 indexed newValue);

  // INTERNAL VARS
  bool private swapping = false;

  // INITIALIZE CONTRACT
  constructor() ERC20("Odyssey", "$ODSY") {
    odsyDividendTracker = new ODSYDividendTracker();

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(ROUTER_PCSV2_MAINNET); // IMMUTABLES UNREADABLE IN CONSTRUCTOR SO USE TMP VAR
    address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH()); // Create a uniswap pair for this new token
    uniswapV2Router = _uniswapV2Router;
    uniswapV2Pair = _uniswapV2Pair;
    setMarketMakerPair(_uniswapV2Pair, true);

    liquidityWallet = address(owner());
    projectWallet = 0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584;

    excludedFromFees[owner()] = true;
    excludedFromFees[address(this)] = true;
    excludedFromFees[projectWallet] = true;

    odsyDividendTracker.setExcludedAccount(owner(), true);
    odsyDividendTracker.setExcludedAccount(address(this), true);
    odsyDividendTracker.setExcludedAccount(address(_uniswapV2Router), true);
    odsyDividendTracker.setExcludedAccount(projectWallet, true);
    odsyDividendTracker.setExcludedAccount(DEAD, true);

    changeFees(2, 6, 2, 4);

    _mint(address(owner()), FINAL_SUPPLY);
  }

  receive() external payable onlyOwner {
    emit ReceivedFunds(msg.sender, msg.value);
  }

  function excludeFromFees(address account, bool exclude) external onlyOwner {
    require(excludedFromFees[account] != exclude, "ODSY: Value already set");

    excludedFromFees[account] = exclude;
    emit ExcludedFromFees(account, exclude);
  }

  function isExcludedFromFees(address account) external view returns(bool) {
    return excludedFromFees[account];
  }

  function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
    require(pair != uniswapV2Pair, "ODSY: The primary AMM pair cannot be modified");

    setMarketMakerPair(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  // function setDividendToken(address newToken) external onlyOwner {
  //   odsyDividendToken = newToken;
  //   odsyDividendTracker.setDividendToken(newToken);
  // }

  function setDividendTracker(address newTracker) public onlyOwner {
    address oldTracker = address(odsyDividendTracker);
    require(newTracker != oldTracker, "ODSY: Value already set");

    ODSYDividendTracker newDividendTracker = ODSYDividendTracker(payable(newTracker));

    require(newDividendTracker.owner() == address(this), "ODSY: The new dividend tracker must be owned by the token.");

    newDividendTracker.setExcludedAccount(address(this), true);
    newDividendTracker.setExcludedAccount(address(uniswapV2Router), true);
    newDividendTracker.setExcludedAccount(projectWallet, true);
    newDividendTracker.setExcludedAccount(DEAD, true);
    newDividendTracker.setOwnerTotalSupply(totalSupply());

    odsyDividendTracker = newDividendTracker;
    emit SetDividendTracker(oldTracker, newTracker);
  }

  function setGasForProcessing(uint256 gas) public onlyOwner {
    require(gas >= 250_000 && gas <= 500_000, "ODSY: gasForProcessing must be between 250,000 and 500,000");
    require(gas != gasForProcessing, "ODSY: Value already set");
    emit SetGasForProcessing(gasForProcessing, gas);
    gasForProcessing = gas;
  }

  function setLiquidityWallet(address new_wallet) external onlyOwner {
    require(new_wallet != liquidityWallet, "ODSY: Value already set");

    address old_wallet = liquidityWallet;
    liquidityWallet = new_wallet;
    if (old_wallet != address(this)) excludedFromFees[old_wallet] = false;
    excludedFromFees[new_wallet] = true;
    emit LiquidityWalletChanged(old_wallet, new_wallet);
  }

  function setMarketCap(uint256 marketCap) external onlyOwner {
    lastMarketCap = marketCap;
    if (lastMarketCap <   1000000) return changeFees(2, 6, 2, 4);
    if (lastMarketCap <   4000000) return changeFees(2, 5, 2, 3);
    if (lastMarketCap <  16000000) return changeFees(2, 4, 2, 2);
    if (lastMarketCap <  64000000) return changeFees(2, 3, 1, 2);
    if (lastMarketCap < 256000000) return changeFees(2, 2, 0, 2);
                                          changeFees(2, 1, 0, 1);
  }

  function setProjectWallet(address new_wallet) external onlyOwner {
    require(new_wallet != projectWallet, "ODSY: Value already set");
    address old_wallet = projectWallet;
    projectWallet = new_wallet;
    excludedFromFees[old_wallet] = false;
    excludedFromFees[new_wallet] = true;
    emit ProjectWalletChanged(old_wallet, new_wallet);
  }

  function isTradingEnabled() public view returns (bool) {
    return true; // TESTING
    // return block.timestamp >= BEGIN_TRADING_AT;
  }

  function isBuy(address from, address to) public view returns (bool) {
    return autoMarketMakers[from] && to != address(uniswapV2Router);
  }

  function isSell(address from, address to) public view returns (bool) {
    return autoMarketMakers[to] && from != address(uniswapV2Router);
  }

  function isTransfer(address from, address to) public view returns (bool) {
    return (to != address(uniswapV2Router) && from != address(uniswapV2Router));
  }

  // FUNCTIONS DELEGATED TO DividendTracker

  function getDividendsAccountInfo(address account) external view returns (address, int256, int256, uint256, uint256, uint256, uint256, uint256) {
    return odsyDividendTracker.getAccountInfo(account);
  }

  function getDividendsAccountInfoAtIndex(uint256 index) external view returns (address, int256, int256, uint256, uint256, uint256, uint256, uint256) {
    return odsyDividendTracker.getAccountInfoAtIndex(index);
  }

  function getDividendsBalanceOf(address account) public view returns (uint256) {
    return odsyDividendTracker.balanceOf(account);
  }

  function getDividendsClaimWait() external view returns(uint256) {
    return odsyDividendTracker.claimWait();
  }

  function getDividendsLastProcessedIndex() external view returns(uint256) {
    return odsyDividendTracker.lastProcessedIndex();
  }

  function getDividendsMinimumBalance() external view returns(uint256) {
    return odsyDividendTracker.minimumBalance();
  }

  function getDividendsHolderCount() external view returns(uint256) {
    return odsyDividendTracker.getHolderCount();
  }

  function getDividendsTotalDistributed() external view returns (uint256) {
    return odsyDividendTracker.totalDistributed();
  }

  function getDividendsWithdrawable(address account) public view returns(uint256) {
    return odsyDividendTracker.getWithdrawable(account);
  }

  function isDividendsExcludedAccount(address account) external view returns(bool) {
    return odsyDividendTracker.excludedAccounts(account);
  }

  function processDividendsClaim() external {
    odsyDividendTracker.processClaim(payable(msg.sender), false);
  }

  function processDividendsClaims(uint256 gas) public {
    try odsyDividendTracker.processClaims(gas) returns (uint256 iterations, uint256 claims, uint256 lastIndex) {
      emit ProcessedDividends(iterations, claims, lastIndex, true, gas, tx.origin);
    } catch {}
    // (uint256 iterations, uint256 claims, uint256 lastIndex) = odsyDividendTracker.processClaims(gas);
    // emit ProcessedDividends(iterations, claims, lastIndex, false, gas, tx.origin);
  }

  function setDividendsClaimWait(uint256 waitSeconds) external onlyOwner {
    odsyDividendTracker.setClaimWait(waitSeconds);
  }

  function setDividendsExcludedAccount(address account, bool exclude) external onlyOwner{
    odsyDividendTracker.setExcludedAccount(account, exclude);
  }

  function setDividendsMinimumBalance(uint256 amount) external onlyOwner {
    require(amount >= 10_000_000 && amount <= 100_000_000, "ODSY: DividendsMinimumBalance must be between 10 and 100 million tokens");

    odsyDividendTracker.setMinimumBalance(amount);
  }

  function _transfer(address from, address to, uint256 amount) internal override {
    require(from != address(0), "ODSY: transfer from the zero address");
    require(to != address(0), "ODSY: transfer to the zero address");
    require(amount > 0, "ODSY: transfer amount must be greater than zero");
    // require(isPreSaleEnabled(), "ODSY: Presale is not active"); // NO ONE CAN TRADE UNTIL CONTRACT GOES LIVE

    if (!isTradingEnabled() && presaleWallets[from]) { // PRE-SALE WHITELIST - NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
      transferAndUpdateTrackerBalances(from, to, amount);
      return;
    }

    require(isTradingEnabled(), "ODSY: Trading is not open to the public");

    if (!swapping) {
      if (isTransfer(from, to)) { // NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
        transferAndUpdateTrackerBalances(from, to, amount);
        processDividendsClaims(gasForProcessing);
        return; // JUST EXIT, NO NEED TO CHECK ACCUMULATORS
      }

      bool feePayer = !excludedFromFees[from] && !excludedFromFees[to];
      if (feePayer) { // RENDER UNTO CAESAR THE THINGS THAT ARE CAESAR'S
        uint256 taxTotal = 0;
        if (isSell(from, to)) {
          require(amount <= maxSellAmount, "ODSY: Transfer exceeds the max sell limit");
          taxTotal = amount * feeToSell / 100;
          if (taxTotal > 0) {
            uint256 taxLiquidity = taxTotal * feeLiquidity / feeToSell;
            uint256 taxProject = taxTotal * feeProject / feeToSell;
            uint256 taxRewards = taxTotal - (taxProject + taxLiquidity);
            accumulatedLiquidity += taxLiquidity;
            accumulatedProject += taxProject;
            accumulatedRewards += taxRewards;
          }
        } else { // BUY
          taxTotal = amount * feeToBuy / 100;
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

    transferAndUpdateTrackerBalances(from, to, amount);

    if (!swapping) {
      processDividendsClaims(gasForProcessing);
    }
  }

  // PRIVATE - ONLY CAN BE USED BY THIS CONTRACT

  function changeFees(uint256 buy, uint256 rewards, uint256 project, uint256 liquidity) private {
    (feeToBuy, feeRewards, feeProject, feeLiquidity) = (buy, rewards, project, liquidity);
    feeToSell = feeRewards + feeProject + feeLiquidity;
    emit FeesChanged(lastMarketCap, feeToBuy, feeToSell, feeRewards, feeProject, feeLiquidity);
  }

  function processAccumulatedTokens() private {
    if (swapThreshold > balanceOf(address(this))) return; // NOT ENOUGH TOKENS IN CONTRACT
    if (accumulatedLiquidity > swapThreshold) swapAndAddLiquidity(swapThreshold);
    if (swapThreshold > balanceOf(address(this))) return; // NOT ENOUGH TOKENS IN CONTRACT TO CONTINUE
    if (accumulatedRewards > swapThreshold) swapAndSendToDividendTracker(swapThreshold);
    if (swapThreshold > balanceOf(address(this))) return; // NOT ENOUGH TOKENS IN CONTRACT TO CONTINUE
    if (accumulatedProject > swapThreshold) swapAndSendToProject(swapThreshold);
  }

  function setMarketMakerPair(address pair, bool active) private {
    require(autoMarketMakers[pair] != active, "ODSY: Value already set");
    autoMarketMakers[pair] = active;
    odsyDividendTracker.setExcludedAccount(pair, active);
  }

  function swapAndAddLiquidity(uint256 tokens) private {
    uint256 currentETH = address(this).balance;
    uint256 swapTokens = tokens / 2;
    uint256 liquidTokens = tokens - swapTokens;
    swapTokensForETH(swapTokens);
    accumulatedLiquidity -= tokens;
    uint256 liquidETH = address(this).balance - currentETH;
    _approve(address(this), address(uniswapV2Router), liquidTokens);
    uniswapV2Router.addLiquidityETH{value: liquidETH}(address(this), liquidTokens, 0, 0, liquidityWallet, block.timestamp);
    emit LiquidityAdded(liquidTokens, liquidETH);
  }

  function swapAndSendToDividendTracker(uint256 tokens) private {
    uint256 currentETH = address(this).balance;
    swapTokensForETH(tokens);
    accumulatedRewards -= tokens;
    uint256 trackerETH = address(this).balance - currentETH;
    if (trackerETH > 0) {
      (bool success,) = address(odsyDividendTracker).call{value: trackerETH}(""); //
      if (success) {
        emit SentFundsToDividendTracker(trackerETH);
//        try odsyDividendTracker.distributeFunds() {} catch {}
      }
    }
  }

  function swapAndSendToProject(uint256 tokens) private {
    swapTokensForETH(tokens);
    accumulatedProject -= tokens;
    uint256 currentETH = address(this).balance; // PROJECT SWEEPS UP ANY LINGERING FUNDS
    if (currentETH > 0) {
      (bool success,) = address(projectWallet).call{value: currentETH}("");
      if (success) emit SentFundsToProject(currentETH);
    }
  }

  function swapTokensForETH(uint256 tokens) private {
    address[] memory pair = new address[](2);
    pair[0] = address(this);
    pair[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokens);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokens, 0, pair, address(this), block.timestamp);
  }

  function transferAndUpdateTrackerBalances(address from, address to, uint256 amount) private {
    super._transfer(from, to, amount);
    try odsyDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
    try odsyDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
  }
}
