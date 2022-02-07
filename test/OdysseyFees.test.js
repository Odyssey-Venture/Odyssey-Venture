// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
var chai = require('chai');
const assert = chai.assert;

const BNB_USD = 415.00;

let defaults = {
  totalSupply: 50_000_000_000,
  maxWallet: 5_000_000_000,
  maxSell: 500_000_000,
  swapThreshold: 16_000_000
};

function toWei(count) {
  return `${count}000000000000000000`;
}

function fromWei(bn) {
  return (bn / toWei(1)).toFixed(2);
}

function findEvent(transaction, event) {
  for (const log of transaction.logs) if (log.event==event) return log;
  return {};
}

function eventArgs(transaction, name) {
  return findEvent(transaction, name).args;
}

function estPrice(bnb, tokens) {
  return (bnb * BNB_USD / tokens).toFixed(8);
}

function MarketCap(transaction, name) {
  let mc = eventArgs(transaction, 'MarketCapCalculated');
  let price = (mc.price / 10**9 * BNB_USD).toFixed(8);
  let cap = fromWei(mc.marketCap * BNB_USD);
  let tokens = fromWei(mc.tokens);
  let bnb = fromWei(mc.value);
  console.log(`${name}: sold ${tokens} for ${bnb} BNB. Contract calculates Market Cap  ${cap} USD / price ${price}`);
}

function logPriceLiquidityEvent(transaction) {
  MarketCap(transaction, 'LiquidityAdded');
}

function PriceFromFunding(transaction, name) {
  MarketCap(transaction, name);
}

function logPriceRewardsEvent(transaction) {
  return PriceFromFunding(transaction, 'FundsSentToRewards');
}

