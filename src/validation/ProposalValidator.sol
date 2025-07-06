// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IProposalValidator.sol";
import "../interfaces/IProposalState.sol";
import "../access/AccessControlWrapper.sol";

/**
 * @title ProposalValidator
 * @author Suhail Abdelaal
 * @notice Handles validation of proposal creation and voting operations
 * @dev Follows Single Responsibility Principle by focusing only on validation
 */
contract ProposalValidator is IProposalValidator, AccessControlWrapper {

    IProposalState private proposalState;

    // Validation constants
    uint256 private constant MIN_TITLE_LENGTH = 3;
    uint256 private constant MAX_TITLE_LENGTH = 200;
    uint256 private constant MIN_OPTIONS = 2;
    uint256 private constant MAX_OPTIONS = 10;
    uint256 private constant MIN_VOTING_DURATION = 10 minutes;

    /**
     * @notice Initializes the ProposalValidator contract
     * @param _accessControl Address of the access control contract
     * @param _proposalState Address of the proposal state contract
     */
    constructor(
        address _accessControl,
        address _proposalState
    ) AccessControlWrapper(_accessControl) {
        proposalState = IProposalState(_proposalState);
    }

    /**
     * @notice Validates proposal creation parameters
     * @dev Checks title length, number of options, and voting duration
     * @param title The proposal title
     * @param options Array of voting options
     * @param startDate Timestamp when voting begins
     * @param endDate Timestamp when voting ends
     */
    function validateProposalCreation(
        string calldata title,
        string[] memory options,
        uint256 startDate,
        uint256 endDate
    ) external view override {
        _validateTitle(title);
        _validateOptions(options);
        _validateDates(startDate, endDate);
    }

    /**
     * @notice Validates a vote
     * @dev Checks if proposal exists, is active, and option is valid
     * @param proposalId ID of the target proposal
     * @param voter Address of the voter
     * @param option Selected voting option
     */
    function validateVote(
        uint256 proposalId,
        address voter,
        string memory option
    ) external view override {
        if (!proposalState.isProposalExists(proposalId)) {
            revert("Proposal does not exist");
        }

        if (!proposalState.isProposalActive(proposalId)) {
            revert("Proposal is not active");
        }

        if (!proposalState.optionExists(proposalId, option)) {
            revert("Invalid option");
        }
    }

    /**
     * @notice Validates a vote change
     * @dev Checks if proposal exists, is active, vote is mutable, and option is valid
     * @param proposalId ID of the target proposal
     * @param voter Address of the voter
     * @param newOption New selected option
     */
    function validateVoteChange(
        uint256 proposalId,
        address voter,
        string calldata newOption
    ) external view override {
        if (!proposalState.isProposalExists(proposalId)) {
            revert("Proposal does not exist");
        }

        if (!proposalState.isProposalActive(proposalId)) {
            revert("Proposal is not active");
        }

        if (
            proposalState.getProposalVoteMutability(proposalId)
                == IProposalState.VoteMutability.IMMUTABLE
        ) {
            revert("Vote is immutable");
        }

        if (!proposalState.isParticipant(proposalId, voter)) {
            revert("Voter has not participated");
        }

        if (!proposalState.optionExists(proposalId, newOption)) {
            revert("Invalid option");
        }
    }

    /**
     * @notice Validates the proposal title
     * @dev Checks if title length is within allowed range
     * @param title The proposal title to validate
     */
    function _validateTitle(string calldata title) internal pure {
        bytes memory titleBytes = bytes(title);
        if (titleBytes.length < MIN_TITLE_LENGTH) {
            revert("Title too short");
        }
        if (titleBytes.length > MAX_TITLE_LENGTH) {
            revert("Title too long");
        }
    }

    /**
     * @notice Validates the voting options
     * @dev Checks if number of options is within allowed range
     * @param options Array of voting options to validate
     */
    function _validateOptions(string[] memory options) internal pure {
        if (options.length < MIN_OPTIONS) {
            revert("Too few options");
        }
        if (options.length > MAX_OPTIONS) {
            revert("Too many options");
        }

        for (uint256 i = 0; i < options.length; i++) {
            if (bytes(options[i]).length == 0) {
                revert("Empty option not allowed");
            }
        }
    }

    /**
     * @notice Validates the voting dates
     * @dev Checks if dates are valid and voting duration is sufficient
     * @param startDate Timestamp when voting begins
     * @param endDate Timestamp when voting ends
     */
    function _validateDates(uint256 startDate, uint256 endDate) internal view {
        if (startDate < block.timestamp) {
            revert("Start date must be in the future");
        }

        if (endDate <= startDate) {
            revert("End date must be after start date");
        }

        if (endDate - startDate < MIN_VOTING_DURATION) {
            revert("Voting duration too short");
        }
    }

}
