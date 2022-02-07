// contracts/Odsy.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import './OdysseyRewards.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

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
  address payable public projectWallet;
  address payable public liquidityAddress;
  uint256 public accumulatedRewards = 0;
  uint256 public accumulatedProject = 0;
  uint256 public accumulatedLiquidity = 0;
  uint16 public feeLevel = 0;
  uint16 public feeToBuy = 2;
  uint16 public feeToSell = 12;
  uint16 public feeRewards = 6;
  uint16 public feeProject = 2;
  uint16 public feeLiquidity = 4;
  uint256 public gasLimit = 300_000; // GAS FOR REWARDS PROCESSING

  uint256 public maxWalletLimit = FINAL_SUPPLY.div(10); // MAX PER WALLET: 5_000_000_000 / 10%
  uint256 public maxSellAmount =  FINAL_SUPPLY.div(100); // MAX PER SELL: 500_000_000 / 1%
  uint256 public swapThreshold = 16_000_000 ether; // CONTRACT SWAPS TO BSD: 16_000_000

  // MAPPINGS
  mapping (address => bool) public autoMarketMakers; // Any transfer to these addresses are likely sells
  mapping (address => bool) public isFeeless; // exclude from all fees and maxes
  mapping (address => bool) public isPresale; // can trade in PreSale

  // EVENTS
  event IsFeelessChanged(address indexed account, bool excluded);
  event FeesChanged(uint256 marketCap, uint256 feeToBuy, uint256 feeToSell, uint256 feeRewards, uint256 feeProject, uint256 feeLiquidity);
  event FundsReceived(address indexed from, uint amount);
  event FundsSentToProject(uint256 amount);
  event FundsSentToRewards(uint256 amount);
  event GasLimitChanged(uint256 from, uint256 to);
  event LiquidityAdded(uint256 tokens, uint256 value);
  event LiquidityWalletChanged(address indexed from, address indexed to);
  event ProjectWalletChanged(address indexed from, address indexed to);
  event RewardsTrackerChanged(address indexed from, address indexed to);
  event SetAutomatedMarketMakerPair(address indexed pair, bool active);

  event MarketCapCalculated(uint256 price, uint256 marketCap, uint256 tokens, uint256 value);

  // INTERNAL VARS
  bool private swapping = false;

  // INITIALIZE CONTRACT
  constructor() ERC20('Odyssey', '$ODSY') {
    // SETUP PANCAKESWAP
    IUniswapV2Router02 router = IUniswapV2Router02(ROUTER_PCSV2_MAINNET); // IMMUTABLES UNREADABLE IN CONSTRUCTOR SO USE TMP VAR
    address pair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH()); // Create a uniswap pair for this new token
    uniswapV2Router = router;
    uniswapV2Pair = pair;
    autoMarketMakers[pair] = true;

    liquidityAddress = payable(address(owner()));
    projectWallet = payable(0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584);

    isPresale[owner()] = true;
    isFeeless[address(this)] = true;
    isFeeless[projectWallet] = true;
    isFeeless[liquidityAddress] = true;

    odysseyRewards = new OdysseyRewards('OdysseyRewards', 'ODSYRV1');
    setDefaultRewardsExclusions();
    changeFees(2, 6, 2, 4);

    // _mint(address(this), FINAL_SUPPLY.div(2));
    _mint(address(owner()), FINAL_SUPPLY);
  }

  // To receive ETH when swapping
  receive() external payable {
    emit FundsReceived(msg.sender, msg.value);
  }

  function openToPublic() external onlyOwner { // ONCE LIVE YOU CANNOT GO BACK!!
    require(address(this).balance > 0, "Must have bnb to pair for launch");
    require(balanceOf(address(this)) > 0, "Must have tokens to pair for launch");

    isOpenToPublic = true;
    addLiquidity(balanceOf(address(this)), address(this).balance);
    setLiquidityAddress(address(DEAD));
  }

  function setFeeless(address account, bool on) external onlyOwner {
    require(isFeeless[account]!=on, 'Value unchanged');

    isFeeless[account] = on;
    emit IsFeelessChanged(account, on);
  }

  function setPresale(address account, bool on) external onlyOwner { // NO EVENTS REQUIRED
    isPresale[account] = on;
  }

  function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
    require(pair != uniswapV2Pair, 'Value invalid');
    require(autoMarketMakers[pair] != value, 'Value unchanged');
    autoMarketMakers[pair] = value;
    odysseyRewards.setExcludedAddress(pair);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function setGasLimit(uint256 gas) external onlyOwner {
    require(gas >= 250_000 && gas <= 500_000, 'Value invalid');
    require(gas != gasLimit, 'Value unchanged');
    emit GasLimitChanged(gasLimit, gas);
    gasLimit = gas;
  }

  function setLiquidityAddress(address wallet) public onlyOwner {
    require(wallet != liquidityAddress, 'Value unchanged');

    address oldWallet = liquidityAddress;
    liquidityAddress = payable(wallet);
    if (oldWallet != address(this)) isFeeless[oldWallet] = false;
    isFeeless[wallet] = true;
    emit LiquidityWalletChanged(oldWallet, wallet);
  }

  function setMarketCap(uint256 marketCap) external onlyOwner {
    uint16 level = feeLevelFromMarketCap(marketCap);
    require(feeLevel != level, 'Value unchanged');

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
    require(wallet != projectWallet, 'Value unchanged');

    address oldWallet = projectWallet;
    projectWallet = payable(wallet);
    isFeeless[oldWallet] = false;
    isFeeless[wallet] = true;
    emit ProjectWalletChanged(oldWallet, projectWallet);
  }

  function setRewardsTracker(address newAddress) external onlyOwner {
    require(newAddress != address(odysseyRewards), 'Value unchanged');

    OdysseyRewards newRewardsTracker = OdysseyRewards(payable(newAddress));

    require(newRewardsTracker.owner() == address(this), 'Token must own tracker');

    emit RewardsTrackerChanged(address(odysseyRewards), newAddress);

    odysseyRewards = newRewardsTracker;
    setDefaultRewardsExclusions();
  }

  // FUNCTIONS DELEGATED TO RewardsTracker

  function getRewardsSettings() external view returns (uint256 rewardsDistributed, uint256 minBalance, uint256 claimWaitPeriodSeconds, uint256 holderCount, uint256 nextIndex) {
    return odysseyRewards.getSettings();
  }

  function getRewardsReport(address account) external view returns (bool accountExcluded, uint256 accountIndex, uint256 nextIndex, uint256 trackedBalance, uint256 totalRewards, uint256 claimedRewards, uint256 pendingRewards, uint256 lastClaimTime, uint256 nextClaimTime, uint256 secondsRemaining) {
    return odysseyRewards.getReport(account);
  }

  function withdrawRewardsFunds() external {
    odysseyRewards.withdrawFunds(payable(msg.sender));
  }

  function processRewardsClaims() external onlyOwner {
    try odysseyRewards.processClaims(gasLimit) {} catch {}
  }

  function setRewardsExcludedAddress(address account, bool exclude) external onlyOwner{
    if (exclude) {
      odysseyRewards.setExcludedAddress(account);
    } else {
      odysseyRewards.setIncludedAddress(account, balanceOf(account));
    }
  }

  function setRewardsMinimumBalance(uint256 amount) external onlyOwner {
    require(amount >= 10_000_000 && amount <= 100_000_000, 'Value invalid');

    odysseyRewards.setMinimumBalance(amount);
  }

  function setRewardsWaitingPeriod(uint256 waitSeconds) external onlyOwner {
    odysseyRewards.setWaitingPeriod(waitSeconds);
  }

  function _transfer(address from, address to, uint256 amount) internal override {
    require(from != address(0) && to != address(0), 'Invalid address');
    require(amount > 0, 'Value invalid');
    // if (!autoMarketMakers[to]) { // EOA TO EOA CANNOT EXCEED MAX
    //   require(balanceOf(to).add(amount) <= maxWalletLimit, 'Wallet over limit');
    // }

    require(to==address(this) || autoMarketMakers[to] || balanceOf(to).add(amount) <= maxWalletLimit, 'Wallet over limit');

    if (!isOpenToPublic && isPresale[from]) { // PRE-SALE WALLET - NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
      transferAndUpdateRewardsTracker(from, to, amount);
      return;
    }

    require(isOpenToPublic, 'Trading closed');

    if (isTransfer(from, to)) { // NOT TO DEX, NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
      transferAndUpdateRewardsTracker(from, to, amount);
      try odysseyRewards.processClaims(gasLimit) {} catch {}
      return; // NO TAXES SO SKIP ACCUMULATOR CHECKS
    }

    if (!swapping) {
      bool feePayer = !isFeeless[from] && !isFeeless[to];
      if (feePayer) { // RENDER UNTO CAESAR THE THINGS THAT ARE CAESAR'S
        uint256 taxTotal = 0;
        if (isSell(from, to)) {
          require(amount <= maxSellAmount, 'Sell over limit');
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

      if (!autoMarketMakers[from] && from!=liquidityAddress && to!=liquidityAddress) {
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

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, liquidityAddress, block.timestamp);
  }

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

  function isSell(address from, address to) private view returns (bool) {
    return autoMarketMakers[to] && from != address(uniswapV2Router);
  }

  function isTransfer(address from, address to) private view returns (bool) {
    return !autoMarketMakers[to] && !autoMarketMakers[from];
  }

  function processAccumulatedTokens() private {
    if (balanceOf(address(this)) >= swapThreshold) swapAndAddLiquidity(swapThreshold);
    if (balanceOf(address(this)) >= swapThreshold) swapAndSendToRewardsTracker(swapThreshold);
    if (balanceOf(address(this)) >= swapThreshold) swapAndSendToProject(swapThreshold);
  }

  function setDefaultRewardsExclusions() private {
    odysseyRewards.setExcludedAddress(owner());
    odysseyRewards.setExcludedAddress(uniswapV2Pair);
    odysseyRewards.setExcludedAddress(address(this));
    odysseyRewards.setExcludedAddress(address(uniswapV2Router));
    odysseyRewards.setExcludedAddress(projectWallet);
    odysseyRewards.setExcludedAddress(DEAD);
  }

  function swapAndAddLiquidity(uint256 tokens) private {
    if (accumulatedLiquidity < tokens) return; // NOT YET

    accumulatedLiquidity -= tokens;
    uint256 swapHalf = tokens.div(2);
    uint256 liquidHalf = tokens.sub(swapHalf);
    uint256 liquidETH = swapTokensForETH(swapHalf);
    addLiquidity(liquidHalf, liquidETH);
    emit LiquidityAdded(liquidHalf, liquidETH);
  }

  function swapAndSendToRewardsTracker(uint256 tokens) private {
    if (accumulatedRewards < tokens) return; // NOT YET

    accumulatedRewards -= tokens;
    uint256 swappedETH = swapTokensForETH(tokens);
    if (swappedETH > 0) {
      (bool success,) = address(odysseyRewards).call{value: swappedETH}('');
      if (success) emit FundsSentToRewards(swappedETH);
    }
  }

  function swapAndSendToProject(uint256 tokens) private {
    if (accumulatedProject < tokens) return; // NOT YET

    accumulatedProject -= tokens;
    uint256 swappedETH = swapTokensForETH(tokens);
    if (swappedETH > 0) {
      (bool success,) = address(projectWallet).call{value: swappedETH}("");
      if (success) emit FundsSentToProject(swappedETH);
    }
  }

  function swapTokensForETH(uint256 tokens) private returns(uint256) {
    address[] memory pair = new address[](2);
    pair[0] = address(this);
    pair[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokens);
    uint256 currentETH = address(this).balance;
    uniswapV2Router.swapExactTokensForETH(tokens, 0, pair, address(this), block.timestamp);
    uint256 swappedETH = address(this).balance.sub(currentETH);

    // TODO: MarketCap sets fees / max sell / swap threshold
    uint256 price = (swappedETH.mul(10**9)).div(tokens * 2);
    uint256 cap = (FINAL_SUPPLY.mul(price)).div(10**9);
    emit MarketCapCalculated(price, cap, tokens, swappedETH);

    return swappedETH;
  }

  function transferAndUpdateRewardsTracker(address from, address to, uint256 amount) private {
    super._transfer(from, to, amount);
    try odysseyRewards.setBalance(payable(from), balanceOf(from)) {} catch {}
    try odysseyRewards.setBalance(payable(to), balanceOf(to)) {} catch {}
  }
}
