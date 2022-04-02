const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LayerZero Concept", function () {
  beforeEach(async function () {
    // use this chainId
    this.masterChainId = 123;
    this.satelliteChain1Id = 1001;
    this.satelliteChain2Id = 1002;

    const LayerZeroEndpointMock = await ethers.getContractFactory(
      "LZEndpointMock"
    );
    this.lzEndpointMockMaster = await LayerZeroEndpointMock.deploy(
      this.masterChainId
    );
    this.lzEndpointMockSatellite1 = await LayerZeroEndpointMock.deploy(
      this.satelliteChain1Id
    );
    this.lzEndpointMockSatellite2 = await LayerZeroEndpointMock.deploy(
      this.satelliteChain2Id
    );

    const MasterChain = await ethers.getContractFactory("MasterChain");
    this.masterChain = await MasterChain.deploy(
      this.lzEndpointMockMaster.address
    );

    const SatelliteChain = await ethers.getContractFactory("SatelliteChain");
    this.satelliteChain1 = await SatelliteChain.deploy(
      this.lzEndpointMockSatellite1.address
    );

    this.satelliteChain2 = await SatelliteChain.deploy(
      this.lzEndpointMockSatellite2.address
    );

    this.lzEndpointMockMaster.setDestLzEndpoint(
      this.masterChain.address,
      this.lzEndpointMockMaster.address
    );

    this.lzEndpointMockMaster.setDestLzEndpoint(
      this.satelliteChain1.address,
      this.lzEndpointMockSatellite1.address
    );

    this.lzEndpointMockMaster.setDestLzEndpoint(
      this.satelliteChain2.address,
      this.lzEndpointMockSatellite2.address
    );

    this.lzEndpointMockSatellite1.setDestLzEndpoint(
      this.satelliteChain1.address,
      this.lzEndpointMockSatellite1.address
    );

    this.lzEndpointMockSatellite1.setDestLzEndpoint(
      this.masterChain.address,
      this.lzEndpointMockMaster.address
    );

    this.lzEndpointMockSatellite2.setDestLzEndpoint(
      this.satelliteChain2.address,
      this.lzEndpointMockSatellite2.address
    );

    this.lzEndpointMockSatellite2.setDestLzEndpoint(
      this.masterChain.address,
      this.lzEndpointMockMaster.address
    );

    // set each contracts remote address so it can send to each other
    this.masterChain.setRemote(
      this.satelliteChain1Id,
      this.satelliteChain1.address
    );
    this.masterChain.setRemote(
      this.satelliteChain2Id,
      this.satelliteChain2.address
    );
    this.satelliteChain1.setRemote(
      this.masterChainId,
      this.masterChain.address
    );
    this.satelliteChain2.setRemote(
      this.masterChainId,
      this.masterChain.address
    );
  });

  it("modify the counter of the destination SatelliteChain", async function () {
    expect(await this.satelliteChain1.getCounter()).to.be.equal(0);
    expect(await this.satelliteChain2.getCounter()).to.be.equal(0);

    await this.masterChain.updateCounter(
      this.satelliteChain1Id,
      this.satelliteChain1.address,
      10,
      "ADD"
    );
    await this.masterChain.updateCounter(
      this.satelliteChain2Id,
      this.satelliteChain2.address,
      5,
      "SUB"
    );

    expect(await this.satelliteChain1.getCounter()).to.be.equal(10);
    expect(await this.satelliteChain2.getCounter()).to.be.equal(0);

    await this.masterChain.updateCounter(
      this.satelliteChain1Id,
      this.satelliteChain1.address,
      5,
      "MUL"
    );
    await this.masterChain.updateCounter(
      this.satelliteChain2Id,
      this.satelliteChain2.address,
      10,
      "ADD"
    );

    expect(await this.satelliteChain1.getCounter()).to.be.equal(50);
    expect(await this.satelliteChain2.getCounter()).to.be.equal(10);
  });
});
