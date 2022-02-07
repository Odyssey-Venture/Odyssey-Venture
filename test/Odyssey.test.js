// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const BN = web3.utils.BN;
const chaiBN = require('chai-bn')(BN);
chai.use(chaiBN);
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const expect = chai.expect;
const assert = chai.assert;

const ROUTER = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
const ZERO = '0x0000000000000000000000000000000000000000';

const defaults = {
  totalSupply: 50_000_000_000,
  maxWallet: 5_000_000_000,
  maxSell: 500_000_000,
  swapThreshold: 16_000_000
};

const tiers = [
  { level: 1, buy: 2, rewards: 6, liquidity: 4, project: 2, marketcap:       1_000 },
  { level: 2, buy: 2, rewards: 5, liquidity: 3, project: 2, marketcap:   1_000_000 },
  { level: 3, buy: 2, rewards: 4, liquidity: 2, project: 2, marketcap:   4_000_000 },
  { level: 4, buy: 2, rewards: 3, liquidity: 2, project: 1, marketcap:  16_000_000 },
  { level: 5, buy: 2, rewards: 2, liquidity: 2, project: 0, marketcap:  64_000_000 },
  { level: 6, buy: 2, rewards: 1, liquidity: 1, project: 0, marketcap: 256_000_000 }
];

