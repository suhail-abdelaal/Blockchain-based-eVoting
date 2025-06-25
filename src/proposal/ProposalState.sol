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
        mapping(string => bool) optionExistence;
        ProposalStatus status;
        VoteMutability voteMutability;
        mapping(address => bool) isParticipant;
        uint256 numOfParticipants;
        uint256 startDate;
        uint256 endDate;
    }

    mapping(uint256 => Proposal) private proposals;
    uint256 private proposalCount;
    uint256 private id;

    event ProposalStatusUpdated(
        uint256 indexed proposalId, ProposalStatus status
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

    function isParticipant(
        uint256 proposalId,
        address voter
    ) external view returns (bool) {
        return proposals[proposalId].isParticipant[voter];
    }

    function decrementProposalCount() external onlyAuthorizedCaller(msg.sender) {
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
        if (!isProposalExists(proposalId)) revert("ProposalDoesNotExist");

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

}
