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
        uint256 proposalId, bytes32 oldOption, bytes32 newOption
    );
    error InvalidOption(uint256 proposalId, bytes32 option);

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed owner,
        bytes title,
        uint256 startDate,
        uint256 endDate
    );

    event VoteCast(
        uint256 indexed proposalId, address indexed voter, bytes32 option
    );

    event VoteRetracted(
        uint256 indexed proposalId, address indexed voter, bytes32 option
    );

    event VoteChanged(
        uint256 indexed proposalId,
        address indexed voter,
        bytes32 oldOption,
        bytes32 newOption
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
        bytes title;
        bytes32[] options;
        mapping(bytes32 => bool) optionExistence;
        mapping(bytes32 => uint256) optionVoteCounts;
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
        bytes32 bytesOption = _stringToBytes32(option);
        if (!proposals[proposalId].optionExistence[bytesOption]) 
            revert InvalidOption(proposalId, bytesOption);
        _;
    }

    // ------------------- External Methods -------------------

    function addProposal(
        address voter,
        string calldata title,
        string[] calldata options,
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
        bytes memory bytesTitle = bytes(title);
        _initializeProposal(
            proposal,
            voter,
            bytesTitle,
            options,
            startDate,
            endDate
        );

        voterRegistry.recordUserCreatedProposal(voter, id);
        emit ProposalCreated(id, voter, bytesTitle, startDate, endDate);

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
        bytes32 bytesOption = _stringToBytes32(option);
        _castVote(proposalId, voter, bytesOption);
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

        bytes32 option = voterRegistry.getVoterSelectedOption(voter, proposalId);
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

        bytes32 previousOption =
            voterRegistry.getVoterSelectedOption(voter, proposalId);
        if (!proposals[proposalId].optionExistence[previousOption]) {
            revert InvalidOption(proposalId, previousOption);
        }

        bytes32 bytesNewOption = _stringToBytes32(newOption);
        if (_cmp(previousOption, bytesNewOption)) {
            revert VoteOptionIdentical(
                proposalId, previousOption, bytesNewOption
            );
        }

        _retractVote(proposalId, voter, previousOption);
        _castVote(proposalId, voter, bytesNewOption);

        emit VoteChanged(proposalId, voter, previousOption, bytesNewOption);
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
        bytes32 bytesOption = _stringToBytes32(option);
        return proposals[proposalId].optionVoteCounts[bytesOption];
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

    // ------------------- Private Methods -------------------

    function _castVote(
        uint256 proposalId,
        address voter,
        bytes32 option
    ) private {
        proposals[proposalId].optionVoteCounts[option] += 1;
        proposals[proposalId].isParticipant[voter] = true;
        voterRegistry.recordUserParticipation(voter, proposalId, option);

        emit VoteCast(proposalId, voter, option);
    }

    function _retractVote(
        uint256 proposalId,
        address voter,
        bytes32 option
    ) private {
        proposals[proposalId].optionVoteCounts[option] -= 1;
        proposals[proposalId].isParticipant[voter] = false;
        voterRegistry.removeUserParticipation(voter, proposalId);

        emit VoteRetracted(proposalId, voter, option);
    }

    function _initializeProposal(
        Proposal storage proposal,
        address owner,
        bytes memory title,
        string[] calldata options,
        uint256 startDate,
        uint256 endDate
    ) private {
        proposal.owner = owner;
        proposal.title = bytes(title);
        proposal.startDate = startDate;
        proposal.endDate = endDate;
        proposal.proposalStatus = ProposalStatus.ACTIVE;     // Temporary
        proposal.voteMutability = VoteMutability.MUTABLE;    // Temporary

        for (uint256 i = 0; i < options.length; ++i) {
            string memory tempOption = options[i];
            bytes32 bytesOption = _stringToBytes32(tempOption);
            proposal.options.push(bytesOption);
            proposal.optionExistence[bytesOption] = true;
        }
    }

    function _cmp(bytes32 a, bytes32 b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _stringToBytes32(
        string memory str
    ) private pure returns (bytes32) {
        bytes32 convertedStr;
        assembly {
            convertedStr := mload(add(str, 32))
        }
        return convertedStr;
    }
}
