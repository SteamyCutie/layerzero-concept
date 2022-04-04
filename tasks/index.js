task("masterChainSetRemote", "setRemote(chainId, remoteAddr) to allow the local contract to receive messages from known remote contracts",
  require("./masterChainSetRemote"))
  .addParam("targetNetwork", "the target network to let this instance receive messages from")

task("satelliteChainSetRemote", "setRemote(chainId, remoteAddr) to allow the local contract to receive messages from known remote contracts",
  require("./satelliteChainSetRemote"))
  .addParam("targetNetwork", "the target network to let this instance receive messages from")

task("masterChainUpdateCounter", "update the destination SatelliteCounter",
  require("./masterChainUpdateCounter"))
  .addParam("targetNetwork", "the target network name, ie: fuji, or mumbai, etc (from hardhat.config.js)")
  .addParam("amount", "amount to update", 1, types.int)
  .addParam("method", "ADD, SUB or MUL", "ADD", types.string)

task("satelliteChainRequestCounter", "update the destination SatelliteCounter",
  require("./satelliteChainRequestCounter"))
  .addParam("targetNetwork", "the target network name, ie: fuji, or mumbai, etc (from hardhat.config.js)")

task("satelliteChainPoll", "Poll the Counter of the SatelliteChain",
  require("./satelliteChainPoll"))
  .addParam("targetNetwork", "the target network name, ie: fuji, or mumbai, etc (from hardhat.config.js)")