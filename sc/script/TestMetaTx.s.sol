// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MinimalForwarder.sol";
import "../src/DAOVoting.sol";

contract TestMetaTx is Script {
    function run() external {
        address forwarderAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        address daoAddr = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        uint256 userKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        address user = vm.addr(userKey);

        MinimalForwarder forwarder = MinimalForwarder(forwarderAddr);
        DAOVoting dao = DAOVoting(payable(daoAddr));

        console.log("User:", user);
        console.log("User balance in DAO:", dao.getUserBalance(user));
        console.log("Total deposited:", dao.totalDeposited());
        console.log("Forwarder nonce:", forwarder.getNonce(user));
        console.log("proposalCount before:", dao.proposalCount());

        bytes memory data = abi.encodeWithSelector(
            dao.createProposal.selector,
            user,
            0.01 ether,
            7 days,
            "TestMetaTx proposal"
        );

        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: user,
            to: daoAddr,
            value: 0,
            gas: 500000,
            nonce: forwarder.getNonce(user),
            data: data
        });

        bytes32 digest = forwarder.getTypedDataHash(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bool valid = forwarder.verify(req, sig);
        console.log("Signature valid:", valid);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        (bool success, bytes memory result) = forwarder.execute(req, sig);
        vm.stopBroadcast();

        console.log("Execute success:", success);
        if (!success && result.length > 0) {
            console.log("Revert data length:", result.length);
        }
        console.log("proposalCount after:", dao.proposalCount());
    }
}
