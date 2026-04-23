// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract DAOVoting is ERC2771Context {
    enum VoteType { FOR, AGAINST, ABSTAIN }

    enum ProposalState { Active, Approved, Rejected, Executed }

    struct Proposal {
        uint256 id;
        address recipient;
        uint256 amount;
        string description;
        uint256 votingDeadline;
        uint256 executionDelay;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
    }

    uint256 public constant MINIMUM_BALANCE = 0.1 ether;
    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant PROPOSAL_THRESHOLD_BPS = 1000; // 10% en basis points

    uint256 public proposalCount;
    uint256 public totalDeposited;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public balances;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public votes;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed id, address indexed proposer, address recipient, uint256 amount, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, VoteType voteType);
    event ProposalExecuted(uint256 indexed id, address recipient, uint256 amount);

    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {}

    receive() external payable {
        _deposit();
    }

    function deposit() external payable {
        _deposit();
    }

    function withdraw(uint256 amount) external {
        address sender = _msgSender();
        require(balances[sender] >= amount, "DAOVoting: insufficient balance");

        balances[sender] -= amount;
        totalDeposited -= amount;

        (bool ok,) = sender.call{value: amount}("");
        require(ok, "DAOVoting: transfer failed");

        emit Withdrawn(sender, amount);
    }

    function createProposal(
        address recipient,
        uint256 amount,
        uint256 votingDuration,
        string calldata description
    ) external returns (uint256) {
        address sender = _msgSender();
        require(balances[sender] * 10000 >= totalDeposited * PROPOSAL_THRESHOLD_BPS, "DAOVoting: insufficient balance to propose");
        require(address(this).balance >= amount, "DAOVoting: insufficient treasury");
        require(votingDuration > 0, "DAOVoting: invalid duration");
        require(recipient != address(0), "DAOVoting: invalid recipient");

        uint256 id = ++proposalCount;

        proposals[id] = Proposal({
            id: id,
            recipient: recipient,
            amount: amount,
            description: description,
            votingDeadline: block.timestamp + votingDuration,
            executionDelay: EXECUTION_DELAY,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false
        });

        emit ProposalCreated(id, sender, recipient, amount, description);
        return id;
    }

    function vote(uint256 proposalId, VoteType voteType) external {
        address sender = _msgSender();
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "DAOVoting: proposal does not exist");
        require(block.timestamp <= proposal.votingDeadline, "DAOVoting: voting period ended");
        require(balances[sender] >= MINIMUM_BALANCE, "DAOVoting: insufficient balance to vote");
        require(!hasVoted[proposalId][sender], "DAOVoting: already voted");

        hasVoted[proposalId][sender] = true;
        votes[proposalId][sender] = voteType;

        if (voteType == VoteType.FOR) proposal.forVotes++;
        else if (voteType == VoteType.AGAINST) proposal.againstVotes++;
        else proposal.abstainVotes++;

        emit Voted(proposalId, sender, voteType);
    }

    function changeVote(uint256 proposalId, VoteType newVoteType) external {
        address sender = _msgSender();
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "DAOVoting: proposal does not exist");
        require(block.timestamp <= proposal.votingDeadline, "DAOVoting: voting period ended");
        require(hasVoted[proposalId][sender], "DAOVoting: has not voted");

        VoteType oldVote = votes[proposalId][sender];
        require(oldVote != newVoteType, "DAOVoting: same vote");

        if (oldVote == VoteType.FOR) proposal.forVotes--;
        else if (oldVote == VoteType.AGAINST) proposal.againstVotes--;
        else proposal.abstainVotes--;

        votes[proposalId][sender] = newVoteType;
        if (newVoteType == VoteType.FOR) proposal.forVotes++;
        else if (newVoteType == VoteType.AGAINST) proposal.againstVotes++;
        else proposal.abstainVotes++;

        emit Voted(proposalId, sender, newVoteType);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "DAOVoting: proposal does not exist");
        require(!proposal.executed, "DAOVoting: already executed");
        require(block.timestamp > proposal.votingDeadline, "DAOVoting: voting still active");
        require(proposal.forVotes > proposal.againstVotes, "DAOVoting: proposal not approved");
        require(block.timestamp > proposal.votingDeadline + proposal.executionDelay, "DAOVoting: execution delay not elapsed");
        require(address(this).balance >= proposal.amount, "DAOVoting: insufficient treasury");

        proposal.executed = true;

        (bool ok,) = proposal.recipient.call{value: proposal.amount}("");
        require(ok, "DAOVoting: transfer failed");

        emit ProposalExecuted(proposalId, proposal.recipient, proposal.amount);
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        require(p.id != 0, "DAOVoting: proposal does not exist");

        if (p.executed) return ProposalState.Executed;
        if (block.timestamp <= p.votingDeadline) return ProposalState.Active;
        if (p.forVotes > p.againstVotes) return ProposalState.Approved;
        return ProposalState.Rejected;
    }

    function canExecute(uint256 proposalId) external view returns (bool) {
        Proposal storage p = proposals[proposalId];
        return p.id != 0
            && !p.executed
            && block.timestamp > p.votingDeadline
            && p.forVotes > p.againstVotes
            && block.timestamp > p.votingDeadline + p.executionDelay
            && address(this).balance >= p.amount;
    }

    function getUserBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function _deposit() internal {
        require(msg.value > 0, "DAOVoting: must send ETH");
        address sender = _msgSender();
        balances[sender] += msg.value;
        totalDeposited += msg.value;
        emit Deposited(sender, msg.value);
    }
}
