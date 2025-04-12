// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RBAC} from "./RBAC.sol";
import {VoterRegistry} from "./VoterRegistry.sol";

contract Ballot is RBAC {

    /* Errors and Events */
    error ProposalNotFound(uint256 proposalId);
    error ProposalStartDateTooEarly(uint256 startDate);
    error ProposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);
    error ProposalCompleted(uint256 proposalId);
    error ProposalNotStartedYet(uint256 proposalId);
    error VoteAlreadyCast(uint256 proposalId, address voter);
    error ImmutableVote(uint256 proposalId, address voter);
    error VoterNotParticipated(uint256 proposalId, address voter);
    error VoteOptionIdentical(uint256 proposalId, string oldOption, string newOption);

    event ProposalCreated(
        uint256 indexed proposalId, 
        address indexed owner, 
        string title, 
        uint256 startDate, 
        uint256 endDate
        );

    event VoteCast(
        uint256 indexed proposalId, 
        address indexed voter, 
        string option
        );

    event VoteRetracted(
        uint256 indexed proposalId, 
        address indexed voter, 
        string option
        );

    event VoteChanged(
        uint256 indexed proposalId, 
        address indexed voter, 
        string oldOption, 
        string newOption
        );

    enum ProposalStatus { PENDING, ACTIVE, COMPLETED }
    enum VoteMutability { IMMUTABLE, MUTABLE }

    struct Proposal {
        address owner;
        string title;
        string[] options;
        mapping(string candidateName => uint256 voteCount) optionVoteCounts;
        ProposalStatus proposalStatus;
        VoteMutability voteMutability;
        uint256 startDate;
        uint256 endDate;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    VoterRegistry public voterRegistry;

    constructor(address _voterRegistry) {
        voterRegistry = VoterRegistry(_voterRegistry);
        proposalCount = 0;
    }

    modifier onActiveProposals(uint256 proposalId) {
        if (proposalId > proposalCount) revert ProposalNotFound(proposalId);
        ProposalStatus status = proposals[proposalId].proposalStatus;
        if (status == ProposalStatus.COMPLETED) revert ProposalCompleted(proposalId);
        if (status == ProposalStatus.PENDING) revert ProposalNotStartedYet(proposalId);
        _;
    }

    modifier onlyParticipants(uint256 proposalId)  {
        if (!voterRegistry.checkVoterParticipation(msg.sender, proposalId))
            revert VoterNotParticipated(proposalId, msg.sender);
        _;
    }

    function addProposal(
        string calldata _title,
        string[] calldata _options,
        uint256 _startDate,
        uint256 _endDate
    ) external onlyVerifiedVoter returns (uint256) {
        if (_startDate <= block.timestamp + 10 minutes)
            revert ProposalStartDateTooEarly(_startDate);
        if (_endDate <= _startDate)
            revert ProposalEndDateLessThanStartDate(_startDate, _endDate);

        ++proposalCount;
        uint256 id = proposalCount;
        Proposal storage proposal = proposals[id];
        _initializeProposal(proposal, _title, _options, _startDate, _endDate, msg.sender);

        voterRegistry.recordUserCreatedProposal(msg.sender, id);
        emit ProposalCreated(id, msg.sender, _title, _startDate, _endDate);

        return id;
    }

    function castVote(
        uint256 _proposalId,
        string calldata _option
    ) external onlyVerifiedVoter onActiveProposals(_proposalId) {
        address voter = msg.sender;
        if (voterRegistry.checkVoterParticipation(voter, _proposalId))
            revert VoteAlreadyCast(_proposalId, voter);

        _castVote(_proposalId, voter, _option);
    }

    function retractVote(
        uint256 _proposalId,
        string calldata _option
    ) external onlyVerifiedVoter onActiveProposals(_proposalId) onlyParticipants(_proposalId) {
        address voter = msg.sender;
        if (getProposalVoteMutability(_proposalId) == VoteMutability.IMMUTABLE)
            revert ImmutableVote(_proposalId, voter);
            
        _retractVote(_proposalId, voter, _option);
    }

    function changeVote(
        uint256 _proposalId,
        string calldata _newOption
    ) external onlyVerifiedVoter onActiveProposals(_proposalId) onlyParticipants(_proposalId) {
        address voter = msg.sender;
        if (getProposalVoteMutability(_proposalId) == VoteMutability.IMMUTABLE)
            revert ImmutableVote(_proposalId, voter);

        string memory previousOption = voterRegistry.getVoterSelectedOption(voter, _proposalId);
        if (cmpStrings(previousOption, _newOption)) 
            revert VoteOptionIdentical(_proposalId, previousOption, _newOption);

        _retractVote(_proposalId, voter, previousOption);
        _castVote(_proposalId, voter, _newOption);

        emit VoteChanged(_proposalId, voter, previousOption, _newOption);
    }

    function getProposalStatus(uint256 _proposalId) public view returns (ProposalStatus) {
        return proposals[_proposalId].proposalStatus;
    }

    function getProposalVoteMutability(uint256 _proposalId) public view returns (VoteMutability) {
        return proposals[_proposalId].voteMutability;
    }

    function getProposalOwner(uint256 _proposalId) public view returns (address) {
        return proposals[_proposalId].owner;
    }

    // ------------------- Internal Helpers -------------------

    function _castVote(uint256 _proposalId, address voter, string calldata _option) internal {
        proposals[_proposalId].optionVoteCounts[_option] += 1;
        voterRegistry.recordUserParticipation(voter, _proposalId, _option);

        emit VoteCast(_proposalId, voter, _option);
    }

    function _retractVote(uint256 _proposalId, address voter, string memory _option) internal {
        proposals[_proposalId].optionVoteCounts[_option] -= 1;
        voterRegistry.removeUserParticipation(voter, _proposalId);

        emit VoteRetracted(_proposalId, voter, _option);
    }

    function _initializeProposal(
        Proposal storage proposal,
        string calldata _title,
        string[] calldata _options,
        uint256 _startDate,
        uint256 _endDate,
        address _owner
    ) internal {
        proposal.owner = _owner;
        proposal.title = _title;
        proposal.startDate = _startDate;
        proposal.endDate = _endDate;
        proposal.proposalStatus = (_startDate >= block.timestamp)
            ? ProposalStatus.ACTIVE
            : ProposalStatus.PENDING;

        for (uint256 i = 0; i < _options.length; ++i) {
            proposal.options.push(_options[i]);
            proposal.optionVoteCounts[_options[i]] = 0;
        }
    }

    function cmpStrings(string memory a, string memory b) internal pure returns (bool) {
        // Convert the strings to bytes and check if they are of the same length
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
