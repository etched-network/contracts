// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

contract CounterScript is Script {
    function setUp() public {
        // vm.startBroadcast(vm.envUint`("PRIVATE_KEY"));
        uint256 privKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privKey);
        vm.deploy("Sequencer", "src/Sequencer.sol");
        vm.commit();
    }

    function run() public {
        vm.broadcast();
    }
}
