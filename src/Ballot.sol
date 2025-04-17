// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RBACWrapper} from "./RBACWrapper.sol";
import {VoterRegistry} from "./VoterRegistry.sol";
import {Vote} from "./Vote.sol";

contract Ballot is RBACWrapper {
    /* Errors and Events */
    error ProposalNotFound(uint256 proposalId);
    error ProposalStartDateTooEarly(uint256 startDate);
    error ProposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);
    error ProposalCompleted(uint256 proposalId);
    error ProposalNotStartedYet(uint256 proposalId);
    error NotAuthorized(address addr);
    error VoteAlreadyCast(uint256 proposalId, address voter);
    error ImmutableVote(uint256 proposalId, address voter);
    error VoterNotParticipated(uint256 proposalId, address voter);
    error VoteOptionIdentical(
        uint256 proposalId, string oldOption, string newOption
    );
    error InvalidOption(uint256 proposalId, string option);

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed owner,
        string title,
        uint256 startDate,
        uint256 endDate
    );

    event VoteCast(
        uint256 indexed proposalId, address indexed voter, string option
    );

    event VoteRetracted(
        uint256 indexed proposalId, address indexed voter, string option
    );

    event VoteChanged(
        uint256 indexed proposalId,
        address indexed voter,
        string oldOption,
        string newOption
    );

    enum ProposalStatus {
        PENDING,
        ACTIVE,
        COMPLETED
    }
    enum VoteMutability {
        IMMUTABLE,
        MUTABLE
    }

    struct Proposal {
        address owner;
        string title;
        string[] options;
        mapping(string => bool) optionExistence;
        mapping(string => uint256) optionVoteCounts;
        ProposalStatus proposalStatus;
        VoteMutability voteMutability;
        mapping(address => bool) isParticipant;
        uint256 startDate;
        uint256 endDate;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    VoterRegistry public voterRegistry;
    address authorizedCaller;

    constructor(
        address _rbac,
        address _authorizedCaller,
        address _voterRegistry
    ) RBACWrapper(_rbac) {
        authorizedCaller = _authorizedCaller;
        voterRegistry = VoterRegistry(_voterRegistry);
    }

    // ------------------- Modifiers -------------------

    modifier onActiveProposals(
        uint256 proposalId
    ) {
        // if (proposalId > proposalCount) revert ProposalNotFound(proposalId);
        ProposalStatus status = proposals[proposalId].proposalStatus;
        if (status == ProposalStatus.COMPLETED) {
            revert ProposalCompleted(proposalId);
        }
        if (status == ProposalStatus.PENDING) {
            revert ProposalNotStartedYet(proposalId);
        }
        _;
    }

    modifier onlyParticipants(address voter, uint256 proposalId) {
        if (!checkVoterParticipation(voter, proposalId)) {
            revert VoterNotParticipated(proposalId, voter);
        }
        _;
    }

    modifier onlyValidOptions(uint256 proposalId, string calldata option) {
        if (!proposals[proposalId].optionExistence[option]) {
            revert InvalidOption(proposalId, option);
        }
        _;
    }

    // ------------------- External Methods -------------------

    function addProposal(
        address voter,
        string calldata title,
        string[] calldata options,
        VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) external onlyVerifiedVoterAddr(voter) returns (uint256) {
        if (msg.sender != authorizedCaller) revert NotAuthorized(msg.sender);

        if (startDate <= block.timestamp + 10 minutes) {
            revert ProposalStartDateTooEarly(startDate);
        }
        if (endDate <= startDate) {
            revert ProposalEndDateLessThanStartDate(startDate, endDate);
        }

        ++proposalCount;
        uint256 id = proposalCount;
        Proposal storage proposal = proposals[id];
        _initializeProposal(
            proposal, voter, title, options, voteMutability, startDate, endDate
        );

        voterRegistry.recordUserCreatedProposal(voter, id);
        emit ProposalCreated(id, voter, title, startDate, endDate);

        return id;
    }

    function castVote(
        address voter,
        uint256 proposalId,
        string calldata option
    )
        external
        onlyVerifiedVoterAddr(voter)
        onActiveProposals(proposalId)
        onlyValidOptions(proposalId, option)
    {
        if (msg.sender != authorizedCaller) revert NotAuthorized(msg.sender);
        if (checkVoterParticipation(voter, proposalId)) {
            revert VoteAlreadyCast(proposalId, voter);
        }

        _castVote(proposalId, voter, option);
    }

    function retractVote(
        address voter,
        uint256 proposalId
    )
        external
        onlyVerifiedVoterAddr(voter)
        onActiveProposals(proposalId)
        onlyParticipants(voter, proposalId)
    {
        if (msg.sender != authorizedCaller) revert NotAuthorized(msg.sender);
        if (getProposalVoteMutability(proposalId) == VoteMutability.IMMUTABLE) {
            revert ImmutableVote(proposalId, voter);
        }

        string memory option =
            voterRegistry.getVoterSelectedOption(voter, proposalId);
        if (!proposals[proposalId].optionExistence[option]) {
            revert InvalidOption(proposalId, option);
        }

        _retractVote(proposalId, voter, option);
    }

    function changeVote(
        address voter,
        uint256 proposalId,
        string calldata newOption
    )
        external
        onlyVerifiedVoterAddr(voter)
        onActiveProposals(proposalId)
        onlyParticipants(voter, proposalId)
    {
        if (msg.sender != authorizedCaller) revert NotAuthorized(msg.sender);
        if (getProposalVoteMutability(proposalId) == VoteMutability.IMMUTABLE) {
            revert ImmutableVote(proposalId, voter);
        }

        string memory previousOption =
            voterRegistry.getVoterSelectedOption(voter, proposalId);
        if (!proposals[proposalId].optionExistence[previousOption]) {
            revert InvalidOption(proposalId, previousOption);
        }

        if (_cmpStrings(previousOption, newOption)) {
            revert VoteOptionIdentical(proposalId, previousOption, newOption);
        }

        _retractVote(proposalId, voter, previousOption);
        _castVote(proposalId, voter, newOption);

        emit VoteChanged(proposalId, voter, previousOption, newOption);
    }

    // ------------------- Public Methods -------------------

    function checkVoterParticipation(
        address voter,
        uint256 proposalId
    ) public view returns (bool) {
        return proposals[proposalId].isParticipant[voter];
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view returns (uint256) {
        return proposals[proposalId].optionVoteCounts[option];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    function getProposalStatus(
        uint256 proposalId
    ) public view returns (ProposalStatus) {
        return proposals[proposalId].proposalStatus;
    }

    function getProposalVoteMutability(
        uint256 proposalId
    ) public view returns (VoteMutability) {
        return proposals[proposalId].voteMutability;
    }

    function getProposalOwner(
        uint256 proposalId
    ) public view returns (address) {
        return proposals[proposalId].owner;
    }

    // ------------------- Internal Methods -------------------

    function _castVote(
        uint256 proposalId,
        address voter,
        string calldata option
    ) internal {
        proposals[proposalId].optionVoteCounts[option] += 1;
        proposals[proposalId].isParticipant[voter] = true;
        voterRegistry.recordUserParticipation(voter, proposalId, option);

        emit VoteCast(proposalId, voter, option);
    }

    function _retractVote(
        uint256 proposalId,
        address voter,
        string memory option
    ) internal {
        proposals[proposalId].optionVoteCounts[option] -= 1;
        proposals[proposalId].isParticipant[voter] = false;
        // voterRegistry.removeUserParticipation(voter, proposalId);

        emit VoteRetracted(proposalId, voter, option);
    }

    function _initializeProposal(
        Proposal storage proposal,
        address owner,
        string calldata title,
        string[] calldata options,
        VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) internal {
        proposal.owner = owner;
        proposal.title = title;
        proposal.startDate = startDate;
        proposal.endDate = endDate;
        // proposal.proposalStatus = (startDate >= block.timestamp)
        // ? ProposalStatus.ACTIVE
        // : ProposalStatus.PENDING;
        proposal.proposalStatus = ProposalStatus.ACTIVE;
        proposal.voteMutability = voteMutability;

        for (uint256 i = 0; i < options.length; ++i) {
            proposal.options.push(options[i]);
            proposal.optionExistence[options[i]] = true;
            // proposal.optionVoteCounts[options[i]] = 0;
        }
    }

    function _cmpStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        // Convert the strings to bytes and check if they are of the same length
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
