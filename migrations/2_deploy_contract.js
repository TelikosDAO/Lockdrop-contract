const Lockdrop = artifacts.require("Lockdrop.sol");

module.exports = function (deployer) {
    deployer.deploy(Lockdrop, 1604199600);
  };
  