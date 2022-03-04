// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');
const IUniswapV2Router02 = artifacts.require('@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol');
const IUniswapV2Pair = artifacts.require('@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol');

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

const WBNB = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c';


const one_hour = 60 * 60;
const six_hours = 6 * one_hour;
const two_hours = 2 * one_hour;
const one_day = 24 * one_hour;

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

function logPriceRewardsEvent(transaction) {
  return MarketCap(transaction, 'FundsSentToRewards');
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let transaction;
  let tracker;
  let uniswapV2Pair;
  let uniswapV2Router;
  let p0;
  let p1;
  let tomorrow = Date.now() + one_day;

  const addresses = {
    project: owner,
    router: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
    dead: '0x000000000000000000000000000000000000dEaD',
    liquidity: owner
  };

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    tracker = await OdysseyRewards.new("OdysseyRewards", "ODSYRV1");
    await tracker.transferOwnership(contract.address, { from: owner });
    await contract.setRewardsTracker(tracker.address);
    uniswapV2Router = await IUniswapV2Router02.at(addresses.router);
    uniswapV2Pair = await IUniswapV2Pair.at(await contract.uniswapV2Pair());
    p0 = await uniswapV2Pair.token0();
    p1 = await uniswapV2Pair.token1();
  });

  it('testing buys', async function () {
    await contract.send(toWei(250), { from: holder1 });
    await contract.send(toWei(250), { from: holder2 });
    await contract.send(toWei(250), { from: holder3 });
    await contract.send(toWei(250), { from: holder4 });
    await contract.send(toWei(250), { from: holder5 });
    await contract.send(toWei(250), { from: holder6 });
    await contract.send(toWei(250), { from: holder7 });
    await contract.send(toWei(250), { from: holder8 });
    await contract.transfer(holder1, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder2, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder3, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder4, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder5, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder6, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder7, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder8, toWei(1_000_000_000), { from: owner });
    await contract.transfer(holder9, toWei(1_000_000_000), { from: owner });

    await contract.transfer(contract.address, toWei(25_000_000_000), { from: owner });

    let data = await contract.getRewardsReport();
    assert.equal(fromWei(data.totalRewardsPaid), 0); // NO REWARDS YET
    assert.equal(fromWei(await contract.balanceOf(contract.address)), 25_000_000_000);
    assert.equal(fromWei(await web3.eth.getBalance(contract.address)), 2_000);
    console.log('Est Price ' + estPrice(2_000, 50_000_000_000), 'marketCap of', 2_000 * BNB_USD);

    console.log('Opening contract to public trading');
    transaction = await contract.openToPublic();
    // expectEvent(transaction, 'LiquidityAddressChanged', { from: owner, to: addresses.dead });
    assert.equal(fromWei(await contract.balanceOf(contract.address)), 0);
    assert.equal(fromWei(await web3.eth.getBalance(contract.address)), 0);


    console.log('Selling 100_000_000 tokens');
    await contract.transfer(uniswapV2Pair.address, toWei(100_000_000), { from: holder1 });
    assert.equal(fromWei(await contract.accumulatedLiquidity()), 5_000_000); // 5%
    assert.equal(fromWei(await contract.accumulatedRewards()),   4_000_000); // 4%
    assert.equal(fromWei(await contract.accumulatedProject()),   3_000_000); // 3%


    // transaction = await uniswapV2Pair.approve(holder1, toWei(1), {from: holder1});
    // console.log(transaction);
    let balance = await contract.balanceOf(holder1);

    console.log('Buying 100 BNB in tokens');
    transaction = await uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens(
      0, [WBNB, contract.address], holder1, tomorrow, { value: toWei(100), from: holder1 }
    );

    let newBalance = await contract.balanceOf(holder1);

    console.log('recieved', fromWei(newBalance) - fromWei(balance), 'tokens for 100 BNB');

    assert.notEqual(balance, newBalance);

    // console.log(transaction);

    // transaction = await uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens(0, [ uniswapV2Pair.token0(), uniswapV2Pair.token1() ], holder9, 1);
    // console.log(transaction);

  });
});