function logPriceProjectEvent(transaction) {
  return PriceFromFunding(transaction, 'FundsSentToProject');
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let transaction;
  let tracker;
  let uniswapV2Pair;
  let swappedBNB;

  const addresses = {
    project: '0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584',
    router: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
    dead: '0x000000000000000000000000000000000000dEaD',
    liquidity: owner
  };

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    uniswapV2Pair = await contract.uniswapV2Pair();
    defaults.swapThreshold = await contract.swapThreshold();
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    addresses.contract = contract.address;
    addresses.pair = uniswapV2Pair;
  });

  it('project wallet', async function () {
    await contract.send(toWei(500), { from: holder1 });
    await contract.send(toWei(500), { from: holder2 });
    await contract.send(toWei(500), { from: holder3 });
    await contract.send(toWei(500), { from: holder4 });
    await contract.send(toWei(500), { from: holder5 });
    await contract.send(toWei(500), { from: holder6 });
    await contract.send(toWei(500), { from: holder7 });
    await contract.send(toWei(500), { from: holder8 });
    await contract.transfer(holder1, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder2, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder3, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder4, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder5, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder6, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder7, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder8, toWei(1_000_000_000), { from: owner });

    await contract.transfer(contract.address, toWei(25_000_000_000), { from: owner });

    let project_balance = await web3.eth.getBalance(addresses.project);
    let data = await contract.getRewardsSettings();
    assert.equal(fromWei(data.rewardsDistributed), 0); // NO REWARDS YET
    assert.equal(fromWei(await contract.balanceOf(addresses.contract)), 25_000_000_000);
    assert.equal(fromWei(await web3.eth.getBalance(addresses.contract)), 4_000);
    console.log('Est Price ' + estPrice(4_000, 50_000_000_000), 'marketCap of', 4_000 * BNB_USD);

    console.log('Opening contract to public trading');
    transaction = await contract.openToPublic();
    expectEvent(transaction, 'LiquidityWalletChanged', { from: owner, to: addresses.dead });
    assert.equal(fromWei(await contract.balanceOf(addresses.contract)), 0);
    assert.equal(fromWei(await web3.eth.getBalance(addresses.contract)), 0);


    console.log('Selling 100_000_000 tokens');
    await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder1 });
    assert.equal(fromWei(await contract.accumulatedRewards()),   6_000_000); // 6%
    assert.equal(fromWei(await contract.accumulatedLiquidity()), 4_000_000); // 4%
    assert.equal(fromWei(await contract.accumulatedProject()),   2_000_000); // 2%


    console.log('Selling 100_000_000 tokens');
    await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder2 });
    assert.equal(fromWei(await contract.accumulatedRewards()),   12_000_000); // 6%
    assert.equal(fromWei(await contract.accumulatedLiquidity()),  8_000_000); // 4%
    assert.equal(fromWei(await contract.accumulatedProject()),    4_000_000); // 2%


    console.log('Selling 100_000_000 tokens - Rewards over threshold / swap to BNB');
    transaction = await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder3 });
    expectEvent(transaction, 'Transfer', { from: addresses.contract, to: uniswapV2Pair, value: defaults.swapThreshold });
    expectEvent(transaction, 'FundsReceived', { from:  addresses.router });
    swappedBNB = findEvent(transaction, 'FundsReceived').args.amount;
    console.log(`Verify ${fromWei(swappedBNB)} BNB from swap went to rewards`);
    expectEvent(transaction, 'FundsSentToRewards', { amount: swappedBNB });
    expectEvent.inTransaction(transaction.tx, tracker, 'FundsDeposited', { amount: swappedBNB });
    expectEvent.inTransaction(transaction.tx, tracker, 'FundsWithdrawn', { account: holder2 });
    expectEvent.inTransaction(transaction.tx, tracker, 'FundsWithdrawn', { account: holder7 });
    expectEvent.inTransaction(transaction.tx, tracker, 'ClaimsProcessed', { iterations: '6' });
    assert.equal(fromWei((await contract.getRewardsSettings()).rewardsDistributed), fromWei(swappedBNB)); // NOW WE HAVE REWARDS
    assert.equal(fromWei(await contract.accumulatedRewards()),    2_000_000); // 18m ~ 16m swap = 2m
    assert.equal(fromWei(await contract.accumulatedLiquidity()), 12_000_000); // +4%
    assert.equal(fromWei(await contract.accumulatedProject()),    6_000_000); // +2%
    logPriceRewardsEvent(transaction);


    console.log('Selling 100_000_000 tokens - Liquidity over threshold / swap to LP');
    transaction = await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder4 });
    expectEvent(transaction, 'FundsReceived', { from:  addresses.router });
    swappedBNB = findEvent(transaction, 'FundsReceived').args.amount;
    expectEvent(transaction, 'LiquidityAdded', { tokens: toWei(8_000_000), value: swappedBNB });
    assert.equal(fromWei(await contract.accumulatedRewards()),    8_000_000); // 6%
    assert.equal(fromWei(await contract.accumulatedLiquidity()),          0); // +4% ~ 16m - 16m swap = 0
    assert.equal(fromWei(await contract.accumulatedProject()),    8_000_000); // +2%
    logPriceLiquidityEvent(transaction);


    console.log('Selling 100_000_000 tokens');
    transaction = await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder5 });
    assert.equal(fromWei(await contract.accumulatedRewards()),   14_000_000); // 6%
    assert.equal(fromWei(await contract.accumulatedLiquidity()),  4_000_000); // +4%
    assert.equal(fromWei(await contract.accumulatedProject()),   10_000_000); // +2%


    console.log('Selling 100_000_000 tokens - Rewards over threshold / swap to BNB');
    transaction = await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder6 });
    expectEvent(transaction, 'FundsReceived', { from:  addresses.router });
    expectEvent(transaction, 'FundsSentToRewards');
    expectEvent.inTransaction(transaction.tx, tracker, 'FundsDeposited');
    expectEvent.inTransaction(transaction.tx, tracker, 'ClaimsProcessed');
    assert.equal(fromWei(await contract.accumulatedRewards()),    4_000_000); // 6% ~ 20m - 16m swap = 4
    assert.equal(fromWei(await contract.accumulatedLiquidity()),  8_000_000); // +4%
    assert.equal(fromWei(await contract.accumulatedProject()),   12_000_000); // +2%
    logPriceRewardsEvent(transaction);


    console.log('Selling 100_000_000 tokens');
    transaction = await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder7 });
    assert.equal(fromWei(await contract.accumulatedRewards()),   10_000_000); // 6%
    assert.equal(fromWei(await contract.accumulatedLiquidity()), 12_000_000); // +4%
    assert.equal(fromWei(await contract.accumulatedProject()),   14_000_000); // +2%


    console.log('Selling 100_000_000 tokens - Liquid + Rewards + Project Funds');
    transaction = await contract.transfer(uniswapV2Pair, toWei(100_000_000), { from: holder8 });
    expectEvent(transaction, 'LiquidityAdded');
    logPriceLiquidityEvent(transaction);
    expectEvent(transaction, 'FundsSentToRewards');
    logPriceRewardsEvent(transaction);
    expectEvent(transaction, 'FundsSentToProject');
    logPriceProjectEvent(transaction);

    swappedBNB = findEvent(transaction, 'FundsSentToProject').args.amount;
    console.log(`Verify ${fromWei(swappedBNB)} BNB from swap went to project wallet`);
    let project_funds = await web3.eth.getBalance(addresses.project) - project_balance;
    assert.equal(fromWei(swappedBNB), fromWei(project_funds));

    assert.equal(fromWei(await contract.accumulatedRewards()),   0); // 6% ~ 16m - 16m swap = 0
    assert.equal(fromWei(await contract.accumulatedLiquidity()), 0); // +4% ~ 16m - 16m swap = 0
    assert.equal(fromWei(await contract.accumulatedProject()),   0); // +2% ~ 16m - 16m swap = 0
  });
});
