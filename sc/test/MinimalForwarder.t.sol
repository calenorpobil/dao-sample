// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MinimalForwarder.sol";
import "../src/DAOVoting.sol";

contract MinimalForwarderTest is Test {
    MinimalForwarder public forwarder;
    DAOVoting public dao;

    uint256 constant SIGNER_KEY = 0xabc123;
    address signer;

    function setUp() public {
        forwarder = new MinimalForwarder();
        dao = new DAOVoting(address(forwarder));
        signer = vm.addr(SIGNER_KEY);
        vm.deal(signer, 10 ether);
    }

    function _buildRequest(
        address from,
        address to,
        uint256 nonce,
        bytes memory data
    ) internal pure returns (MinimalForwarder.ForwardRequest memory) {
        return MinimalForwarder.ForwardRequest({
            from: from,
            to: to,
            value: 0,
            gas: 300_000,
            nonce: nonce,
            data: data
        });
    }

    function _sign(MinimalForwarder.ForwardRequest memory req, uint256 key)
        internal view returns (bytes memory)
    {
        bytes32 digest = forwarder.getTypedDataHash(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    // --- getNonce ---

    function test_initial_nonce_is_zero() public view {
        assertEq(forwarder.getNonce(signer), 0);
    }

    function test_nonce_independent_per_user() public {
        address other = makeAddr("other");
        assertEq(forwarder.getNonce(signer), 0);
        assertEq(forwarder.getNonce(other), 0);
    }

    // --- verify ---

    function test_verify_valid_signature() public {
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, "");
        bytes memory sig = _sign(req, SIGNER_KEY);
        assertTrue(forwarder.verify(req, sig));
    }

    function test_verify_wrong_nonce() public {
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 99, "");
        bytes memory sig = _sign(req, SIGNER_KEY);
        assertFalse(forwarder.verify(req, sig));
    }

    function test_verify_wrong_signer() public {
        uint256 eveKey = 0xdead;
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, "");
        bytes memory sig = _sign(req, eveKey);
        assertFalse(forwarder.verify(req, sig));
    }

    function test_verify_tampered_data() public {
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, "");
        bytes memory sig = _sign(req, SIGNER_KEY);

        // Change data after signing
        req.data = abi.encode("tampered");
        assertFalse(forwarder.verify(req, sig));
    }

    // --- execute ---

    function test_nonce_increments_after_execute() public {
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, "");
        bytes memory sig = _sign(req, SIGNER_KEY);

        assertEq(forwarder.getNonce(signer), 0);
        forwarder.execute(req, sig);
        assertEq(forwarder.getNonce(signer), 1);
    }

    function test_execute_reverts_invalid_signature() public {
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, "");
        bytes memory badSig = new bytes(65);

        vm.expectRevert("MinimalForwarder: invalid signature");
        forwarder.execute(req, badSig);
    }

    function test_execute_reverts_on_replay() public {
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, "");
        bytes memory sig = _sign(req, SIGNER_KEY);

        forwarder.execute(req, sig);

        vm.expectRevert("MinimalForwarder: invalid signature");
        forwarder.execute(req, sig);
    }

    function test_execute_second_tx_uses_nonce_1() public {
        bytes memory sig0 = _sign(_buildRequest(signer, address(dao), 0, ""), SIGNER_KEY);
        forwarder.execute(_buildRequest(signer, address(dao), 0, ""), sig0);

        MinimalForwarder.ForwardRequest memory req1 = _buildRequest(signer, address(dao), 1, "");
        bytes memory sig1 = _sign(req1, SIGNER_KEY);
        forwarder.execute(req1, sig1);

        assertEq(forwarder.getNonce(signer), 2);
    }

    // --- gasless DAO integration ---

    function test_gasless_vote_for() public {
        address proposer = makeAddr("proposer");
        vm.deal(proposer, 10 ether);

        vm.prank(signer);
        dao.deposit{value: 5 ether}();
        vm.prank(proposer);
        dao.deposit{value: 5 ether}();
        vm.prank(proposer);
        uint256 proposalId = dao.createProposal(makeAddr("recipient"), 1 ether, 7 days, "gasless vote");

        bytes memory data = abi.encodeCall(dao.vote, (proposalId, DAOVoting.VoteType.FOR));
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, data);
        bytes memory sig = _sign(req, SIGNER_KEY);

        forwarder.execute(req, sig);

        DAOVoting.Proposal memory p = dao.getProposal(proposalId);
        assertEq(p.forVotes, 1);
        assertTrue(dao.hasVoted(proposalId, signer));
        assertEq(forwarder.getNonce(signer), 1);
    }

    function test_gasless_vote_msgSender_is_signer_not_relayer() public {
        address proposer = makeAddr("proposer");
        vm.deal(proposer, 10 ether);

        vm.prank(signer);
        dao.deposit{value: 5 ether}();
        vm.prank(proposer);
        dao.deposit{value: 5 ether}();
        vm.prank(proposer);
        uint256 proposalId = dao.createProposal(makeAddr("recipient"), 1 ether, 7 days, "sender test");

        bytes memory data = abi.encodeCall(dao.vote, (proposalId, DAOVoting.VoteType.FOR));
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, data);
        bytes memory sig = _sign(req, SIGNER_KEY);

        // relayer (this contract) pays gas, but the DAO should see signer as voter
        forwarder.execute(req, sig);

        assertTrue(dao.hasVoted(proposalId, signer));
        assertFalse(dao.hasVoted(proposalId, address(this)));
    }

    function test_gasless_vote_against() public {
        address proposer = makeAddr("proposer");
        vm.deal(proposer, 10 ether);

        vm.prank(signer);
        dao.deposit{value: 5 ether}();
        vm.prank(proposer);
        dao.deposit{value: 5 ether}();
        vm.prank(proposer);
        uint256 proposalId = dao.createProposal(makeAddr("recipient"), 1 ether, 7 days, "against test");

        bytes memory data = abi.encodeCall(dao.vote, (proposalId, DAOVoting.VoteType.AGAINST));
        MinimalForwarder.ForwardRequest memory req = _buildRequest(signer, address(dao), 0, data);
        forwarder.execute(req, _sign(req, SIGNER_KEY));

        DAOVoting.Proposal memory p = dao.getProposal(proposalId);
        assertEq(p.againstVotes, 1);
        assertEq(p.forVotes, 0);
    }
}
