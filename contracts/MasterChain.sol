// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./interfaces/ILayerZeroUserApplicationConfig.sol";
import "./interfaces/IPOCDeployment.sol";

import "hardhat/console.sol";

contract MasterChain is
    Ownable,
    ILayerZeroReceiver,
    ILayerZeroUserApplicationConfig,
    IPOCDeployment
{
    using SafeMath for uint256;
    // required: the LayerZero endpoint which is passed in the constructor
    ILayerZeroEndpoint public endpoint;
    mapping(uint16 => bytes) public remotes;
    mapping(uint16 => uint256) public counters;

    constructor(address _endpoint) {
        endpoint = ILayerZeroEndpoint(_endpoint);
    }

    function updateCounter(
        uint16 _chainId,
        bytes memory _dstAddress,
        uint256 _amount,
        string memory _method
    ) external payable override {
        uint256 amount;
        bytes memory method = bytes(_method);
        bytes memory expectAdd = bytes("ADD");
        bytes memory expectSub = bytes("SUB");
        if (
            method.length == expectAdd.length &&
            keccak256(method) == keccak256(expectAdd)
        ) amount = counters[_chainId].add(_amount);
        else if (
            method.length == expectSub.length &&
            keccak256(method) == keccak256(expectSub) &&
            counters[_chainId] >= _amount
        ) amount = counters[_chainId].sub(_amount);
        else amount = counters[_chainId].mul(_amount);
        endpoint.send{value: msg.value}(
            _chainId,
            _dstAddress,
            abi.encodePacked(amount),
            payable(msg.sender),
            address(0x0),
            bytes("")
        );
    }

    function requestCounter(uint16 _chainId, bytes memory _dstAddress)
        external
        payable
        override
    {
        endpoint.send{value: msg.value}(
            _chainId,
            _dstAddress,
            bytes(""),
            payable(msg.sender),
            address(0x0),
            bytes("COUNTER")
        );
    }

    function toUint256(bytes memory _bytes) internal pure returns (uint256) {
        require(_bytes.length >= 32, "toUint256_outOfBounds");
        uint256 tempUint;
        assembly {
            tempUint := mload(add(_bytes, 0x20))
        }
        return tempUint;
    }

    // overrides lzReceive function in ILayerZeroReceiver.
    // automatically invoked on the receiving chain after the source chain calls endpoint.send(...)
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) external override {
        // boilerplate: only allow this endpoint to be the caller of lzReceive!
        require(msg.sender == address(endpoint));
        // owner must have setRemote() to allow its remote contracts to send to this contract
        require(
            _srcAddress.length == remotes[_srcChainId].length &&
                keccak256(_srcAddress) == keccak256(remotes[_srcChainId]),
            "Invalid remote sender address. owner should call setRemote() to enable remote contract"
        );
        counters[_srcChainId] = toUint256(_payload);
    }

    // _adapterParams (v2)
    // specify a small amount of notive token you want to airdropped to your wallet on destination
    function incrementCounterWithAdapterParamsV2(
        uint16 _dstChainId,
        bytes calldata _dstCounterMockAddress,
        uint256 gasAmountForDst,
        uint256 airdropEthQty,
        address airdropAddr
    ) public payable {
        uint16 version = 2;
        bytes memory _adapterParams = abi.encodePacked(
            version,
            gasAmountForDst,
            airdropEthQty, // how must dust to receive on destination
            airdropAddr // the address to receive the dust
        );
        endpoint.send{value: msg.value}(
            _dstChainId,
            _dstCounterMockAddress,
            bytes(""),
            payable(msg.sender),
            address(0x0),
            _adapterParams
        );
    }

    // call send() to multiple destinations in the same transaction!
    function incrementMultiCounter(
        uint16[] calldata _dstChainIds,
        bytes[] calldata _dstCounterMockAddresses,
        address payable _refundAddr
    ) public payable {
        require(
            _dstChainIds.length == _dstCounterMockAddresses.length,
            "_dstChainIds.length, _dstCounterMockAddresses.length not the same"
        );

        uint256 numberOfChains = _dstChainIds.length;

        // note: could result in a few wei of dust left in contract
        uint256 valueToSend = msg.value.div(numberOfChains);

        // send() each chainId + dst address pair
        for (uint256 i = 0; i < numberOfChains; ++i) {
            // a Communicator.sol instance is the 'endpoint'
            // .send() each payload to the destination chainId + UA destination address
            endpoint.send{value: valueToSend}(
                _dstChainIds[i],
                _dstCounterMockAddresses[i],
                bytes(""),
                _refundAddr,
                address(0x0),
                bytes("")
            );
        }

        // refund eth if too much was sent into this contract call
        uint256 refund = msg.value.sub(valueToSend.mul(numberOfChains));
        _refundAddr.transfer(refund);
    }

    function setConfig(
        uint16, /*_version*/
        uint16 _chainId,
        uint256 _configType,
        bytes calldata _config
    ) external override {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            _chainId,
            _configType,
            _config
        );
    }

    function getConfig(
        uint16, /*_dstChainId*/
        uint16 _chainId,
        address,
        uint256 _configType
    ) external view returns (bytes memory) {
        return
            endpoint.getConfig(
                endpoint.getSendVersion(address(this)),
                _chainId,
                address(this),
                _configType
            );
    }

    function setSendVersion(uint16 version) external override {
        endpoint.setSendVersion(version);
    }

    function setReceiveVersion(uint16 version) external override {
        endpoint.setReceiveVersion(version);
    }

    function getSendVersion() external view returns (uint16) {
        return endpoint.getSendVersion(address(this));
    }

    function getReceiveVersion() external view returns (uint16) {
        return endpoint.getReceiveVersion(address(this));
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress)
        external
        override
    {
        //
    }

    // set the Oracle to be used by this UA for LayerZero messages
    function setOracle(uint16 dstChainId, address oracle) external {
        uint256 TYPE_ORACLE = 6; // from UltraLightNode
        // set the Oracle
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            dstChainId,
            TYPE_ORACLE,
            abi.encode(oracle)
        );
    }

    // _chainId - the chainId for the remote contract
    // _remoteAddress - the contract address on the remote chainId
    // the owner must set remote contract addresses.
    // in lzReceive(), a require() ensures only messages
    // from known contracts can be received.
    function setRemote(uint16 _chainId, bytes calldata _remoteAddress)
        external
        onlyOwner
    {
        require(
            remotes[_chainId].length == 0,
            "The remote address has already been set for the chainId!"
        );
        remotes[_chainId] = _remoteAddress;
    }

    // set the inbound block confirmations
    function setInboundConfirmations(uint16 remoteChainId, uint16 confirmations)
        external
    {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            remoteChainId,
            2, // CONFIG_TYPE_INBOUND_BLOCK_CONFIRMATIONS
            abi.encode(confirmations)
        );
    }

    // set outbound block confirmations
    function setOutboundConfirmations(
        uint16 remoteChainId,
        uint16 confirmations
    ) external {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            remoteChainId,
            5, // CONFIG_TYPE_OUTBOUND_BLOCK_CONFIRMATIONS
            abi.encode(confirmations)
        );
    }

    // allow this contract to receive ether
    fallback() external payable {}

    receive() external payable {}
}
