const { getDeploymentAddresses } = require('../utils/readStatic')
const CHAIN_ID = require('../constants/chainIds.json')

module.exports = async function (taskArgs, hre) {
  const dstChainId = CHAIN_ID[taskArgs.targetNetwork]
  console.log(`
        [destination]: ${getDeploymentAddresses(taskArgs.targetNetwork)["SatelliteChain"]}, 
        [amount]: ${taskArgs.amount}, 
        [method]: ${taskArgs.method}
    `)
  const dstAddr = getDeploymentAddresses(taskArgs.targetNetwork)["SatelliteChain"]
  const masterChain = await ethers.getContract("MasterChain")

  let tx = await (await masterChain.updateCounter(
    dstChainId,
    dstAddr,
    taskArgs.amount,
    taskArgs.method,
    { value: ethers.utils.parseEther('0.001') } // estimate/guess
  )).wait()
  console.log(`✅ Message Sent [${hre.network.name}] MasterChain updateCounter on destination SatelliteChain @ [${dstChainId}] [${dstAddr}]`)
  console.log(`tx: ${tx.transactionHash}`)

  console.log(``)
  console.log(`Note: to poll/wait for the message to arrive on the destination use the command:`)
  console.log('')
  console.log(`    $ npx hardhat --network ${taskArgs.targetNetwork} satelliteChainPoll --target-network ${taskArgs.targetNetwork}`)
}