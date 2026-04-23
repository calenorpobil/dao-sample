// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MinimalForwarder.sol";
import "../src/DAOVoting.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        MinimalForwarder forwarder = new MinimalForwarder();
        DAOVoting dao = new DAOVoting(address(forwarder));

        vm.stopBroadcast();

        console.log("MinimalForwarder deployed at:", address(forwarder));
        console.log("DAOVoting deployed at:", address(dao));
    }
}
