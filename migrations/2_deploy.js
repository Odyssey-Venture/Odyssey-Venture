const OdysseyRewards = artifacts.require("./OdysseyRewards.sol");
const Odyssey = artifacts.require("./Odyssey.sol");
const IterableMapping = artifacts.require("./IterableMapping.sol");

module.exports = function (deployer) {
  deployer.deploy(IterableMapping);
  deployer.link(IterableMapping, OdysseyRewards);
  deployer.deploy(OdysseyRewards);
  deployer.link(IterableMapping, Odyssey);
  deployer.deploy(Odyssey);
};
