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

  address constant ROUTER_PCSV2_MAINNET = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
  // address constant ROUTER_PCSV2_TESTNET = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
  uint256 constant FINAL_SUPPLY = 50_000_000_000 ether; // 50B FINAL SUPPLY / NO MINTING
  uint256 constant MAX_WALLET = 5_000_000_000 ether; // MAX PER WALLET: 5_000_000_000 / 10%
  uint256 constant MAX_SELL = 500_000_000 ether; // MAX PER SELL: 500_000_000 / 1%

  bool public isOpenToPublic = false;
  bool public isStakingOn = false;
  address payable public projectWallet;
  address payable public liquidityAddress;
  uint256 public accumulatedRewards = 0;
  uint256 public accumulatedProject = 0;
  uint256 public accumulatedLiquidity = 0;
  uint16[4] public feeLevel = [1,1,1,1]; // STATE CAPACITOR
  uint16 public feeToBuy = 2;
  uint16 public feeToSell = 12;
  uint16 public feeLiquidity = 5;
  uint16 public feeProject = 3;
  uint16 public feeRewards = 4;
  uint256 public swapThreshold = 16_000_000 ether; // CONTRACT SWAPS TO BSD: 16_000_000
  uint256 public gasLimit = 300_000; // GAS FOR REWARDS PROCESSING

  // MAPPINGS
  mapping (address => bool) public autoMarketMakers; // Any transfer to these addresses are likely sells
  mapping (address => bool) public isFeeless; // exclude from all fees and maxes
  mapping (address => bool) public isPresale; // can trade in PreSale
  mapping (address => bool) public isStaked; // holder controlled staking flag

  // EVENTS

  event AccountStakingChanged(address indexed account, bool from, bool to);
  event FeesChanged(uint256 feeToBuy, uint256 feeToSell, uint256 feeRewards, uint256 feeProject, uint256 feeLiquidity, uint256 swapAt);
  event FundsReceived(address indexed from, uint amount);
  event FundsSentToLiquidity(uint256 tokens, uint256 value);
  event FundsSentToProject(uint256 tokens, uint256 value);
  event FundsSentToRewards(uint256 tokens, uint256 value);
  event GasLimitChanged(uint256 from, uint256 to);
  event IsFeelessChanged(address indexed account, bool excluded);
  event LiquidityAddressChanged(address indexed from, address indexed to);
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

    projectWallet = payable(0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584);
    liquidityAddress = payable(owner());
    isPresale[owner()] = true;
    isFeeless[address(this)] = true;
    isFeeless[projectWallet] = true;

    odysseyRewards = new OdysseyRewards('OdysseyRewards', 'ODSYRV1');
    setDefaultRewardsExclusions();
    setFeesByLevel(1);

    _mint(address(owner()), FINAL_SUPPLY);
  }

  // To receive ETH when swapping
  receive() external payable {
    emit FundsReceived(msg.sender, msg.value);
  }

  function balanceOfLiquidity() external view returns(uint256) {
    return IUniswapV2Pair(uniswapV2Pair).balanceOf(address(this));
  }

  function openToPublic() external onlyOwner { // NO GOING BACK
    require(address(this).balance > 0, 'Must have bnb to pair for launch');
    require(balanceOf(address(this)) > 0, 'Must have tokens to pair for launch');

    isOpenToPublic = true;

    // INITIAL LIQUIDITY GOES TO OWNER TO LOCK
    addLiquidity(balanceOf(address(this)), address(this).balance);

    liquidityAddress = payable(address(this)); // GENERATED LIQUIDITY STAYS IN CONTRACT
    emit LiquidityAddressChanged(owner(), address(this));
  }

  function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
    require(pair != uniswapV2Pair, 'Value invalid');
    require(autoMarketMakers[pair] != value, 'Value unchanged');
    autoMarketMakers[pair] = value;
    odysseyRewards.setExcludedAddress(pair);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function setFeeless(address account, bool setting) external onlyOwner {
    require(isFeeless[account]!=setting, 'Value unchanged');

    isFeeless[account] = setting;
    emit IsFeelessChanged(account, setting);
  }

  function setGasLimit(uint256 gas) external onlyOwner {
    require(gas >= 250_000 && gas <= 500_000, 'Value invalid');
    require(gas != gasLimit, 'Value unchanged');
    emit GasLimitChanged(gasLimit, gas);
    gasLimit = gas;
  }

  function setPresale(address account, bool setting) external onlyOwner { // NO EVENTS REQUIRED
    isPresale[account] = setting;
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

  function setStaking(bool setting) external onlyOwner {
    require(isStakingOn!=setting, 'Value unchanged');

    isStakingOn = setting;
    if (odysseyRewards.isStakingOn()!=setting) odysseyRewards.setStaking(setting);
  }

  // *************************************
  // FUNCTIONS DELEGATED TO RewardsTracker

  function getRewardsReport() external view returns (uint256 holderCount, bool stakingOn, uint256 totalTokensTracked, uint256 totalTokensStaked, uint256 totalRewardsPaid, uint256 requiredBalance, uint256 waitPeriodSeconds) {
    return odysseyRewards.getReport();
  }

  function getRewardsReportByAccount(address account) external view returns (bool excluded, uint256 indexOf, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours, uint256 stakedDays) {
    return odysseyRewards.getReportAccount(account);
  }

  function setRewardsStaking(address account, bool setting) external {
    require(account==msg.sender, 'Value invalid'); // USER MUST PROVIDER THEIR OWN ADDRESS
    require(isStaked[account]!=setting, 'Value unchanged');

    if (isStaked[account] && !setting) { // TURNING OFF STAKING HAS NO CONDITIONS AND NEVER FAILS
      try odysseyRewards.stakeAccount(account, setting) {} catch {} // REWARDS CONTRACT SHOULD NOT PREVENT TURNING OFF THIS
    } else {
      require(isStakingOn, 'Rewards staking not active');
      odysseyRewards.stakeAccount(account, setting); // THIS COULD REVERT IN REWARDS CONTRACT
    }
    isStaked[account] = setting;
    emit AccountStakingChanged(account, !setting, setting);
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
    require(amount >= 5_000_000 && amount <= 15_000_000, 'Value invalid');

    odysseyRewards.setMinimumBalance(amount * 1 ether);
  }

  function setRewardsWaitingPeriod(uint256 waitSeconds) external onlyOwner {
    odysseyRewards.setWaitingPeriod(waitSeconds);
  }

  function withdrawRewards() external {
    odysseyRewards.withdrawFunds(payable(msg.sender));
  }

  function _transfer(address from, address to, uint256 amount) internal override {
    require(from != address(0) && to != address(0), 'Value invalid');
    require(amount > 0, 'Value invalid');

    require(!isStakingOn || !isStaked[from], 'Account is staked for rewards');

    require(to==address(this) || autoMarketMakers[to] || balanceOf(to).add(amount) <= MAX_WALLET, 'Wallet over limit');

    if (!isOpenToPublic && isPresale[from]) { // PRE-SALE WALLET - NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
      transferAndUpdateRewardsTracker(from, to, amount);
      return;
    }

    require(isOpenToPublic, 'Trading closed');

    if (!autoMarketMakers[to] && !autoMarketMakers[from]) { // NOT A SALE, NO FEE TRANSFER
      transferAndUpdateRewardsTracker(from, to, amount);
      try odysseyRewards.processClaims(gasLimit) {} catch {}
      return; // NO TAXES
    }

    if (!swapping) {
      bool feePayer = !isFeeless[from] && !isFeeless[to];
      if (feePayer) { // RENDER UNTO CAESAR THE THINGS THAT ARE CAESAR'S
        uint256 taxTotal = 0;
        if (autoMarketMakers[to] && from!=address(uniswapV2Router)) { // SELL
          require(amount <= MAX_SELL, 'Sell over limit');
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

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, liquidityAddress, block.timestamp);
  }

  function changeMarketCap(uint256 swappedETH, uint256 tokens) private {
    uint256 marketCap = swappedETH.mul(FINAL_SUPPLY).div(tokens).div(1 ether);
    uint256 price = marketCap.mul(1 ether).div(FINAL_SUPPLY.div(1 ether));
    emit MarketCapCalculated(price, marketCap, tokens, swappedETH); // TESTING

    uint16 level = // MC IN BNB NOT USD
      (marketCap <   4_000) ? 1 :
      (marketCap <   8_000) ? 2 :
      (marketCap <  16_000) ? 3 :
      (marketCap <  32_000) ? 4 :
      (marketCap <  64_000) ? 5 :
      (marketCap < 128_000) ? 6 :
      (marketCap < 256_000) ? 7 :
      (marketCap < 512_000) ? 8 : 9;

    if (feesChanged(level)) {
      setFeesByLevel(level);

      // ONCE LIQUIDITY FEE GOES TO ZERO WE MAY NEVER COLLECT AGAIN,
      if (feeLiquidity==0 && accumulatedLiquidity > 0) {
        accumulatedRewards += accumulatedLiquidity;
        accumulatedLiquidity = 0;
      }
      emit FeesChanged(feeToBuy, feeToSell, feeRewards, feeProject, feeLiquidity, swapThreshold);
    }
  }

  function feesChanged(uint16 level) private returns (bool) {
    // STORE PAST 3 READINGS; 4TH IS CURRENT STATE
    uint i;
    bool flag = true;
    for (i=0;i<3;i++) feeLevel[i] = (i<2) ? feeLevel[i+1] : level; // SHIFT & STORE
    // IF 1ST 3 EQ AND THE 4 IS NOT LEVEL HAS CHANGED AND STABLIZED
    for (i=0;i<3;i++) flag = flag && (i<2 ? feeLevel[i]==feeLevel[i+1] : feeLevel[i]!=feeLevel[i+1]);
    if (flag) feeLevel[3] = level; // 4TH SLOT HOLDS CURRENT LEVEL
    return flag;
  }

  function processAccumulatedTokens() private {
    if (balanceOf(address(this)) >= swapThreshold) swapAndAddLiquidity(swapThreshold);
    if (balanceOf(address(this)) >= swapThreshold) swapAndSendToRewardsTracker(swapThreshold);
    if (balanceOf(address(this)) >= swapThreshold) swapAndSendToProject(swapThreshold);
  }

  function setDefaultRewardsExclusions() private {
    odysseyRewards.setExcludedAddress(uniswapV2Pair);
    odysseyRewards.setExcludedAddress(address(this));
    odysseyRewards.setExcludedAddress(address(uniswapV2Router));
    odysseyRewards.setExcludedAddress(projectWallet);
  }

  function setFeesByLevel(uint16 level) private {
    swapThreshold = uint256((17-level)) * 1_000_000 ether;
    feeLiquidity = (level<6) ? (6-level) : 0;
    feeProject = (level<4) ? (4-level) : 0;
    feeRewards = (13-level) - feeLiquidity - feeProject;
    feeToSell = feeRewards + feeProject + feeLiquidity;
  }

  function swapAndAddLiquidity(uint256 tokens) private {
    if (accumulatedLiquidity < tokens) return; // NOT YET

    accumulatedLiquidity -= tokens;
    uint256 swapHalf = tokens.div(2);
    uint256 liquidTokens = tokens.sub(swapHalf);
    uint256 liquidETH = swapTokensForETH(swapHalf);
    addLiquidity(liquidTokens, liquidETH);
    emit FundsSentToLiquidity(liquidTokens, liquidETH);
  }

  function swapAndSendToRewardsTracker(uint256 tokens) private {
    if (accumulatedRewards < tokens) return; // NOT YET

    accumulatedRewards -= tokens;
    uint256 swappedETH = swapTokensForETH(tokens);
    if (swappedETH > 0) {
      (bool success,) = address(odysseyRewards).call{value: swappedETH}('');
      if (success) {
        emit FundsSentToRewards(tokens, swappedETH);
        changeMarketCap(swappedETH, tokens);
      }
    }
  }

  function swapAndSendToProject(uint256 tokens) private {
    if (accumulatedProject < tokens) return; // NOT YET

    accumulatedProject -= tokens;
    uint256 swappedETH = swapTokensForETH(tokens);
    if (swappedETH > 0) {
      (bool success,) = address(projectWallet).call{value: swappedETH}('');
      if (success) emit FundsSentToProject(tokens, swappedETH);
    }
  }

  function swapTokensForETH(uint256 tokens) private returns(uint256) {
    address[] memory pair = new address[](2);
    pair[0] = address(this);
    pair[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokens);
    uint256 currentETH = address(this).balance;
    uniswapV2Router.swapExactTokensForETH(tokens, 0, pair, address(this), block.timestamp);
    return address(this).balance.sub(currentETH);
  }

  function transferAndUpdateRewardsTracker(address from, address to, uint256 amount) private {
    super._transfer(from, to, amount);
    try odysseyRewards.trackSell(payable(from), balanceOf(from)) {} catch {}
    try odysseyRewards.trackBuy(payable(to), balanceOf(to)) {} catch {}
  }
}
