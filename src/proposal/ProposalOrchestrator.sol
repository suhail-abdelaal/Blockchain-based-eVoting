// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IProposalManager.sol";
import "../interfaces/IProposalValidator.sol";
import "../interfaces/IProposalState.sol";
import "../interfaces/IVoteTallying.sol";
import "../interfaces/IVoterManager.sol";
import "../access/AccessControlWrapper.sol";

contract ProposalOrchestrator is IProposalManager, AccessControlWrapper {

    IProposalValidator private validator;
    IProposalState private proposalState;
    IVoteTallying private voteTallying;
    IVoterManager private voterManager;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed owner,
        string title,
        uint256 startDate,
        uint256 endDate
    );
    event ProposalDeleted(uint256 indexed proposalId);
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

    constructor(
        address _accessControl,
        address _validator,
        address _proposalState,
        address _voteTallying,
        address _voterManager
    ) AccessControlWrapper(_accessControl) {
        validator = IProposalValidator(_validator);
        proposalState = IProposalState(_proposalState);
        voteTallying = IVoteTallying(_voteTallying);
        voterManager = IVoterManager(_voterManager);
    }

    function createProposal(
        address creator,
        string calldata title,
        string[] memory options,
        IProposalState.VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    )
        external
        override
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(creator)
        returns (uint256)
    {
        validator.validateProposalCreation(title, options, startDate, endDate);

        uint256 proposalId = proposalState.createProposal(
            creator, title, options, voteMutability, startDate, endDate
        );
        voterManager.recordUserCreatedProposal(creator, proposalId);

        emit ProposalCreated(proposalId, creator, title, startDate, endDate);
        return proposalId;
    }

    function castVote(
        address voter,
        uint256 proposalId,
        string memory option
    )
        external
        override
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(voter)
    {
        // Update proposal status first to ensure it's current
        proposalState.updateProposalStatus(proposalId);

        validator.validateVote(proposalId, voter, option);

        if (proposalState.isParticipant(proposalId, voter)) {
            revert("VoteAlreadyCast");
        }

        if (!proposalState.optionExists(proposalId, option)) {
            revert("InvalidOption");
        }

        proposalState.addParticipant(proposalId, voter);
        voteTallying.incrementVoteCount(proposalId, option);
        voterManager.recordUserParticipation(voter, proposalId, option);

        emit VoteCast(proposalId, voter, option);
    }

    function retractVote(
        address voter,
        uint256 proposalId
    )
        external
        override
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(voter)
    {
        // Update proposal status first to ensure it's current
        proposalState.updateProposalStatus(proposalId);

        if (!proposalState.isParticipant(proposalId, voter)) {
            revert("VoterNotParticipated");
        }

        if (
            proposalState.getProposalVoteMutability(proposalId)
                == IProposalState.VoteMutability.IMMUTABLE
        ) revert("ImmutableVote");

        string memory option =
            voterManager.getVoterSelectedOption(voter, proposalId);

        proposalState.removeParticipant(proposalId, voter);
        voteTallying.decrementVoteCount(proposalId, option);
        voterManager.removeUserParticipation(voter, proposalId);

        emit VoteRetracted(proposalId, voter, option);
    }

    function changeVote(
        address voter,
        uint256 proposalId,
        string calldata newOption
    )
        external
        override
        onlyAuthorizedCaller(msg.sender)
        onlyVerifiedAddr(voter)
    {
        // Update proposal status first to ensure it's current
        proposalState.updateProposalStatus(proposalId);

        validator.validateVoteChange(proposalId, voter, newOption);

        if (!proposalState.isParticipant(proposalId, voter)) {
            revert("Voter not participated");
        }

        string memory previousOption =
            voterManager.getVoterSelectedOption(voter, proposalId);

        if (
            keccak256(abi.encodePacked(previousOption))
                == keccak256(abi.encodePacked(newOption))
        ) revert("Vote option identical");

        voteTallying.decrementVoteCount(proposalId, previousOption);
        voteTallying.incrementVoteCount(proposalId, newOption);
        voterManager.removeUserParticipation(voter, proposalId);
        voterManager.recordUserParticipation(voter, proposalId, newOption);

        emit VoteChanged(proposalId, voter, previousOption, newOption);
    }
    

    function removeUserProposal(
        address user,
        uint256 proposalId
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (proposalState.getParticipantCount(proposalId) > 0) {
            revert("ProposalHasActiveParticipants");
        }

        voterManager.removeUserProposal(user, proposalId);
        proposalState.decrementProposalCount();
        emit ProposalDeleted(proposalId);
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view override returns (uint256) {
        return voteTallying.getVoteCount(proposalId, option);
    }

    function getProposalDetails(uint256 proposalId)
        external
        override
        returns (
            address owner,
            string memory title,
            string[] memory options,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        )
    {
        // Check if proposal exists
        if (!proposalState.isProposalExists(proposalId)) {
            revert("Proposal does not exist");
        }

        // Update proposal status first to ensure it's current
        proposalState.updateProposalStatus(proposalId);

        (owner, title, options, startDate, endDate, status, voteMutability) =
            proposalState.getProposal(proposalId);

        // Get winners and draw status if proposal is closed
        if (
            proposalState.getProposalStatus(proposalId)
                == IProposalState.ProposalStatus.FINALIZED
        ) (winners, isDraw) = voteTallying.getWinningOptions(proposalId);
        else (new string[](0), false);
    }

    function getProposalCount() external view override returns (uint256) {
        return proposalState.getProposalCount();
    }

    function getProposalWinner(uint256 proposalId)
        external
        override
        returns (string[] memory winners, bool isDraw)
    {
        // Update proposal status first to ensure it's current
        proposalState.updateProposalStatus(proposalId);

        // Check if proposal is closed
        if (!proposalState.isProposalClosed(proposalId)) {
            revert("ProposalNotClosed");
        }

        // Get all options for this proposal
        string[] memory options = proposalState.getProposalOptions(proposalId);

        // Find the maximum vote count
        uint256 maxVotes = 0;
        for (uint256 i = 0; i < options.length; i++) {
            uint256 voteCount =
                voteTallying.getVoteCount(proposalId, options[i]);
            if (voteCount > maxVotes) maxVotes = voteCount;
        }

        // Count how many options have the maximum votes
        uint256 winnerCount = 0;
        for (uint256 i = 0; i < options.length; i++) {
            if (voteTallying.getVoteCount(proposalId, options[i]) == maxVotes) {
                winnerCount++;
            }
        }

        // Create the winners array
        winners = new string[](winnerCount);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < options.length; i++) {
            if (voteTallying.getVoteCount(proposalId, options[i]) == maxVotes) {
                winners[currentIndex] = options[i];
                currentIndex++;
            }
        }

        // Determine if it's a draw
        isDraw = winnerCount > 1;

        // Store the results for future queries
        voteTallying.setWinners(proposalId, winners, isDraw);

        return (winners, isDraw);
    }

    function authorizeContracts() external onlyAdmin {
        accessControl.grantRole(accessControl.getAUTHORIZED_CALLER_ROLE(), address(accessControl));
        accessControl.grantRole(accessControl.getAUTHORIZED_CALLER_ROLE(), address(voterManager));
        accessControl.grantRole(accessControl.getAUTHORIZED_CALLER_ROLE(), address(proposalState));
        accessControl.grantRole(accessControl.getAUTHORIZED_CALLER_ROLE(), address(voteTallying));
        accessControl.grantRole(accessControl.getAUTHORIZED_CALLER_ROLE(), address(validator));
        accessControl.grantRole(accessControl.getAUTHORIZED_CALLER_ROLE(), address(this));
    }


}
