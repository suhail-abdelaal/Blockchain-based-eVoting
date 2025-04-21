// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RBACWrapper} from "./RBACWrapper.sol";
import {VoterRegistry} from "./VoterRegistry.sol";

contract Ballot is RBACWrapper {
    /* Errors and Events */
    error ProposalNotFound(uint256 proposalId);
    error ProposalStartDateTooEarly(uint256 startDate);
    error ProposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);
    error ProposalNotStartedYet(uint256 proposalId);
    error ProposalPeriodTooShort(uint256 startDate, uint256 endDate);
    error ProposalClosed(uint256 proposalId);
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
        CLOSED
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
        ProposalStatus status;
        VoteMutability voteMutability;
        mapping(address => bool) isParticipant;
        uint256 startDate;
        uint256 endDate;
        bytes32[] winners;
    }

    mapping(uint256 => Proposal) private proposals;
    uint256 private proposalCount;
    VoterRegistry private voterRegistry;
    address private authorizedCaller;

    constructor(
        address _rbac,
        address _authorizedCaller,
        address _voterRegistry
    ) RBACWrapper(_rbac) {
        authorizedCaller = _authorizedCaller;
        voterRegistry = VoterRegistry(_voterRegistry);
    }

    // ------------------- Modifiers -------------------

    modifier onlyAutorizedCaller() {
        if (msg.sender != authorizedCaller || msg.sender != address(this)) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    modifier onActiveProposals(
        uint256 proposalId
    ) {
        _updateProposalStatus(proposalId);
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
        bytes memory bytesTitle = bytes(title);
        _initializeProposal(
            proposal, voter, bytesTitle, options, startDate, endDate
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
        onlyAutorizedCaller
        onlyVerifiedAddr(voter)
        onActiveProposals(proposalId)
        onlyParticipants(voter, proposalId)
    {
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
    ) public view onlyAutorizedCaller returns (bool) {
        return proposals[proposalId].isParticipant[voter];
    }

    function tallyVotes(
        uint256 proposalId
    ) public onlyAutorizedCaller {
        uint256 highestVoteCount;
        bytes32 winner;
        bytes32[] memory initialWinners;
        uint256 initialWinnersIndex;
        Proposal storage proposal = proposals[proposalId];
        for (uint256 i; i < proposal.options.length; ++i) {
            uint256 optionVoteCount =
                _getVoteCount(proposalId, proposal.options[i]);
            if (optionVoteCount > highestVoteCount) {
                winner = proposal.options[i];
                initialWinners[initialWinnersIndex] = winner;
                ++initialWinnersIndex;
                highestVoteCount = optionVoteCount;
            }
        }

        for (uint256 i; i < initialWinnersIndex; ++i) {
            uint256 optionVoteCount =
                _getVoteCount(proposalId, initialWinners[i]);
            if (optionVoteCount == highestVoteCount) {
                proposal.winners.push(initialWinners[i]);
            }
        }
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view onlyAutorizedCaller returns (uint256) {
        bytes32 bytesOption = _stringToBytes32(option);
        return _getVoteCount(proposalId, bytesOption);
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
        _updateProposalStatus(proposalId);
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

    function _updateProposalStatus(
        uint256 id
    ) private {
        Proposal storage proposal = proposals[id];
        ProposalStatus status;
        if (proposal.startDate <= block.timestamp) {
            status = ProposalStatus.ACTIVE;
        } else if (proposal.endDate <= block.timestamp) {
            status = ProposalStatus.CLOSED;
            tallyVotes(id);
        }

        if (status != ProposalStatus.NONE) {
            proposal.status = status;
            emit ProposalStatusUpdated(id, status);
        }
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
