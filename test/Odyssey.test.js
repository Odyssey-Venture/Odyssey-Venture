// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const BN = web3.utils.BN;
const chaiBN = require('chai-bn')(BN);
chai.use(chaiBN);
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const expect = chai.expect;
const assert = chai.assert;

const ROUTER = "0x10ED43C718714eb63d5aA57B78B54704E256024E";

const defaults = {
  name: 'Odyssey',
  symbol: '$ODSY',
  decimals: 18,
  totalSupply: 50_000_000_000,
  maxWallet: 500_000_000,
  maxSell: 50_000_000,
  swapThreshold: 500_000
};

function toWei(count) {
  return count * (10 ** 18);
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3] = accounts;
  let contract;
  let transaction;
  let uniswapV2Pair;

  const wallets = {
    project: '0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584',
    liquidity: '0x000000000000000000000000000000000000dEaD'
  };

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    uniswapV2Pair = await contract.uniswapV2Pair();
    wallets.liquidity = owner;
  });

  it('has an owner', async function() {
    assert.equal(await contract.owner(), owner);
  });

  it('initializes the correct values', async function () {
    console.log('Checking name');
    assert.equal(await contract.name(), defaults.name, 'Name is incorrect');
    console.log('Checking symbol');
    assert.equal((await contract.symbol()), defaults.symbol, 'Symbol is incorrect');
    console.log('Checking decimals');
    assert.equal((await contract.decimals()), defaults.decimals, 'decimals is incorrect');
  });

  it('sets the correct total supply upon deployment', async function () {
    console.log('Checking totalSupply');
    const supply = await contract.totalSupply();
    assert.equal(supply, toWei(defaults.totalSupply), 'Mint incorrect');
    console.log('Checking totalSupply allocated to owner');
    expect(await contract.balanceOf(owner)).to.be.a.bignumber.equal(supply);
    assert.equal(await contract.balanceOf(owner), toWei(defaults.totalSupply), 'Owner does not have totalSupply');
    console.log('Checking no supply allocated to Project wallet');
    expect(await contract.balanceOf(wallets.project)).to.be.a.bignumber.equal('0');
  });

  it('only owner can send funds to contract', async function() {
    await expectRevert(contract.send(6, { from: holder2 }), 'Ownable: caller is not the owner');
    transaction = await contract.send(6, { from: owner });
    expectEvent(transaction, 'ReceivedFunds', { from: owner, amount: (6).toString() });

    console.log(owner.balance);
  });

  it('has max wallet and max sell limits', async function () {
    console.log('Checking max wallet and sell');
    assert.equal(await contract.maxWalletAmount(), toWei(defaults.maxWallet));
    assert.equal(await contract.maxSellAmount(), toWei(defaults.maxSell));
  });

  it('has a project wallet that owner can update', async function () {
    console.log('Checking project wallet');
    assert.equal(await contract.projectWallet(), wallets.project, 'Project Wallet is incorrect');

    console.log('Checking project wallet is in exclusions list');
    assert.isTrue(await contract.isExcludedFromFees(wallets.project), 'Project Wallet is incorrect');

    console.log('Checking project wallet cannot be set to existing value');
    await expectRevert(contract.setProjectWallet(wallets.project, { from: owner }), 'ODSY: Value already set');

    console.log('Checking owner can change project wallet');
    transaction = await contract.setProjectWallet(holder1, { from: owner });
    assert.equal(await contract.projectWallet(), holder1, 'Project Wallet not changed');
    assert.isFalse(await contract.isExcludedFromFees(wallets.project), 'Old Project Wallet should not be in exclusions');
    assert.isTrue(await contract.isExcludedFromFees(holder1), 'New Project Wallet should be in exclusions');
    expectEvent(transaction, 'ProjectWalletChanged', { previousValue: wallets.project, newValue: holder1 });

    console.log('Checking only owner can change project wallet');
    await expectRevert(contract.setProjectWallet(holder1, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('has a liquidity wallet that owner can update', async function () {
    console.log('Checking liquidity wallet');
    assert.equal(await contract.liquidityWallet(), wallets.liquidity, 'Liquidity Wallet is incorrect');

    console.log('Checking liquidity wallet is in exclusions list');
    assert.isTrue(await contract.isExcludedFromFees(wallets.liquidity), 'Liquidity Wallet is incorrect');

    console.log('Checking liquidity wallet cannot be set to existing value');
    await expectRevert(contract.setLiquidityWallet(wallets.liquidity, { from: owner }), 'ODSY: Value already set');

    console.log('Checking owner can change liquidity wallet');
    transaction = await contract.setLiquidityWallet(holder1, { from: owner });
    assert.equal(await contract.liquidityWallet(), holder1, 'Liquidity Wallet should have changed');
    assert.isTrue(await contract.isExcludedFromFees(holder1), 'New Liquidity Wallet should be in exclusions');
    expectEvent(transaction, 'LiquidityWalletChanged', { previousValue: wallets.liquidity, newValue: holder1 });

    await contract.setLiquidityWallet(holder2, { from: owner });
    assert.isFalse(await contract.isExcludedFromFees(holder1), 'Old Liquidity Wallet should not be in exclusions');
    assert.isTrue(await contract.isExcludedFromFees(holder2), 'New Liquidity Wallet should be in exclusions');

    console.log('Checking only owner can change liquidity wallet');
    await expectRevert(contract.setLiquidityWallet(holder1, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to exclude wallets from fees', async function () {
    await expectRevert(contract.excludeFromFees(holder1, true, { from: holder1 }), 'Ownable: caller is not the owner');
    assert.isFalse(await contract.isExcludedFromFees(holder1));
    transaction = await contract.excludeFromFees(holder1, true, { from: owner });
    expectEvent(transaction, 'ExcludedFromFees', { account: holder1, isExcluded: true });
    assert.isTrue(await contract.isExcludedFromFees(holder1), 'Wallet should be in exclusions');

    transaction = await contract.excludeFromFees(holder1, false, { from: owner });
    expectEvent(transaction, 'ExcludedFromFees', { account: holder1, isExcluded: false });
    assert.isFalse(await contract.isExcludedFromFees(holder1), 'Wallet should not be in exclusions');
  });

  it('calculates fees based on last marketcap', async function () {
    let tiers = [
      { buy: 2, rewards: 6, liquidity: 4, project: 2, marketcap:       1_000 },
      { buy: 2, rewards: 6, liquidity: 4, project: 2, marketcap:     999_999 },
      { buy: 2, rewards: 5, liquidity: 3, project: 2, marketcap:   1_000_000 },
      { buy: 2, rewards: 4, liquidity: 2, project: 2, marketcap:   4_000_000 },
      { buy: 2, rewards: 3, liquidity: 2, project: 1, marketcap:  16_000_000 },
      { buy: 2, rewards: 2, liquidity: 2, project: 0, marketcap:  64_000_000 },
      { buy: 2, rewards: 1, liquidity: 1, project: 0, marketcap: 256_000_000 }
    ];
    for (var idx=0; idx < tiers.length; idx++) {
      fee = tiers[idx];
      fee.total = fee.rewards + fee.liquidity + fee.project;
      console.log(`Checking fees when MC ${fee.marketcap}: Buy ${fee.buy} / Sell ${fee.total} [reward ${fee.rewards} market ${fee.project} liquid ${fee.liquidity}]`);
      transaction = await contract.setMarketCap(fee.marketcap);
      assert.equal((await contract.lastMarketCap()).toNumber(), fee.marketcap);
      assert.equal((await contract.feeToBuy()).toNumber(),      fee.buy);
      assert.equal((await contract.feeRewards()).toNumber(),    fee.rewards);
      assert.equal((await contract.feeProject()).toNumber(),    fee.project);
      assert.equal((await contract.feeLiquidity()).toNumber(),  fee.liquidity);
      assert.equal((await contract.feeToSell()).toNumber(),     fee.total);
      expectEvent(transaction, 'FeesChanged', {
        marketCap:    fee.marketcap.toString(),
        feeToBuy:     fee.buy.toString(),
        feeToSell:    fee.total.toString(),
        feeRewards:   fee.rewards.toString(),
        feeProject:   fee.project.toString(),
        feeLiquidity: fee.liquidity.toString()
      });
    }
  });

  it('can tell difference between a buy, a sell, and a transfer', async function () {
    console.log('Checking that moving from uniswapV2Pair to EOA is a Buy');
    let isBuy = await contract.isBuy(uniswapV2Pair, owner);
    assert.isTrue(isBuy, 'isBuy has failed.');
    console.log('Checking that moving from EOA to uniswapV2Pair is a Sell');
    let isSell = await contract.isSell(owner, uniswapV2Pair);
    assert.isTrue(isSell, 'isSell has failed.');
    console.log('Checking that moving from EOA to EOA is a Transfer');
    let isTransfer = await contract.isTransfer(owner, holder2);
    assert.isTrue(isTransfer, 'isTransfer has failed.');
  });

  it('collects no fees when transferring EOA to EOA', async function() {
    let totalSupply = await contract.totalSupply();
    const amount = 10000;
    const bnAmount = new BN(amount);
    console.log('Checking transfer from wallet to wallet');
    transaction = await contract.transfer(holder1, amount, { from: owner });
    expectEvent(transaction, 'Transfer', { from: owner, to: holder1, value: bnAmount });
    expect(await contract.balanceOf(owner)).to.be.a.bignumber.equal(totalSupply.sub(bnAmount));
    expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal(bnAmount);

    transaction = await contract.transfer(holder2, amount, { from: holder1 });
    expectEvent(transaction, 'Transfer', { from: holder1, to: holder2, value: bnAmount });
    expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal('0');
    expect(await contract.balanceOf(holder2)).to.be.a.bignumber.equal(bnAmount);
    console.log('Checking that no fees were sent to Accumulators');
    expect(await contract.accumulatedRewards()).to.be.a.bignumber.equal('0');
    expect(await contract.accumulatedProject()).to.be.a.bignumber.equal('0');
    expect(await contract.accumulatedLiquidity()).to.be.a.bignumber.equal('0');
    expect(await contract.balanceOf(contract.address)).to.be.a.bignumber.equal('0');
  });

  // it('collects proper fees when transaction is a buy', async function() {
    // let totalSupply = await contract.totalSupply();
    // const amount = 10000;
    // const bnAmount = new BN(amount);
    // transaction = await contract.transfer(ROUTER, amount, { from: owner });
    // console.log(transaction);
    // expectEvent(transaction, 'Transfer', { from: owner, to: ROUTER, value: bnAmount });
    // await contract.transfer(holder1, amount, { from: uniswapV2Pair });
    // console.log((await contract.balanceOf(owner)).toString());
    // console.log((await contract.balanceOf(uniswapV2Pair)).toString());
    // console.log((await contract.balanceOf(holder1)).toString());
    // console.log((await contract.balanceOf(wallets.project)).toString());
    // console.log((await contract.balanceOf(wallets.liquidity)).toString());
    // expect(await contract.balanceOf(owner)).to.be.a.bignumber.equal(totalSupply.sub(bnAmount));
    // expect(await contract.balanceOf(uniswapV2Pair)).to.be.a.bignumber.equal(bnAmount);
  // });
});
