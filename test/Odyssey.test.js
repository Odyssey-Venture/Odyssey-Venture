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
    project: owner,
    liquidity: owner
  };

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    uniswapV2Pair = await contract.uniswapV2Pair();
  });

  it('initializes the correct values', async function () {
    assert.equal(await contract.name(), 'Odyssey');
    assert.equal((await contract.symbol()), '$ODSY');
    assert.equal((await contract.decimals()), 18);
  });

  it('allow owner to open contract to public', async function() {
    await contract.openToPublic({ from: owner });
    assert.isTrue(await contract.isOpenToPublic());
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
  });

  it('can only openToPublic once', async function() {
    await contract.openToPublic({ from: owner });
    await expectRevert(contract.openToPublic({ from: owner }), 'Value unchanged');
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
    await expectRevert(contract.setFeeless(holder1, false, { from: owner }), "Value unchanged");
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

  it('allows only current project wallet to change project wallet', async function () {
    await expectRevert(contract.setProjectWallet(holder1, { from: holder1 }), 'Value invalid');
  });

  it('allows project wallet to set project wallet', async function () {
    transaction = await contract.setProjectWallet(holder1, { from: wallets.project });
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
    await expectRevert(contract.setProjectWallet(wallets.project, { from: owner }), "Value unchanged");
  });

  it('allows owner to update tracker', async function() {
    let newTracker = await OdysseyRewards.new('OdysseyRewards', 'ODSYRV2', {from: owner });
    await newTracker.transferOwnership(contract.address, { from: owner });
    transaction = await contract.setRewardsTracker(newTracker.address);
    expectEvent(transaction, 'RewardsTrackerChanged', { from: tracker.address, to: newTracker.address });
    assert.equal(await contract.odysseyRewards(), newTracker.address);
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    assert.equal(await tracker.symbol(), 'ODSYRV2');
  });

  it('allows only owner to set gasLimit', async function () {
    await expectRevert(contract.setGasLimit(400_000, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set gasLimit', async function () {
    transaction = await contract.setGasLimit(400_000, { from: owner });
    expectEvent(transaction, 'GasLimitChanged', { from: '300000', to: '400000' });
    assert.equal(await contract.gasLimit(), 400_000);
  });

  it('allows owner to set gasLimit between 250k and 750k', async function () {
    await expectRevert(contract.setGasLimit(249_999, { from: owner }), 'Value invalid');
    await expectRevert(contract.setGasLimit(750_001, { from: owner }), 'Value invalid');
  });

  it('requires the value of GasLimit to change if updated', async function () {
    await expectRevert(contract.setGasLimit(300_000, { from: owner }), "Value unchanged");
  });

  it('rejects transfers to zero address', async function() {
    await expectRevert(contract.transfer(ZERO, 1, { from: owner }), 'Value invalid');
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
    // console.log((await contract.balanceOf(uniswapV2Pair)).toString());
  });

  it('allows only owner to turn staking on', async function () {
    await expectRevert(contract.setRewardsStaking(true, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('requires the value of IsStakingOn to change if updated', async function () {
    await expectRevert(contract.setRewardsStaking(false, { from: owner }), "Value unchanged");
  });

  it('allows owner to toggle staking option', async function () {
    await contract.setRewardsStaking(true);
    let report = await contract.getRewardsReport();
    assert.isTrue(report.stakingOn);
  });
});
