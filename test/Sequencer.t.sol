// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.14;

import "forge-std/Test.sol";
import "../src/Sequencer.sol";

contract SequencerTest is Test {
    Sequencer sequencer;

    bytes32 stateRootChainEthBlock0 = 0xd7f8974fb5ac78d9ac099b9ad5018bedc2ce0a72dad1827a1709da30580f0544;
    bytes32 stateRootChainEthBlock19000000 = 0xd7f8974fb5ac78d9ac099b9ad5018bedc2ce0a72dad1827a1709da30580f0544;

    // optimism
    bytes32 stateRootChainOpBlock0 = 0xeddb4c1786789419153a27c4c80ff44a2226b6eda04f7e22ce5bae892ea568eb;
    bytes32 stateRootChainOpBlock119800000 = 0xe5fec5ae8d8f9986f63f925251b32b34c0789082c8d5f6e5a763682f73bdbae2;

    // reth node --dev --datadir rethdb
    // cast block 0 | grep stateRoot
    bytes32 stateRootChainRethDevBlock0 = 0xf09d8f7da5bc5036f8dd9536c953e2212390a46fb3e553ece2b7d419131537b1;

    // state after 1 value transfer block:
    // priv key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 is 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    // cast send --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 --value 255  
    // cast block 1 | grep stateRoot
    bytes32 stateRootChainRethDevBlock1 = 0x1617afe2025b993af20a9705bc6a92fbd5a8c9640fd03900842e76860588eb0f;

    uint256 channelId_Eth0;
    uint256 channelId_Eth1;
    uint256 channelId_Op0;
    uint256 channelId_Op1;
    uint256 channelId_Reth0;
    uint256 channelId_Reth1;

    function setUp() external {
        sequencer = new Sequencer();

        // vm.prank(makeAddr("ethereum_0"));
        // channelId_Eth0 = sequencer.createChannel(1, stateRootChainEthBlock0);

        // vm.prank(makeAddr("ethereum_19000000"));
        // channelId_Eth1 = sequencer.createChannel(1, stateRootChainEthBlock19000000);

        // vm.prank(makeAddr("optimism_0"));
        // channelId_Op0 = sequencer.createChannel(10, stateRootChainOpBlock0);

        // vm.prank(makeAddr("optimism_119800000"));
        // channelId_Op1 = sequencer.createChannel(10, stateRootChainOpBlock119800000);

        vm.prank(makeAddr("rethdev_0"));
        channelId_Reth0 = sequencer.createChannel(1337, stateRootChainRethDevBlock0);
    }

    function _sendTx(
        uint256 channelId,
        string memory from,
        address to
    ) internal returns (address) {
        (address addr, uint256 pk) = makeAddrAndKey(from);
        bytes32 hash = keccak256(abi.encodePacked(
            channelId,
            uint256(1),
            to,
            uint256(0), // amount
            uint256(0) // fee
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);

        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            // NOTE: the above condition does not seem to ever be true for vm.sign (hence this block is untested)
            // perhaps the library ensuring this?
            console2.log("large s used");
            s = bytes32(
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0 -
                    uint256(s)
            );
            v ^= 1;
        }

        address signer = ecrecover(hash, v, r, s);
        require(signer == addr, "signing issue?");

        bytes32 vs = bytes32(uint256(s) | ((uint256(v ^ 1) & 1) << 255));

        Transaction memory txn = Transaction({
            channelId: channelId,
            nonce: 1,
            to: to,
            amount: 0,
            fee: 0,
            signature: [r, vs]
        });

        sequencer.sendTx(txn);

        return addr;
    }

    function test_Sequencer() public {
        address signer = _sendTx(channelId_Eth0, "rethdev_0", address(0x123));

        vm.prank(signer);
        // idk, whatever. just set bullshit state root
        sequencer.roll(channelId_Eth0, bytes32(uint256(0xabcd)));
    }

    function test_RollNotSequencer() public {
        vm.prank(makeAddr("NotSequencer"));
        try sequencer.roll(channelId_Eth0, bytes32(uint256(0xabcd))) {
            revert("roll() called should have failed because not sequencer");
        } catch Error(string memory reason) {
            assertEq(reason, "only channel controller");
        }
    }

    function test_RollNoSuchChannel() public {
        uint256 channelIdNoChain = uint256(uint160(address(this))) << 96;
        try sequencer.roll(channelIdNoChain, bytes32(uint256(0xabcd))) {
            revert("roll() called should have failed because no such channel");
        } catch Error(string memory reason) {
            assertEq(reason, "no such channel");
        }
    }
}
