// SPDX-License-I1ntifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IProposalState.sol";
import "../access/AccessControlWrapper.sol";

contract ProposalState is IProposalState, AccessControlWrapper {

    struct Proposal {
        uint256 id;
        address owner;
        string title;
        string[] options;
        ProposalStatus status;
        VoteMutability voteMutability;
        mapping(string => uint256) voteCount;
        mapping(string => bool) optionExistence;
        mapping(address => bool) isParticipant;
        uint256 numOfParticipants;
        uint256 startDate;
        uint256 endDate;
        bool isDraw;
        string[] winners;
    }

    mapping(uint256 => Proposal) private proposals;
    uint256 private proposalCount;
    uint256 private id;

    event ProposalStatusUpdated(
        uint256 indexed proposalId, ProposalStatus status
    );

    event ProposalFinalized(
        uint256 indexed proposalId, string[] winners, bool isDraw
    );

    constructor(address _accessControl) AccessControlWrapper(_accessControl) {
        id = 1;
    }

    function getProposalStatus(uint256 proposalId)
        external
        view
        override
        returns (ProposalStatus)
    {
        return proposals[proposalId].status;
    }

    function getCurrentProposalStatus(uint256 proposalId)
        external
        override
        returns (ProposalStatus)
    {
        _updateProposalStatus(proposalId);
        return proposals[proposalId].status;
    }

    function updateProposalStatus(uint256 proposalId)
        external
        override
        onlyAuthorizedCaller(msg.sender)
    {
        _updateProposalStatus(proposalId);
    }

    function _updateProposalStatus(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        uint256 currentTime = block.timestamp;

        if (
            proposal.status != ProposalStatus.ACTIVE
                && proposal.startDate <= currentTime
                && proposal.endDate > currentTime
        ) {
            proposal.status = ProposalStatus.ACTIVE;
            emit ProposalStatusUpdated(proposalId, ProposalStatus.ACTIVE);
        } else if (
            proposal.status != ProposalStatus.CLOSED
                && proposal.endDate <= currentTime
        ) {
            proposal.status = ProposalStatus.CLOSED;
            emit ProposalStatusUpdated(proposalId, ProposalStatus.CLOSED);
            tallyVotes(proposalId);
            emit ProposalFinalized(
                proposalId,
                proposals[proposalId].winners,
                proposals[proposalId].isDraw
            );
        }
    }

    function getProposalVoteMutability(uint256 proposalId)
        external
        view
        override
        returns (VoteMutability)
    {
        return proposals[proposalId].voteMutability;
    }

    function isProposalActive(uint256 proposalId)
        external
        view
        override
        returns (bool)
    {
        return proposals[proposalId].status == ProposalStatus.ACTIVE;
    }

    function isProposalClosed(uint256 proposalId)
        external
        view
        override
        returns (bool)
    {
        return proposals[proposalId].status == ProposalStatus.CLOSED;
    }

    function createProposal(
        address owner,
        string calldata title,
        string[] memory options,
        VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) external onlyAuthorizedCaller(msg.sender) returns (uint256) {
        Proposal storage proposal = proposals[id];

        proposal.id = id;
        proposal.owner = owner;
        proposal.title = title;
        proposal.options = options;
        proposal.startDate = startDate;
        proposal.endDate = endDate;
        proposal.status = ProposalStatus.PENDING;
        proposal.voteMutability = voteMutability;

        for (uint256 i = 0; i < options.length; ++i) {
            proposal.optionExistence[options[i]] = true;
        }

        id++;
        proposalCount++;

        _updateProposalStatus(proposal.id);

        return proposal.id;
    }

    function incrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].voteCount[option]++;
    }

    function decrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].voteCount[option]--;
    }

    function addParticipant(
        uint256 proposalId,
        address voter
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].isParticipant[voter] = true;
        proposals[proposalId].numOfParticipants++;
    }

    function removeParticipant(
        uint256 proposalId,
        address voter
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].isParticipant[voter] = false;
        proposals[proposalId].numOfParticipants--;
    }

    function tallyVotes(uint256 proposalId)
        public
        override
        onlyAuthorizedCaller(msg.sender)
    {
        // Check if votes have already been tallied
        if (
            proposals[proposalId].winners.length > 0
                || proposals[proposalId].isDraw
        ) {
            revert(string(abi.encodePacked("Votes already tallied for proposal ", _uintToString(proposalId))));
        }

        // Get all options for this proposal
        string[] memory options = proposals[proposalId].options;

        if (options.length == 0) {
            revert(string(abi.encodePacked("No options available for proposal ", _uintToString(proposalId))));
        }

        // Find the maximum vote count
        uint256 maxVotes = 0;
        for (uint256 i = 0; i < options.length; i++) {
            uint256 optionVoteCount = getVoteCount(proposalId, options[i]);
            if (optionVoteCount > maxVotes) maxVotes = optionVoteCount;
        }

        // If no votes were cast, set empty winners
        if (maxVotes == 0) {
            proposals[proposalId].winners = new string[](0);
            proposals[proposalId].isDraw = false;
            return;
        }

        // Count how many options have the maximum votes
        uint256 winnerCount = 0;
        for (uint256 i = 0; i < options.length; i++) {
            if (getVoteCount(proposalId, options[i]) == maxVotes) winnerCount++;
        }

        // Create winners array
        string[] memory winningOptions = new string[](winnerCount);
        uint256 winnerIndex = 0;
        for (uint256 i = 0; i < options.length; i++) {
            if (getVoteCount(proposalId, options[i]) == maxVotes) {
                winningOptions[winnerIndex] = options[i];
                winnerIndex++;
            }
        }

        // Determine if it's a draw (multiple winners with same vote count)
        bool draw = winnerCount > 1;

        // Store the results
        proposals[proposalId].winners = winningOptions;
        proposals[proposalId].isDraw = draw;
    }

    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) public view override returns (uint256) {
        return proposals[proposalId].voteCount[option];
    }

    function getWinners(uint256 proposalId)
        public
        view
        override
        returns (string[] memory, bool)
    {
        return (proposals[proposalId].winners, proposals[proposalId].isDraw);
    }

    function isParticipant(
        uint256 proposalId,
        address voter
    ) external view returns (bool) {
        return proposals[proposalId].isParticipant[voter];
    }

    function decrementProposalCount()
        external
        onlyAuthorizedCaller(msg.sender)
    {
        proposalCount--;
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address owner,
            string memory title,
            string[] memory options,
            uint256 startDate,
            uint256 endDate,
            ProposalStatus status,
            VoteMutability voteMutability
        )
    {
        if (!isProposalExists(proposalId)) {
            revert(string(abi.encodePacked("Proposal does not exist: ", _uintToString(proposalId))));
        }

        owner = proposals[proposalId].owner;
        title = proposals[proposalId].title;
        options = proposals[proposalId].options;
        startDate = proposals[proposalId].startDate;
        endDate = proposals[proposalId].endDate;
        status = proposals[proposalId].status;
        voteMutability = proposals[proposalId].voteMutability;
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    function getParticipantCount(uint256 proposalId)
        external
        view
        returns (uint256)
    {
        return proposals[proposalId].numOfParticipants;
    }

    function optionExists(
        uint256 proposalId,
        string calldata option
    ) external view returns (bool) {
        return proposals[proposalId].optionExistence[option];
    }

    function getProposalOptions(uint256 proposalId)
        external
        view
        returns (string[] memory)
    {
        return proposals[proposalId].options;
    }

    function isProposalExists(uint256 proposalId) public view returns (bool) {
        return proposals[proposalId].id != 0;
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 tempValue = value;
        while (tempValue != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(tempValue % 10)));
            tempValue /= 10;
        }
        return string(buffer);
    }

}
