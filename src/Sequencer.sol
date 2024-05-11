// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.14;

// sendTx could just accept arbitrary bytes, even without additional param for signature - just encode it however in the bytes
struct Transaction {
    // instead of chainId, this is abi.encodePacked(address(controller), uint96(channelId))
    uint256 channelId;
    uint256 nonce;
    address to;
    uint256 amount;
    uint256 fee;
    bytes32[2] signature; // r, vs
}

enum TxStatus {
    None,
    Pending,
    Confirmed,
    Reverted,
    Invalid // rejected because of nonce, lack of gas, etc.?
}

struct TransactionReceipt {
    TxStatus status;
}

struct Channel {
    bytes32 stateRoot;
    // there are no blocks, just count transactions
    uint256 txHeight;
    Transaction[] transactions;
}

// solidity doesn't pack this shit. primitive language, fr, fr...
// struct ChannelId {
//     address controller;
//     uint96 channelId;
// }

contract Sequencer {
    mapping (uint256 channelId => Channel) public channels;
    mapping (uint256 txHash => TransactionReceipt) public receipts;

    event ChannelCreated(address indexed controller, uint96 chainId);

    constructor() {

    }
    
    function getChannelId(uint96 chainId, address controller) public pure returns (uint256 channelId) {
        return (uint256(uint160(controller)) << 96) | uint256(chainId);
    }

    function getChannelTransactionCount(uint256 channelId) public view returns (uint256) {
        return channels[channelId].transactions.length;
    }

    function createChannel(uint96 chainId, bytes32 stateRoot) public returns (uint256 channelId) {
        require(stateRoot != 0, "state root cannot be zero");
        channelId = getChannelId(chainId, msg.sender);
        Channel storage channel = channels[channelId];
        require(channel.stateRoot == bytes32(0), "channel already exists");
        channel.stateRoot = stateRoot;
        emit ChannelCreated(msg.sender, chainId);
    }

    function sendTx(Transaction calldata txn) public payable {
        require(msg.value >= txn.amount + txn.fee, "insufficient funds");
        
        Channel storage channel = channels[txn.channelId];
        channel.transactions.push(txn);
    }

    function roll(uint256 channelId, bytes32 stateRoot) public payable {
        // perhaps instead of stateRoot you just have arbitrary bytes
        // and a callback to the channel controller which is responsible for responses
        // uint256 channelId = getChannelId(chainId, msg.sender);
        require(channelId >> 96 == uint160(msg.sender), "only channel controller");
        Channel storage channel = channels[channelId];
        require(channel.stateRoot != bytes32(0), "no such channel");
        channel.stateRoot = stateRoot;
    }
}
