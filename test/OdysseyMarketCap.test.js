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

function logEvents(transaction) {
  let txt = [];
  for (const log of transaction.logs) txt.push(log.event);
  console.log(`  - Events (${txt.length})`, txt.join());
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

function logPriceLiquidityEvent(transaction) {
  MarketCap(transaction, 'FundsSentToLiquidity');
}

function logPriceRewardsEvent(transaction) {
  return MarketCap(transaction, 'FundsSentToRewards');
}

function logPriceProjectEvent(transaction) {
  return MarketCap(transaction, 'FundsSentToProject');
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let transaction;
  let event;
  let tracker;
  let uniswapV2Pair;

  const addresses = {
    project: '0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584',
    router: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
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
    for (let idx=1;idx<10;idx++) {
      await contract.send(toWei(750), { from: accounts[idx] });
      await contract.transfer(accounts[idx], toWei(2_500_000_000), { from: owner });
    }
    await contract.transfer(contract.address, toWei(25_000_000_000), { from: owner });
    let project_balance = fromWei(await web3.eth.getBalance(addresses.project));
    console.log('Project wallet funds starting at', project_balance);
    let project_funds = 0;
    let seed = fromWei(await web3.eth.getBalance(addresses.contract));
    console.log('Seed money', seed, 'Est Price', estPrice(seed, 50_000_000_000) * 1, 'marketCap', seed * BNB_USD);

    console.log('Opening contract to public trading');
    transaction = await contract.openToPublic();
    assert.equal(fromWei(await contract.balanceOf(addresses.contract)), 0);
    assert.equal(fromWei(await web3.eth.getBalance(addresses.contract)), 0);

    let sold = 0;
    let amt = 100_000_000;
    for (let jdx=1;jdx<10;jdx++)
    for (let idx=1;idx<10;idx++) {
      console.log(`Selling ${amt.toLocaleString()} tokens - total sold ${sold.toLocaleString()}`);
      transaction = await contract.transfer(uniswapV2Pair, toWei(amt), { from: accounts[idx] });
      sold += amt;
      logEvents(transaction);
      console.log('  - accumulatedLiquidity', fromWei(await contract.accumulatedLiquidity()).padStart(18, ' '));
      console.log('  - accumulatedRewards  ', fromWei(await contract.accumulatedRewards()).padStart(18, ' '));
      console.log('  - accumulatedProject  ', fromWei(await contract.accumulatedProject()).padStart(18, ' '));

      if (event = findEvent(transaction, 'FundsReceived')) {
        if (event = findEvent(transaction, 'FundsSentToRewards')) {
          let bnb = event.args.value / toWei(1);
          console.log('  - Verify ', bnb, 'BNB from swap went to rewards');
          event = findEvent(transaction, 'MarketCapCalculated');
          let price = (event.args.price / toWei(1)).toFixed(8);
          console.log(
            '  - MarketCapCalculated',
              event.args.marketCap.toNumber(), 'BNB / ', event.args.marketCap.toNumber() * BNB_USD, 'USD | price ',
              price, ' BNB / ', price * BNB_USD, 'USD'
          );
          if (event = findEvent(transaction, 'FeesChanged')) {
            console.log('  - FeesChanged',
              'Buy: ', event.args.feeToBuy.toNumber(),
              ' / Sell', event.args.feeToSell.toNumber(),
              ' / Rewards', event.args.feeRewards.toNumber(),
              ' / Project', event.args.feeProject.toNumber(),
              ' / Liquidity', event.args.feeLiquidity.toNumber(),
              ' / swapAt', fromWei(event.args.swapAt) * 1.0
            );
          }
          logPriceRewardsEvent(transaction);
        }

        if (event = findEvent(transaction, 'FundsSentToProject')) {
          let bnb = event.args.value / toWei(1);
          console.log('  - Verify ', bnb, 'BNB from swap went to project');
          project_funds += bnb;
          let diff = fromWei(await web3.eth.getBalance(addresses.project)) - project_balance;
          console.log('  - Project wallet now funds at', project_funds, 'diff', diff);
          logPriceProjectEvent(transaction);
        }

        if (event = findEvent(transaction, 'FundsSentToLiquidity')) {
          let bnb = event.args.value / toWei(1);
          console.log('  - Verify ', bnb, 'BNB from swap went to liquidity');
          console.log('  - contract liquidity increased to ', fromWei(await contract.balanceOfLiquidity()));
          logPriceLiquidityEvent(transaction);
        }
      }
    }
    console.log('Sold', sold.toLocaleString(), 'tokens');
    console.log('Contract Liquidity', fromWei(await contract.balanceOfLiquidity()));
    distros = fromWei((await contract.getRewardsReport()).totalRewardsPaid);
    console.log('Rewards Distributed $', distros * BNB_USD);
    let diff = fromWei(await web3.eth.getBalance(addresses.project)) - project_balance;
    console.log('Project Funds from sells $', diff * BNB_USD);
  });
});
