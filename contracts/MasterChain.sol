// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./interfaces/ILayerZeroUserApplicationConfig.sol";
import "./interfaces/IPOCDeployment.sol";

contract MasterChain is
    Ownable,
    ILayerZeroReceiver,
    ILayerZeroUserApplicationConfig,
    IPOCDeployment
{
    ILayerZeroEndpoint public endpoint;
    mapping(uint16 => bytes) public remotes;
    mapping(uint16 => int256) public counters;

    constructor(address _endpoint) {
        endpoint = ILayerZeroEndpoint(_endpoint);
    }

    function updateCounter(
        uint16 _chainId,
        bytes memory _dstAddress,
        int256 _amount,
        string memory _method
    ) external payable override {
        int256 amount;
        bytes memory method = bytes(_method);
        bytes memory expectAdd = bytes("ADD");
        bytes memory expectSub = bytes("SUB");
        bytes memory expectMul = bytes("MUL");
        if (
            method.length == expectAdd.length &&
            keccak256(method) == keccak256(expectAdd)
        ) amount = counters[_chainId] + _amount;
        else if (
            method.length == expectSub.length &&
            keccak256(method) == keccak256(expectSub)
        ) amount = counters[_chainId] - _amount;
        else if (
            method.length == expectMul.length &&
            keccak256(method) == keccak256(expectMul)
        ) amount = counters[_chainId] * _amount;
        else amount = counters[_chainId];

        bytes memory _params = abi.encode("SET", _chainId, amount);
        endpoint.send{value: msg.value}(
            _chainId,
            _dstAddress,
            _params,
            payable(msg.sender),
            address(0x0),
            bytes("")
        );
    }

    function sendCounter(
        uint16 _dstChainId,
        bytes memory _dstAddress,
        uint16 _srcChainId
    ) public payable override {
        bytes memory _params = abi.encode(
            "SET",
            _srcChainId,
            counters[_srcChainId]
        );
        endpoint.send{value: msg.value}(
            _dstChainId,
            _dstAddress,
            _params,
            payable(msg.sender),
            address(0x0),
            bytes("")
        );
    }

    // overrides lzReceive function in ILayerZeroReceiver.
    // automatically invoked on the receiving chain after the source chain calls endpoint.send(...)
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) external override {
        require(msg.sender == address(endpoint));
        require(
            _srcAddress.length == remotes[_srcChainId].length &&
                keccak256(_srcAddress) == keccak256(remotes[_srcChainId]),
            "Invalid remote sender address. owner should call setRemote() to enable remote contract"
        );
        string memory method;
        uint16 chainId;
        bytes memory dstAddress;
        int256 amount;
        (method, chainId, dstAddress, amount) = abi.decode(
            _payload,
            (string, uint16, bytes, int256)
        );

        if (keccak256(bytes(method)) == keccak256(bytes("SET"))) {
            counters[_srcChainId] = amount;
        } else {
            sendCounter(_srcChainId, _srcAddress, chainId);
        }
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
        uint256 typeOracle = 6; // from UltraLightNode
        // set the Oracle
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            dstChainId,
            typeOracle,
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
        counters[_chainId] = 0;
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
