// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RBACWrapper} from "./RBACWrapper.sol";
import {VoterManager} from "./VoterManager.sol";
import {console} from "forge-std/Test.sol";

contract ProposalManager is RBACWrapper {
    /* Errors and Events */
    error ProposalNotFound(uint256 proposalId);
    error ProposalStartDateTooEarly(uint256 startDate);
    error ProposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);
    error ProposalNotStartedYet(uint256 proposalId);
    error ProposalPeriodTooShort(uint256 startDate, uint256 endDate);
    error ProposalClosed(uint256 proposalId);
    error ProposalNotFinalized(uint256 proposalId);
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

    event ProposalStatusUpdated(
        uint256 indexed proposalId, ProposalStatus status
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
        NONE,
        PENDING,
        ACTIVE,
        CLOSED,
        FINALIZED
    }
    enum VoteMutability {
        IMMUTABLE,
        MUTABLE
    }

    struct Proposal {
        uint256 id;
        address owner;
        bytes title;
        bytes32[] options;
        mapping(bytes32 => bool) optionExistence;
        mapping(bytes32 => uint256) optionVoteCounts;
        ProposalStatus status;
        VoteMutability voteMutability;
        mapping(address => bool) isParticipant;
        uint256 startDate;
        uint256 endDate;
        string[] winners;
        bool isDraw;
    }

    mapping(uint256 => Proposal) private proposals;
    uint256 private proposalCount;
    VoterManager private voterManager;
    address private authorizedCaller;

    constructor(
        address _rbac,
        address _authorizedCaller,
        address _voterManager
    ) RBACWrapper(_rbac) {
        authorizedCaller = _authorizedCaller;
        voterManager = VoterManager(_voterManager);
    }

    // ------------------- Modifiers -------------------

    modifier onlyAutorizedCaller() {
        if (msg.sender != authorizedCaller && msg.sender != address(this)) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    modifier onActiveProposals(
        uint256 proposalId
    ) {
        _checkProposalStatus(proposalId);
        ProposalStatus status = proposals[proposalId].status;
        if (status == ProposalStatus.CLOSED) revert ProposalClosed(proposalId);
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
        if (!proposals[proposalId].optionExistence[bytesOption]) {
            revert InvalidOption(proposalId, bytesOption);
        }
        _;
    }

    // ------------------- External Methods -------------------

    function addProposal(
        address voter,
        string calldata title,
        string[] calldata options,
        uint256 startDate,
        uint256 endDate
    ) external onlyAutorizedCaller onlyVerifiedAddr(voter) returns (uint256) {
        if (startDate < block.timestamp + 10 minutes) {
            revert ProposalStartDateTooEarly(startDate);
        }
        if (endDate <= startDate) {
            revert ProposalEndDateLessThanStartDate(startDate, endDate);
        }
        if ((endDate - startDate) < 1 hours) {
            revert ProposalPeriodTooShort(startDate, endDate);
        }
        ++proposalCount;
        uint256 id = proposalCount;
        Proposal storage proposal = proposals[id];
        proposal.id = id;
        bytes memory bytesTitle = bytes(title);
        _initializeProposal(
            proposal, voter, bytesTitle, options, startDate, endDate
        );

        voterManager.recordUserCreatedProposal(voter, id);
        emit ProposalCreated(id, voter, bytesTitle, startDate, endDate);

        return id;
    }

    function castVote(
        address voter,
        uint256 proposalId,
        string calldata option
    )
        external
        onlyAutorizedCaller
        onlyVerifiedAddr(voter)
        onActiveProposals(proposalId)
        onlyValidOptions(proposalId, option)
    {
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
        onlyAutorizedCaller
        onlyVerifiedAddr(voter)
        onActiveProposals(proposalId)
        onlyParticipants(voter, proposalId)
    {
        if (getProposalVoteMutability(proposalId) == VoteMutability.IMMUTABLE) {
            revert ImmutableVote(proposalId, voter);
        }

        bytes32 option = voterManager.getVoterSelectedOption(voter, proposalId);
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
        onlyAutorizedCaller
        onlyVerifiedAddr(voter)
        onActiveProposals(proposalId)
        onlyParticipants(voter, proposalId)
    {
        if (getProposalVoteMutability(proposalId) == VoteMutability.IMMUTABLE) {
            revert ImmutableVote(proposalId, voter);
        }

        bytes32 previousOption =
            voterManager.getVoterSelectedOption(voter, proposalId);
        if (!proposals[proposalId].optionExistence[previousOption]) {
            revert InvalidOption(proposalId, previousOption);
        }

        bytes32 bytesNewOption = _stringToBytes32(newOption);
        if (previousOption == bytesNewOption) {
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
    ) public view onlyAutorizedCaller returns (bool) {
        return proposals[proposalId].isParticipant[voter];
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view onlyAutorizedCaller returns (uint256) {
        bytes32 bytesOption = _stringToBytes32(option);
        return _getVoteCount(proposalId, bytesOption);
    }

    function getProposalWinner(
        uint256 proposalId
    ) external onlyAutorizedCaller returns (string[] memory, bool) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.status == ProposalStatus.FINALIZED) {
            return (proposal.winners, proposal.isDraw);
        }

        _checkProposalStatus(proposalId);
        // @audit
        if (proposal.status != ProposalStatus.FINALIZED) {
            revert ProposalNotFinalized(proposalId);
        }

        return (proposal.winners, proposal.isDraw);
    }

    function getProposalCount()
        external
        view
        onlyAutorizedCaller
        returns (uint256)
    {
        return proposalCount;
    }

    function getProposalStatus(
        uint256 proposalId
    ) public onlyAutorizedCaller returns (ProposalStatus) {
        _checkProposalStatus(proposalId);
        return proposals[proposalId].status;
    }

    function getProposalVoteMutability(
        uint256 proposalId
    ) public view onlyAutorizedCaller returns (VoteMutability) {
        return proposals[proposalId].voteMutability;
    }

    function getProposalOwner(
        uint256 proposalId
    ) public view onlyAutorizedCaller returns (address) {
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
        voterManager.recordUserParticipation(voter, proposalId, option);

        emit VoteCast(proposalId, voter, option);
    }

    function _retractVote(
        uint256 proposalId,
        address voter,
        bytes32 option
    ) private {
        proposals[proposalId].optionVoteCounts[option] -= 1;
        proposals[proposalId].isParticipant[voter] = false;
        voterManager.removeUserParticipation(voter, proposalId);

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
        proposal.status = ProposalStatus.PENDING;
        proposal.voteMutability = VoteMutability.MUTABLE; // Temporary

        for (uint256 i = 0; i < options.length; ++i) {
            string memory tempOption = options[i];
            bytes32 bytesOption = _stringToBytes32(tempOption);
            proposal.options.push(bytesOption);
            proposal.optionExistence[bytesOption] = true;
        }
    }

    function _getVoteCount(
        uint256 proposalId,
        bytes32 option
    ) private view returns (uint256) {
        return proposals[proposalId].optionVoteCounts[option];
    }

    function _checkProposalStatus(
        uint256 proposalId
    ) private {
        Proposal storage proposal = proposals[proposalId];
        uint256 currentTime = block.timestamp;
        if (
            proposal.status != ProposalStatus.ACTIVE
                && proposal.startDate <= currentTime
                && proposal.endDate > currentTime
        ) {
            _updateProposalStatus(proposal, ProposalStatus.ACTIVE);
        } else if (
            proposal.status != ProposalStatus.CLOSED
                && proposal.endDate <= currentTime
        ) {
            _updateProposalStatus(proposal, ProposalStatus.CLOSED);
            _tallyVotes(proposal);
        }
    }

    function _updateProposalStatus(
        Proposal storage proposal,
        ProposalStatus status
    ) private {
        proposal.status = status;
        emit ProposalStatusUpdated(proposal.id, status);
    }

    function _tallyVotes(
        Proposal storage proposal
    ) private onlyAutorizedCaller {
        uint256 highestVoteCount;

        // 1. First pass to find the highest vote count
        for (uint256 i = 0; i < proposal.options.length; ++i) {
            uint256 voteCount = _getVoteCount(proposal.id, proposal.options[i]);
            if (voteCount > highestVoteCount) highestVoteCount = voteCount;
        }

        // 2. Second pass to collect all winners who match that count
        for (uint256 i = 0; i < proposal.options.length; ++i) {
            uint256 voteCount = _getVoteCount(proposal.id, proposal.options[i]);
            if (voteCount == highestVoteCount) {
                proposal.winners.push(_bytes32ToString(proposal.options[i]));
            }
        }
        proposal.isDraw = (proposal.winners.length > 1);
        proposal.status = ProposalStatus.FINALIZED;
    }


    function _bytes32ToString(
        bytes32 _bytes32
    ) private pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) i++;

        bytes memory bytesArray = new bytes(i);
        for (uint8 j = 0; j < i; j++) {
            bytesArray[j] = _bytes32[j];
        }

        return string(bytesArray);
    }

    function _stringToBytes32(
        string memory str
    ) private pure returns (bytes32) {
        return bytes32(bytes(str));
    }
}
