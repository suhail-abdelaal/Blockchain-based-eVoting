// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IProposalManager.sol";
import "../interfaces/IProposalValidator.sol";
import "../interfaces/IProposalState.sol";
import "../interfaces/IVoterManager.sol";
import "../access/AccessControlWrapper.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ProposalOrchestrator is IProposalManager, AccessControlWrapper {
    using Strings for uint256;
    using Strings for address;

    IProposalValidator private validator;
    IProposalState private proposalState;
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
        address _voterManager
    ) AccessControlWrapper(_accessControl) {
        validator = IProposalValidator(_validator);
        proposalState = IProposalState(_proposalState);
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
            revert(string(abi.encodePacked("Vote already cast by voter ", voter.toHexString(), " for proposal ", proposalId.toString())));
        }

        if (!proposalState.optionExists(proposalId, option)) {
            revert(string(abi.encodePacked("Invalid option '", option, "' for proposal ", proposalId.toString())));
        }

        proposalState.addParticipant(proposalId, voter);
        proposalState.incrementVoteCount(proposalId, option);
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
            revert(string(abi.encodePacked("Voter ", voter.toHexString(), " has not participated in proposal ", proposalId.toString())));
        }

        if (
            proposalState.getProposalVoteMutability(proposalId)
                == IProposalState.VoteMutability.IMMUTABLE
        ) {
            revert(string(abi.encodePacked("Cannot retract vote for proposal ", proposalId.toString(), " - immutable voting enabled")));
        }

        string memory option =
            voterManager.getVoterSelectedOption(voter, proposalId);

        proposalState.removeParticipant(proposalId, voter);
        proposalState.decrementVoteCount(proposalId, option);
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
        ) {
            revert(string(abi.encodePacked("New option '", newOption, "' is identical to current option '", previousOption, "' for voter ", voter.toHexString(), " in proposal ", proposalId.toString())));
        }

        proposalState.decrementVoteCount(proposalId, previousOption);
        proposalState.incrementVoteCount(proposalId, newOption);
        voterManager.removeUserParticipation(voter, proposalId);
        voterManager.recordUserParticipation(voter, proposalId, newOption);

        emit VoteChanged(proposalId, voter, previousOption, newOption);
    }

    function removeUserProposal(
        address user,
        uint256 proposalId
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (proposalState.getParticipantCount(proposalId) > 0) {
            revert(string(abi.encodePacked("Cannot remove proposal ", proposalId.toString(), " - has active participants (", proposalState.getParticipantCount(proposalId).toString(), " participants)")));
        }

        voterManager.removeUserProposal(user, proposalId);
        proposalState.decrementProposalCount();
        emit ProposalDeleted(proposalId);
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view override returns (uint256) {
        return proposalState.getVoteCount(proposalId, option);
    }


    function updateProposalStatus(uint256 proposalId) external override {
        proposalState.updateProposalStatus(proposalId);
    }

    function getProposalDetails(uint256 proposalId)
        external
        view
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
            revert(string(abi.encodePacked("Proposal does not exist: ", proposalId.toString())));
        }

        (owner, title, options, startDate, endDate, status, voteMutability) =
            proposalState.getProposal(proposalId);

        // Get winners and draw status if proposal is closed
        if (
            proposalState.getProposalStatus(proposalId)
                == IProposalState.ProposalStatus.CLOSED
        ) {
            (winners, isDraw) = proposalState.getWinners(proposalId);
        } else {
            winners = new string[](0);
            isDraw = false;
        }
    }

    function getProposalCount() external view override returns (uint256) {
        return proposalState.getProposalCount();
    }

    function getProposalWinnersWithUpdate(uint256 proposalId)
        external
        override
        returns (string[] memory winners, bool isDraw)
    {
        proposalState.updateProposalStatus(proposalId);
        return proposalState.getWinners(proposalId);
    }

    function getProposalWinners(uint256 proposalId)
        external
        view
        returns (string[] memory winners, bool isDraw)
    {
        return proposalState.getWinners(proposalId);
    }

    function authorizeContracts() external onlyAdmin {
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(accessControl)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(validator)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(proposalState)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(voterManager)
        );
    }



}
