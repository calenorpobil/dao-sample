// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DAOVoting.sol";
import "../src/MinimalForwarder.sol";

contract DAOVotingTest is Test {
    DAOVoting public dao;
    MinimalForwarder public forwarder;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address recipient = makeAddr("recipient");

    uint256 constant DEPOSIT = 1 ether;
    uint256 constant VOTING_DURATION = 7 days;

    function setUp() public {
        forwarder = new MinimalForwarder();
        dao = new DAOVoting(address(forwarder));

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
    }

    // --- deposit ---

    function test_deposit() public {
        vm.prank(alice);
        dao.deposit{value: DEPOSIT}();

        assertEq(dao.balances(alice), DEPOSIT);
        assertEq(dao.totalDeposited(), DEPOSIT);
    }

    function test_deposit_revert_zero() public {
        vm.prank(alice);
        vm.expectRevert("DAOVoting: must send ETH");
        dao.deposit{value: 0}();
    }

    function test_deposit_via_receive() public {
        vm.prank(alice);
        (bool ok,) = address(dao).call{value: DEPOSIT}("");
        assertTrue(ok);
        assertEq(dao.balances(alice), DEPOSIT);
    }

    // --- withdraw ---

    function test_withdraw() public {
        vm.startPrank(alice);
        dao.deposit{value: DEPOSIT}();
        uint256 balanceBefore = alice.balance;
        dao.withdraw(DEPOSIT);
        vm.stopPrank();

        assertEq(dao.balances(alice), 0);
        assertEq(alice.balance, balanceBefore + DEPOSIT);
    }

    function test_withdraw_revert_insufficient() public {
        vm.prank(alice);
        vm.expectRevert("DAOVoting: insufficient balance");
        dao.withdraw(1 ether);
    }

    // --- createProposal ---

    function _setupDeposits() internal {
        vm.prank(alice);
        dao.deposit{value: 5 ether}();
        vm.prank(bob);
        dao.deposit{value: 3 ether}();
        vm.prank(carol);
        dao.deposit{value: 2 ether}();
    }

    function test_createProposal() public {
        _setupDeposits();

        vm.prank(alice);
        uint256 id = dao.createProposal(recipient, 1 ether, VOTING_DURATION, "Send 1 ETH to recipient");

        assertEq(id, 1);
        DAOVoting.Proposal memory p = dao.getProposal(1);
        assertEq(p.recipient, recipient);
        assertEq(p.amount, 1 ether);
        assertEq(p.description, "Send 1 ETH to recipient");
    }

    function test_createProposal_revert_threshold() public {
        vm.prank(alice);
        dao.deposit{value: 0.1 ether}();

        vm.prank(bob);
        dao.deposit{value: 10 ether}();

        vm.prank(alice);
        vm.expectRevert("DAOVoting: insufficient balance to propose");
        dao.createProposal(recipient, 0.1 ether, VOTING_DURATION, "test");
    }

    // --- vote ---

    function test_vote_for() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        DAOVoting.Proposal memory p = dao.getProposal(1);
        assertEq(p.forVotes, 1);
        assertTrue(dao.hasVoted(1, alice));
    }

    function test_vote_revert_double_vote() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.startPrank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        vm.expectRevert("DAOVoting: already voted");
        dao.vote(1, DAOVoting.VoteType.AGAINST);
        vm.stopPrank();
    }

    function test_vote_revert_after_deadline() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        vm.prank(alice);
        vm.expectRevert("DAOVoting: voting period ended");
        dao.vote(1, DAOVoting.VoteType.FOR);
    }

    function test_vote_revert_no_balance() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        address nobody = makeAddr("nobody");
        vm.prank(nobody);
        vm.expectRevert("DAOVoting: insufficient balance to vote");
        dao.vote(1, DAOVoting.VoteType.FOR);
    }

    // --- executeProposal ---

    function test_executeProposal() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        vm.prank(bob);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);

        uint256 recipientBalanceBefore = recipient.balance;
        dao.executeProposal(1);

        DAOVoting.Proposal memory p = dao.getProposal(1);
        assertTrue(p.executed);
        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
    }

    function test_executeProposal_revert_not_approved() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.AGAINST);

        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);

        vm.expectRevert("DAOVoting: proposal not approved");
        dao.executeProposal(1);
    }

    function test_executeProposal_revert_delay_not_elapsed() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(block.timestamp + VOTING_DURATION + 1);

        vm.expectRevert("DAOVoting: execution delay not elapsed");
        dao.executeProposal(1);
    }

    function test_executeProposal_revert_double_execution() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);
        dao.executeProposal(1);

        vm.expectRevert("DAOVoting: already executed");
        dao.executeProposal(1);
    }

    // --- getProposalState ---

    function test_proposalState_active() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        assertEq(uint256(dao.getProposalState(1)), uint256(DAOVoting.ProposalState.Active));
    }

    function test_proposalState_approved() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        assertEq(uint256(dao.getProposalState(1)), uint256(DAOVoting.ProposalState.Approved));
    }

    function test_proposalState_executed() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);
        dao.executeProposal(1);

        assertEq(uint256(dao.getProposalState(1)), uint256(DAOVoting.ProposalState.Executed));
    }

    // --- canExecute ---

    function test_canExecute_true() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);
        assertTrue(dao.canExecute(1));
    }

    function test_canExecute_false_before_delay() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        assertFalse(dao.canExecute(1));
    }

    function test_canExecute_false_after_execution() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);
        dao.executeProposal(1);

        assertFalse(dao.canExecute(1));
    }

    function test_canExecute_false_rejected() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.AGAINST);
        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);

        assertFalse(dao.canExecute(1));
    }

    // --- createProposal (additional edge cases) ---

    function test_createProposal_revert_zero_recipient() public {
        _setupDeposits();
        vm.prank(alice);
        vm.expectRevert("DAOVoting: invalid recipient");
        dao.createProposal(address(0), 1 ether, VOTING_DURATION, "test");
    }

    function test_createProposal_revert_zero_duration() public {
        _setupDeposits();
        vm.prank(alice);
        vm.expectRevert("DAOVoting: invalid duration");
        dao.createProposal(recipient, 1 ether, 0, "test");
    }

    // --- vote (additional edge cases) ---

    function test_vote_nonexistent_proposal() public {
        vm.prank(alice);
        dao.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert("DAOVoting: proposal does not exist");
        dao.vote(999, DAOVoting.VoteType.FOR);
    }

    // --- changeVote ---

    function test_changeVote_before_deadline() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.prank(alice);
        dao.changeVote(1, DAOVoting.VoteType.AGAINST);

        DAOVoting.Proposal memory p = dao.getProposal(1);
        assertEq(p.forVotes, 0);
        assertEq(p.againstVotes, 1);
        assertEq(uint256(dao.votes(1, alice)), uint256(DAOVoting.VoteType.AGAINST));
    }

    function test_changeVote_revert_not_voted() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        vm.expectRevert("DAOVoting: has not voted");
        dao.changeVote(1, DAOVoting.VoteType.AGAINST);
    }

    function test_changeVote_revert_after_deadline() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        vm.warp(block.timestamp + VOTING_DURATION + 1);

        vm.prank(alice);
        vm.expectRevert("DAOVoting: voting period ended");
        dao.changeVote(1, DAOVoting.VoteType.AGAINST);
    }

    function test_changeVote_revert_same_vote() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");

        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.prank(alice);
        vm.expectRevert("DAOVoting: same vote");
        dao.changeVote(1, DAOVoting.VoteType.FOR);
    }

    // --- executeProposal (additional edge cases) ---

    function test_executeProposal_tied_votes() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        vm.prank(bob);
        dao.vote(1, DAOVoting.VoteType.AGAINST);

        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);
        vm.expectRevert("DAOVoting: proposal not approved");
        dao.executeProposal(1);
    }

    function test_executeProposal_revert_nonexistent() public {
        vm.expectRevert("DAOVoting: proposal does not exist");
        dao.executeProposal(999);
    }

    // --- getProposalState (additional) ---

    function test_proposalState_rejected() public {
        _setupDeposits();
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, VOTING_DURATION, "test");
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.AGAINST);

        vm.warp(block.timestamp + VOTING_DURATION + 1);
        assertEq(uint256(dao.getProposalState(1)), uint256(DAOVoting.ProposalState.Rejected));
    }

    function test_proposalState_revert_nonexistent() public {
        vm.expectRevert("DAOVoting: proposal does not exist");
        dao.getProposalState(999);
    }

    // --- gasless voting (meta-transactions) ---

    uint256 constant SIGNER_KEY = 0xabc123;

    function _signMetaTx(MinimalForwarder.ForwardRequest memory req, uint256 key)
        internal view returns (bytes memory)
    {
        bytes32 digest = forwarder.getTypedDataHash(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _buildVoteRequest(
        address from,
        uint256 nonce,
        uint256 proposalId,
        DAOVoting.VoteType voteType
    ) internal view returns (MinimalForwarder.ForwardRequest memory) {
        return MinimalForwarder.ForwardRequest({
            from: from,
            to: address(dao),
            value: 0,
            gas: 300_000,
            nonce: nonce,
            data: abi.encodeCall(dao.vote, (proposalId, voteType))
        });
    }

    function test_vote_gasless() public {
        address signer = vm.addr(SIGNER_KEY);
        vm.deal(signer, 10 ether);

        vm.prank(signer);
        dao.deposit{value: 5 ether}();
        vm.prank(alice);
        dao.deposit{value: 5 ether}();
        vm.prank(alice);
        uint256 id = dao.createProposal(recipient, 1 ether, VOTING_DURATION, "gasless test");

        MinimalForwarder.ForwardRequest memory req = _buildVoteRequest(signer, 0, id, DAOVoting.VoteType.FOR);
        bytes memory sig = _signMetaTx(req, SIGNER_KEY);
        forwarder.execute(req, sig);

        DAOVoting.Proposal memory p = dao.getProposal(id);
        assertEq(p.forVotes, 1);
        assertTrue(dao.hasVoted(id, signer));
        assertEq(forwarder.getNonce(signer), 1);
    }

    function test_vote_gasless_replay_reverts() public {
        address signer = vm.addr(SIGNER_KEY);
        vm.deal(signer, 10 ether);

        vm.prank(signer);
        dao.deposit{value: 5 ether}();
        vm.prank(alice);
        dao.deposit{value: 5 ether}();
        vm.prank(alice);
        uint256 id = dao.createProposal(recipient, 1 ether, VOTING_DURATION, "replay test");

        MinimalForwarder.ForwardRequest memory req = _buildVoteRequest(signer, 0, id, DAOVoting.VoteType.FOR);
        bytes memory sig = _signMetaTx(req, SIGNER_KEY);
        forwarder.execute(req, sig);

        vm.expectRevert("MinimalForwarder: invalid signature");
        forwarder.execute(req, sig);
    }

    function test_full_workflow_with_gasless_voting() public {
        // Setup: 3 users with known private keys for gasless voting
        uint256 userAKey = 0xaaa111;
        address userA = vm.addr(userAKey);
        uint256 userBKey = 0xbbb222;
        address userB = vm.addr(userBKey);
        uint256 userCKey = 0xccc333;
        address userC = vm.addr(userCKey);
        address beneficiary = makeAddr("beneficiary");

        vm.deal(userA, 15 ether);
        vm.deal(userB, 5 ether);
        vm.deal(userC, 25 ether);

        // Step 1: User A deposits 10 ETH
        vm.prank(userA);
        dao.deposit{value: 10 ether}();
        assertEq(dao.balances(userA), 10 ether);
        assertEq(dao.totalDeposited(), 10 ether);

        // Step 2: User B deposits 1 ETH (will have <10% for proposal creation)
        vm.prank(userB);
        dao.deposit{value: 1 ether}();
        assertEq(dao.balances(userB), 1 ether);
        assertEq(dao.totalDeposited(), 11 ether);

        // Step 3: User A creates proposal (has 10/11 = 90.9% > 10%)
        vm.prank(userA);
        uint256 proposalId = dao.createProposal(beneficiary, 2 ether, VOTING_DURATION, "Full workflow proposal");
        DAOVoting.Proposal memory p = dao.getProposal(proposalId);
        assertEq(p.recipient, beneficiary);
        assertEq(p.amount, 2 ether);

        // Step 4: User B tries to create proposal (has 1/11 = 9.09% < 10%, should fail)
        vm.prank(userB);
        vm.expectRevert("DAOVoting: insufficient balance to propose");
        dao.createProposal(beneficiary, 1 ether, VOTING_DURATION, "B's failed proposal");

        // Step 5: User A votes FOR (gasless via meta-transaction)
        MinimalForwarder.ForwardRequest memory reqA = _buildVoteRequest(userA, 0, proposalId, DAOVoting.VoteType.FOR);
        bytes memory sigA = _signMetaTx(reqA, userAKey);
        forwarder.execute(reqA, sigA);
        p = dao.getProposal(proposalId);
        assertEq(p.forVotes, 1);

        // Step 6: User B votes AGAINST (gasless)
        MinimalForwarder.ForwardRequest memory reqB = _buildVoteRequest(userB, 0, proposalId, DAOVoting.VoteType.AGAINST);
        bytes memory sigB = _signMetaTx(reqB, userBKey);
        forwarder.execute(reqB, sigB);
        p = dao.getProposal(proposalId);
        assertEq(p.forVotes, 1);
        assertEq(p.againstVotes, 1);

        // Step 7: User C deposits 20 ETH
        vm.prank(userC);
        dao.deposit{value: 20 ether}();
        assertEq(dao.balances(userC), 20 ether);
        assertEq(dao.totalDeposited(), 31 ether);

        // Step 8: User C votes FOR (gasless)
        MinimalForwarder.ForwardRequest memory reqC = _buildVoteRequest(userC, 0, proposalId, DAOVoting.VoteType.FOR);
        bytes memory sigC = _signMetaTx(reqC, userCKey);
        forwarder.execute(reqC, sigC);
        p = dao.getProposal(proposalId);
        assertEq(p.forVotes, 2);
        assertEq(p.againstVotes, 1);

        // Step 9: Wait for voting deadline and execution delay
        vm.warp(block.timestamp + VOTING_DURATION + 1 days + 1);

        // Step 10: Check proposal can be executed
        assertTrue(dao.canExecute(proposalId));
        assertEq(uint256(dao.getProposalState(proposalId)), uint256(DAOVoting.ProposalState.Approved));

        // Step 11: Execute proposal (simulating daemon execution)
        uint256 beneficiaryBalanceBefore = beneficiary.balance;
        dao.executeProposal(proposalId);

        // Step 12: Verify execution
        p = dao.getProposal(proposalId);
        assertTrue(p.executed);
        assertEq(beneficiary.balance, beneficiaryBalanceBefore + 2 ether);
        assertEq(uint256(dao.getProposalState(proposalId)), uint256(DAOVoting.ProposalState.Executed));
        assertFalse(dao.canExecute(proposalId));
    }

    function test_vote_gasless_multiple_users() public {
        address signer1 = vm.addr(SIGNER_KEY);
        uint256 signer2Key = 0xdef456;
        address signer2 = vm.addr(signer2Key);
        vm.deal(signer1, 10 ether);
        vm.deal(signer2, 10 ether);

        vm.prank(signer1);
        dao.deposit{value: 5 ether}();
        vm.prank(signer2);
        dao.deposit{value: 5 ether}();
        vm.prank(alice);
        dao.deposit{value: 2 ether}();
        vm.prank(alice);
        uint256 id = dao.createProposal(recipient, 1 ether, VOTING_DURATION, "multi gasless");

        MinimalForwarder.ForwardRequest memory req1 = _buildVoteRequest(signer1, 0, id, DAOVoting.VoteType.FOR);
        forwarder.execute(req1, _signMetaTx(req1, SIGNER_KEY));

        MinimalForwarder.ForwardRequest memory req2 = _buildVoteRequest(signer2, 0, id, DAOVoting.VoteType.AGAINST);
        forwarder.execute(req2, _signMetaTx(req2, signer2Key));

        DAOVoting.Proposal memory p = dao.getProposal(id);
        assertEq(p.forVotes, 1);
        assertEq(p.againstVotes, 1);
    }
}
