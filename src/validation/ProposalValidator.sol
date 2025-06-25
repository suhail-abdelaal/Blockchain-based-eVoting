// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IProposalValidator.sol";
import "../interfaces/IProposalState.sol";
import "../access/AccessControlWrapper.sol";

/**
 * @title ProposalValidator
 * @dev Handles all validation logic for proposals and voting
 * Follows Single Responsibility Principle by focusing only on validation
 * Follows Open/Closed Principle by being extensible for new validation rules
 */
contract ProposalValidator is IProposalValidator, AccessControlWrapper {

    IProposalState private proposalState;

    // Validation constants
    uint256 private constant MIN_TITLE_LENGTH = 3;
    uint256 private constant MAX_TITLE_LENGTH = 200;
    uint256 private constant MIN_OPTIONS = 2;
    uint256 private constant MAX_OPTIONS = 10;
    uint256 private constant MIN_VOTING_DURATION = 10 minutes;

    // Custom errors for validation failures
    error InvalidTitle(string reason);
    error InvalidOptions(string reason);
    error InvalidDates(string reason);
    error ProposalNotActive();
    error VoterNotRegistered();
    error InvalidOption();
    error VotingNotAllowed();

    constructor(
        address _accessControl,
        address _proposalState
    ) AccessControlWrapper(_accessControl) {
        proposalState = IProposalState(_proposalState);
    }

    /**
     * @dev Validate proposal creation parameters
     * @param title The proposal title
     * @param options The voting options
     * @param startDate The proposal start date
     * @param endDate The proposal end date
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
     * @dev Validate a vote
     * @param proposalId The proposal ID
     * @param voter The voter address
     * @param option The selected option
     */
    function validateVote(
        uint256 proposalId,
        address voter,
        string memory option
    ) external view override {
        // Check if voter is registered
        if (!accessControl.isVoterVerified(voter)) revert VoterNotRegistered();

        // Check if proposal is active
        if (!proposalState.isProposalActive(proposalId)) {
            revert ProposalNotActive();
        }

        // Check if option exists
        if (!proposalState.optionExists(proposalId, option)) {
            revert InvalidOption();
        }

        // Additional voting rules can be added here
        _validateVotingRules(proposalId, voter);
    }

    /**
     * @dev Validate a vote change
     * @param proposalId The proposal ID
     * @param voter The voter address
     * @param newOption The new selected option
     */
    function validateVoteChange(
        uint256 proposalId,
        address voter,
        string calldata newOption
    ) external view override {
        // Check if voter is registered
        if (!accessControl.isVoterVerified(voter)) revert VoterNotRegistered();

        // Check if proposal allows vote changes
        if (
            proposalState.getProposalVoteMutability(proposalId)
                == IProposalState.VoteMutability.IMMUTABLE
        ) revert VotingNotAllowed();

        // Check if proposal is active
        if (!proposalState.isProposalActive(proposalId)) {
            revert ProposalNotActive();
        }

        // Check if new option exists
        if (!proposalState.optionExists(proposalId, newOption)) {
            revert InvalidOption();
        }
    }

    /**
     * @dev Validate proposal title
     * @param title The proposal title to validate
     */
    function _validateTitle(string calldata title) private pure {
        bytes memory titleBytes = bytes(title);

        if (titleBytes.length < MIN_TITLE_LENGTH) {
            revert InvalidTitle("Title too short");
        }

        if (titleBytes.length > MAX_TITLE_LENGTH) {
            revert InvalidTitle("Title too long");
        }

        // Check for empty or whitespace-only title
        bool hasNonWhitespace = false;
        for (uint256 i = 0; i < titleBytes.length; i++) {
            if (titleBytes[i] != 0x20) {
                // 0x20 is space character
                hasNonWhitespace = true;
                break;
            }
        }

        if (!hasNonWhitespace) {
            revert InvalidTitle("Title cannot be empty or whitespace only");
        }
    }

    /**
     * @dev Validate voting options
     * @param options The voting options to validate
     */
    function _validateOptions(string[] memory options) private pure {
        if (options.length < MIN_OPTIONS) {
            revert InvalidOptions("Not enough options");
        }

        if (options.length > MAX_OPTIONS) {
            revert InvalidOptions("Too many options");
        }

        // Check for duplicate options and empty options
        for (uint256 i = 0; i < options.length; i++) {
            bytes memory option = bytes(options[i]);

            // Check for empty options
            if (option.length == 0) {
                revert InvalidOptions("Empty option not allowed");
            }

            // Check for duplicates
            for (uint256 j = i + 1; j < options.length; j++) {
                if (keccak256(option) == keccak256(bytes(options[j]))) {
                    revert InvalidOptions("Duplicate options not allowed");
                }
            }
        }
    }

    /**
     * @dev Validate proposal dates
     * @param startDate The proposal start date
     * @param endDate The proposal end date
     */
    function _validateDates(uint256 startDate, uint256 endDate) private view {
        // Start date cannot be in the past
        if (startDate < block.timestamp) {
            revert InvalidDates("Start date cannot be in the past");
        }

        // End date must be after start date
        if (endDate <= startDate) {
            revert InvalidDates("End date must be after start date");
        }

        // Check minimum voting duration
        if (endDate - startDate < MIN_VOTING_DURATION) {
            revert InvalidDates("Voting duration too short");
        }
    }

    /**
     * @dev Additional voting rules validation (extensible)
     * @param proposalId The proposal ID
     * @param voter The voter address
     */
    function _validateVotingRules(
        uint256 proposalId,
        address voter
    ) private view {
        // This function can be extended with additional validation rules
        // For example:
        // - Check if voter meets certain criteria
        // - Check proposal-specific voting restrictions
        // - Implement cooling-off periods
        // - Add reputation-based voting rules

        // For now, we'll just ensure basic requirements are met
        // Additional rules can be added here following the Open/Closed
        // Principle
    }

}
