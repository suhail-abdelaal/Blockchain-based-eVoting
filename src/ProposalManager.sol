// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RBACWrapper} from "./RBACWrapper.sol";
import {IVoterManager} from "./interfaces/IVoterManager.sol";
import {IProposalManager} from "./interfaces/IProposalManager.sol";

contract ProposalManager is IProposalManager, RBACWrapper {

    // ------------------- Errors and Events -------------------

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

    event ProposalStatusUpdated(
        uint256 indexed proposalId, ProposalStatus status
    );

    event ProposalVotesTally(
        uint256 indexed proposalId,
        string[] winners,
        bool isDraw
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

    // ------------------- State Variables -------------------

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
        string title;
        string[] options;
        mapping(string => bool) optionExistence;
        mapping(string => uint256) optionVoteCounts;
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
    IVoterManager private voterManager;
    address private authorizedCaller;

    // ------------------- Constructor -------------------

    constructor(address _rbac, address _voterManager) RBACWrapper(_rbac) {
        voterManager = IVoterManager(_voterManager);
    }

    // ------------------- Modifiers -------------------

    modifier onActiveProposals(uint256 proposalId) {
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


    // ------------------- External Methods -------------------

    function addProposal(
        address voter,
        string calldata title,
        string[] calldata options,
        uint256 startDate,
        uint256 endDate
    )
        external
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(voter)
        returns (uint256)
    {
        if (startDate < block.timestamp + 2 minutes) {
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
        _initializeProposal(proposal, voter, title, options, startDate, endDate);

        voterManager.recordUserCreatedProposal(voter, id);
        emit ProposalCreated(id, voter, title, startDate, endDate);

        return id;
    }

    function castVote(
        address voter,
        uint256 proposalId,
        string calldata option
    )
        external
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(voter)
        onActiveProposals(proposalId)
    {
        if (checkVoterParticipation(voter, proposalId)) {
            revert VoteAlreadyCast(proposalId, voter);
        }
        if (!proposals[proposalId].optionExistence[option]) {
            revert InvalidOption(proposalId, option);
        }
        _castVote(proposalId, voter, option);
    }

    function retractVote(
        address voter,
        uint256 proposalId
    )
        external
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(voter)
        onActiveProposals(proposalId)
        onlyParticipants(voter, proposalId)
    {
        if (getProposalVoteMutability(proposalId) == VoteMutability.IMMUTABLE) {
            revert ImmutableVote(proposalId, voter);
        }

        string memory option =
            voterManager.getVoterSelectedOption(voter, proposalId);
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
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(voter)
        onActiveProposals(proposalId)
        onlyParticipants(voter, proposalId)
    {
        if (getProposalVoteMutability(proposalId) == VoteMutability.IMMUTABLE) {
            revert ImmutableVote(proposalId, voter);
        }

        string memory previousOption =
            voterManager.getVoterSelectedOption(voter, proposalId);
        if (!proposals[proposalId].optionExistence[previousOption]) {
            revert InvalidOption(proposalId, previousOption);
        }

        if (_cmp(previousOption, newOption)) {
            revert VoteOptionIdentical(proposalId, previousOption, newOption);
        }

        _retractVote(proposalId, voter, previousOption);
        _castVote(proposalId, voter, newOption);

        emit VoteChanged(proposalId, voter, previousOption, newOption);
    }

    function getProposalDetails(uint256 proposalId)
        external
        onlyAuthorizedCaller(msg.sender)
        returns (
            string memory title,
            string[] memory options,
            uint256 startDate,
            uint256 endDate,
            address owner,
            bool isDraw,
            string[] memory winners
        )
    {
        _checkProposalStatus(proposalId);
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.title,
            proposal.options,
            proposal.startDate,
            proposal.endDate,
            proposal.owner,
            proposal.isDraw,
            proposal.winners
        );
    }

    // ------------------- Public Methods -------------------

    function checkVoterParticipation(
        address voter,
        uint256 proposalId
    ) public view onlyAuthorizedCaller(msg.sender) returns (bool) {
        return proposals[proposalId].isParticipant[voter];
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view onlyAuthorizedCaller(msg.sender) returns (uint256) {
        return _getVoteCount(proposalId, option);
    }

    function getProposalWinner(uint256 proposalId)
        external
        onlyAuthorizedCaller(msg.sender)
        returns (string[] memory, bool)
    {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.status == ProposalStatus.FINALIZED) {
            return (proposal.winners, proposal.isDraw);
        }

        _checkProposalStatus(proposalId);
        if (proposal.status != ProposalStatus.FINALIZED) {
            revert ProposalNotFinalized(proposalId);
        }

        return (proposal.winners, proposal.isDraw);
    }

    function getProposalCount()
        external
        view
        onlyAuthorizedCaller(msg.sender)
        returns (uint256)
    {
        return proposalCount;
    }

    function getProposalStatus(uint256 proposalId)
        public
        onlyAuthorizedCaller(msg.sender)
        returns (ProposalStatus)
    {
        _checkProposalStatus(proposalId);
        return proposals[proposalId].status;
    }

    function getProposalVoteMutability(uint256 proposalId)
        public
        view
        onlyAuthorizedCaller(msg.sender)
        returns (VoteMutability)
    {
        return proposals[proposalId].voteMutability;
    }

    function getProposalOwner(uint256 proposalId)
        public
        view
        onlyAuthorizedCaller(msg.sender)
        returns (address)
    {
        return proposals[proposalId].owner;
    }

    // ------------------- Private Methods -------------------

    function _castVote(
        uint256 proposalId,
        address voter,
        string calldata option
    ) private {
        proposals[proposalId].optionVoteCounts[option] += 1;
        proposals[proposalId].isParticipant[voter] = true;
        voterManager.recordUserParticipation(voter, proposalId, option);

        emit VoteCast(proposalId, voter, option);
    }

    function _retractVote(
        uint256 proposalId,
        address voter,
        string memory option
    ) private {
        proposals[proposalId].optionVoteCounts[option] -= 1;
        proposals[proposalId].isParticipant[voter] = false;
        voterManager.removeUserParticipation(voter, proposalId);

        emit VoteRetracted(proposalId, voter, option);
    }

    function _initializeProposal(
        Proposal storage proposal,
        address owner,
        string memory title,
        string[] memory options,
        uint256 startDate,
        uint256 endDate
    ) private {
        proposal.owner = owner;
        proposal.title = title;
        proposal.options = options;
        proposal.startDate = startDate;
        proposal.endDate = endDate;
        proposal.status = ProposalStatus.PENDING;
        proposal.voteMutability = VoteMutability.MUTABLE;

        for (uint256 i = 0; i < options.length; ++i) {
            proposal.optionExistence[options[i]] = true;
        }
    }

    function _getVoteCount(
        uint256 proposalId,
        string memory option
    ) private view returns (uint256) {
        return proposals[proposalId].optionVoteCounts[option];
    }

    function _checkProposalStatus(uint256 proposalId) private {
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
    
    function _tallyVotes(Proposal storage proposal)
        private
        onlyAuthorizedCaller(msg.sender)
    {
        uint256 highestVoteCount;

        for (uint256 i = 0; i < proposal.options.length; ++i) {
            uint256 voteCount = _getVoteCount(proposal.id, proposal.options[i]);
            if (voteCount > highestVoteCount) highestVoteCount = voteCount;
        }

        for (uint256 i = 0; i < proposal.options.length; ++i) {
            uint256 voteCount = _getVoteCount(proposal.id, proposal.options[i]);
            if (voteCount == highestVoteCount) {
                proposal.winners.push(proposal.options[i]);
            }
        }
        proposal.isDraw = (proposal.winners.length > 1);
        emit ProposalVotesTally(
            proposal.id,
            proposal.winners,
            proposal.isDraw
        );
        _updateProposalStatus(proposal, ProposalStatus.FINALIZED);
    }

    function _cmp(
        string memory a,
        string memory b
    ) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _bytes32ToString(bytes32 _bytes32)
        private
        pure
        returns (string memory)
    {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) i++;

        bytes memory bytesArray = new bytes(i);
        for (uint8 j = 0; j < i; j++) {
            bytesArray[j] = _bytes32[j];
        }

        return string(bytesArray);
    }

    function _stringToBytes32(string memory str)
        private
        pure
        returns (bytes32)
    {
        return bytes32(bytes(str));
    }

}
