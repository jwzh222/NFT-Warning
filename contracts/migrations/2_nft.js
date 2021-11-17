
const Nft = artifacts.require("YangNFT");

module.exports = function (deployer) {
  deployer.deploy(Nft);
};