function toWei(count) {
  return `${count}000000000000000000`;
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3] = accounts;
  let contract;
  let transaction;
  let uniswapV2Pair;
  let tracker;

  const wallets = {
    project: '0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584',
    liquidity: owner
  };

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    uniswapV2Pair = await contract.uniswapV2Pair();
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    // await contract.openToPublic();
  });

  it('initializes the correct values', async function () {
    assert.equal(await contract.name(), 'Odyssey');
    assert.equal((await contract.symbol()), '$ODSY');
    assert.equal((await contract.decimals()), 18);
  });

  it('sets the correct total supply upon deployment', async function () {
    assert.equal(await contract.totalSupply(), toWei(defaults.totalSupply));
  });

  it('anyone can send funds to contract', async function() {
    transaction = await contract.send(toWei(1), { from: holder3 });
    expectEvent(transaction, 'FundsReceived', { from: holder3, amount: toWei(1) });
  });

  it('only owner can open contract to public', async function() {
    await expectRevert(contract.openToPublic({ from: holder2 }), 'Ownable: caller is not the owner');
    assert.isFalse(await contract.isOpenToPublic());
    await expectRevert(contract.openToPublic({ from: owner }), 'Must have bnb to pair for launch');
    await contract.send(toWei(1000), { from: holder3 });
    await contract.transfer(contract.address, toWei(25_000_000_000), { from: owner });
    await contract.openToPublic({ from: owner });
    assert.isTrue(await contract.isOpenToPublic());
  });

  it('has a max wallet limit', async function () {
    assert.equal(await contract.maxWalletLimit(), toWei(defaults.maxWallet));
  });

  it('has a max sell limit', async function () {
    assert.equal(await contract.maxSellAmount(), toWei(defaults.maxSell));
  });

  it('has a threshold for swapping tokens to BSD', async function () {
    assert.equal(await contract.swapThreshold(), toWei(defaults.swapThreshold));
  });

  it('allows only owner to turn fees off for an account', async function () {
    await expectRevert(contract.setFeeless(holder1, true, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to turn fees on/off for an account', async function () {
    transaction = await contract.setFeeless(holder1, true, { from: owner });
    expectEvent(transaction, 'IsFeelessChanged', { account: holder1, excluded: true });
    assert.isTrue(await contract.isFeeless(holder1));
    transaction = await contract.setFeeless(holder1, false, { from: owner });
    expectEvent(transaction, 'IsFeelessChanged', { account: holder1, excluded: false });
    assert.isFalse(await contract.isFeeless(holder1));
  });

  it('requires the value of Feeless to change if updated', async function () {
    await expectRevert(contract.setFeeless(holder1, false, { from: owner }), 'Value unchanged');
  });

  it('allows only owner to add presale wallets', async function () {
    await expectRevert(contract.setPresale(holder1, true, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to add/remove presale wallets', async function () {
    await contract.setPresale(holder1, true, { from: owner });
    assert.isTrue(await contract.isPresale(holder1));
    transaction = await contract.setPresale(holder1, false, { from: owner });
    assert.isFalse(await contract.isPresale(holder1));
  });

  it('allows only owner to set project wallet', async function () {
    await expectRevert(contract.setProjectWallet(holder1, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set project wallet', async function () {
    transaction = await contract.setProjectWallet(holder1, { from: owner });
    expectEvent(transaction, 'ProjectWalletChanged', { from: wallets.project, to: holder1 });
    assert.equal(await contract.projectWallet(), holder1);
  });

  it('exempts project wallet from fees', async function () {
    assert.isTrue(await contract.isFeeless(wallets.project));
    assert.isFalse(await contract.isFeeless(holder1));
    await contract.setProjectWallet(holder1, { from: owner });
    assert.isTrue(await contract.isFeeless(holder1));
    assert.isFalse(await contract.isFeeless(wallets.project));
  });

  it('requires the value of ProjectWallet to change if updated', async function () {
    await expectRevert(contract.setProjectWallet(wallets.project, { from: owner }), 'Value unchanged');
  });

  it('allows only owner to set liquidity wallet', async function () {
    await expectRevert(contract.setLiquidityAddress(holder1, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set liquidity wallet', async function () {
    transaction = await contract.setLiquidityAddress(holder1, { from: owner });
    expectEvent(transaction, 'LiquidityWalletChanged', { from: wallets.liquidity, to: holder1 });
    assert.equal(await contract.liquidityAddress(), holder1);
  });

  it('exempts liquidity wallet from fees', async function () {
    assert.isTrue(await contract.isFeeless(wallets.liquidity));
    assert.isFalse(await contract.isFeeless(holder1));
    await contract.setLiquidityAddress(holder1, { from: owner });
    assert.isTrue(await contract.isFeeless(holder1));
    assert.isFalse(await contract.isFeeless(wallets.liquidity));
  });

  it('requires the value of LiquidityWallet to change if updated', async function () {
    await expectRevert(contract.setLiquidityAddress(wallets.liquidity, { from: owner }), 'Value unchanged');
  });

  it('allows only owner to set gasLimit', async function () {
    await expectRevert(contract.setGasLimit(400_000, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set gasLimit', async function () {
    transaction = await contract.setGasLimit(400_000, { from: owner });
    expectEvent(transaction, 'GasLimitChanged', { from: '300000', to: '400000' });
    assert.equal(await contract.gasLimit(), 400_000);
  });

  it('allows owner to set gasLimit between 250k and 500k', async function () {
    await expectRevert(contract.setGasLimit(249_999, { from: owner }), 'Value invalid');
    await expectRevert(contract.setGasLimit(500_001, { from: owner }), 'Value invalid');
  });

  it('requires the value of GasLimit to change if updated', async function () {
    await expectRevert(contract.setGasLimit(300_000, { from: owner }), 'Value unchanged');
  });

  it('allows only owner to set marketCap', async function () {
    await expectRevert(contract.setMarketCap(400_000, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set marketCap', async function () {
    transaction = await contract.setMarketCap(3_000_000, { from: owner });
    expectEvent(transaction, 'FeesChanged', {
      marketCap: '3000000', feeToBuy: '2', feeRewards: '5', feeLiquidity: '3', feeProject: '2', feeToSell: '10'
    });
    assert.equal((await contract.feeLevel()).toNumber(), 2);
  });

  for (var idx=0; idx < tiers.length; idx++) {
    let fee = tiers[idx];
    fee.total = fee.rewards + fee.liquidity + fee.project;
    it(`Checking fees when MC ${fee.marketcap}: Buy ${fee.buy} / Sell ${fee.total} [reward ${fee.rewards} market ${fee.project} liquid ${fee.liquidity}]`, async function () {
      await contract.setMarketCap(fee.marketcap);
      assert.equal((await contract.feeLevel()).toNumber(),     fee.level);
      assert.equal((await contract.feeToBuy()).toNumber(),     fee.buy);
      assert.equal((await contract.feeRewards()).toNumber(),   fee.rewards);
      assert.equal((await contract.feeProject()).toNumber(),   fee.project);
      assert.equal((await contract.feeLiquidity()).toNumber(), fee.liquidity);
      assert.equal((await contract.feeToSell()).toNumber(),    fee.total);
    });
  }

  it('rejects transfers to zero address', async function() {
    await expectRevert(contract.transfer(ZERO, 1, { from: owner }), 'Invalid address');
  });

  it('rejects transfers of 0 tokens', async function() {
    await expectRevert(contract.transfer(holder1, 0, { from: owner }), 'Value invalid');
  });

  it('allows pre-sale wallets to transfer before trading is public', async function() {
    assert.isFalse(await contract.isOpenToPublic());
    assert.isTrue(await contract.isPresale(owner));
    await contract.transfer(holder1, 1, { from: owner });
    assert.equal(await contract.balanceOf(holder1), '1');
  });

  it('restricts non pre-sale wallets from transfering before trading is public', async function() {
    assert.isFalse(await contract.isOpenToPublic());
    assert.isFalse(await contract.isPresale(holder1));
    await contract.transfer(holder1, 1, { from: owner });
    await expectRevert(contract.transfer(holder2, 1, { from: holder1 }), 'Trading closed');
  });

  it('enforces max wallet size before trading open', async function() {
    assert.isFalse(await contract.isOpenToPublic());
    await expectRevert(contract.transfer(holder1, toWei(defaults.maxWallet+1), { from: owner }), 'Wallet over limit');
  });

  it('does not enforce max wallet size transfers to AMM before trading open', async function() {
    assert.isFalse(await contract.isOpenToPublic());
    await contract.transfer(uniswapV2Pair, toWei(defaults.maxWallet+1), { from: owner });
    console.log((await contract.balanceOf(uniswapV2Pair)).toString());
  });

  // it('collects no fees when transferring EOA to EOA', async function() {
  //   let totalSupply = await contract.totalSupply();
  //   const amount = 10000;
  //   const bnAmount = new BN(amount);
  //   console.log('Checking transfer from wallet to wallet');
  //   transaction = await contract.transfer(holder1, amount, { from: owner });
  //   expectEvent(transaction, 'Transfer', { from: owner, to: holder1, value: bnAmount });
  //   expect(await contract.balanceOf(owner)).to.be.a.bignumber.equal(totalSupply.sub(bnAmount));
  //   expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal(bnAmount);

  //   transaction = await contract.transfer(holder2, amount, { from: holder1 });
  //   expectEvent(transaction, 'Transfer', { from: holder1, to: holder2, value: bnAmount });
  //   expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal('0');
  //   expect(await contract.balanceOf(holder2)).to.be.a.bignumber.equal(bnAmount);
  //   console.log('Checking that no fees were sent to Accumulators');
  //   expect(await contract.accumulatedRewards()).to.be.a.bignumber.equal('0');
  //   expect(await contract.accumulatedProject()).to.be.a.bignumber.equal('0');
  //   expect(await contract.accumulatedLiquidity()).to.be.a.bignumber.equal('0');
  //   expect(await contract.balanceOf(contract.address)).to.be.a.bignumber.equal('0');
  // });

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
