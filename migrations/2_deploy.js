const ODSYDividendTracker = artifacts.require("./ODSYDividendTracker.sol");
const Odyssey = artifacts.require("./Odyssey.sol");
const IterableMapping = artifacts.require("./IterableMapping.sol");

module.exports = function (deployer) {
  deployer.deploy(ODSYDividendTracker);
  deployer.deploy(IterableMapping);
  deployer.link(IterableMapping, Odyssey);
  deployer.deploy(Odyssey);
};


// const ODSYDividendTracker = artifacts.require("./ODSYDividendTracker.sol");
// const IterableMapping = artifacts.require("./IterableMapping.sol");
// const Odyssey = artifacts.require("./Odyssey.sol");

// module.exports = function (deployer) {
//   deployer.deploy(IterableMapping);
//   deployer.link(IterableMapping, ODSYDividendTracker);
//   deployer.deploy(ODSYDividendTracker);
//   deployer.link(ODSYDividendTracker, Odyssey);
//   deployer.deploy(Odyssey);
// };
