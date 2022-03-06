// test/Odyssey.test.js
// npx ganache-cli -f https://bsc-dataseed.binance.org/ --gasLimit 999999999 -e 100000
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
  return;
}

function eventArgs(transaction, name) {
  return findEvent(transaction, name).args;
}

function estPrice(bnb, tokens) {
  return (bnb * BNB_USD / tokens).toFixed(9);
}

function MarketCap(transaction, name) {
  let mc = eventArgs(transaction, name);
  let tokens = fromWei(mc.tokens) * 1;
  let bnb = fromWei(mc.value) * 1;
  let price = estPrice(bnb, tokens) * 1;
  let cap = price * 50_000_000_000;
  console.log('  -', name, 'sold', tokens, 'for', bnb, 'BNB. Calculated MarketCap $', cap, 'USD / price', price, 'USD');
}

function logPriceRewardsEvent(transaction) {
  return MarketCap(transaction, 'FundsSentToRewards');
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let transaction;
  let event;
  let tracker;
  let uniswapV2Pair;

  const addresses = {
    project: owner,
    router: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
    liquidity: owner
  };

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    tracker = await OdysseyRewards.new("OdysseyRewards", "ODSYRV1");
    await tracker.transferOwnership(contract.address, { from: owner });
    await contract.setRewardsTracker(tracker.address);

    uniswapV2Pair = await contract.uniswapV2Pair();
    defaults.swapThreshold = await contract.swapThreshold();
    addresses.contract = contract.address;
    addresses.pair = uniswapV2Pair;
  });

  for (let jdx=1;jdx<10;jdx++) {
    it('marketcap', async function () {
      for (let idx=1;idx<10;idx++) {
        await contract.send(toWei(50 * 2**jdx), { from: accounts[idx] });
        await contract.transfer(accounts[idx], toWei(2_500_000_000), { from: owner });
      }
      await contract.transfer(contract.address, toWei(10_000_000_000), { from: owner });
      transaction = await contract.openToPublic();

      let amt = 500_000_000;
      for (let idx=1;idx<10;idx++) {
        console.log(`Selling ${amt.toLocaleString()} tokens`);
        transaction = await contract.transfer(uniswapV2Pair, toWei(amt), { from: accounts[idx] });
        if (event = findEvent(transaction, 'FundsReceived')) {
          if (event = findEvent(transaction, 'FundsSentToRewards')) {
            event = findEvent(transaction, 'MarketCapCalculated');
            let price = (event.args.price / toWei(1)).toFixed(8);
            console.log(
              '  - MarketCapCalculated',
                event.args.marketCap.toNumber(), 'BNB / ', event.args.marketCap.toNumber() * BNB_USD, 'USD | price ',
                price, ' BNB / ', price * BNB_USD, 'USD'
            );
            logPriceRewardsEvent(transaction);
            if (event = findEvent(transaction, 'FeesChanged')) {
              console.log('  - FeesChanged',
                'Buy: ', event.args.feeToBuy.toNumber(),
                ' / Sell', event.args.feeToSell.toNumber(),
                ' / Rewards', event.args.feeRewards.toNumber(),
                ' / Project', event.args.feeProject.toNumber(),
                ' / Liquidity', event.args.feeLiquidity.toNumber(),
                ' / swapAt', fromWei(event.args.swapAt) * 1.0
              );
              break;
            }
          }
        }
      }

      let cnt = await tracker.records();
      let sum = 0;
      for (let idx=1;idx<=cnt;idx++) {
        let report = await contract.getRewardsReportAccountAt(idx);
        console.log(idx, report.index.toNumber(), fromWei(report.tokens), fromWei(report.rewardsClaimed));
        sum += fromWei(report.rewardsClaimed) * 1;
      }
      console.log(sum);
    });
  }
});
