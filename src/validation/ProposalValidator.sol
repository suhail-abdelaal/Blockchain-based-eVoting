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
        if (!accessControl.isVoterVerified(voter)) {
            revert(string(abi.encodePacked("Voter not registered: ", _addressToString(voter))));
        }

        // Check if proposal is active
        if (!proposalState.isProposalActive(proposalId)) {
            revert(string(abi.encodePacked("Proposal not active: ", _uintToString(proposalId))));
        }

        // Check if option exists
        if (!proposalState.optionExists(proposalId, option)) {
            revert(string(abi.encodePacked("Invalid option '", option, "' for proposal ", _uintToString(proposalId))));
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
        if (!accessControl.isVoterVerified(voter)) {
            revert(string(abi.encodePacked("Voter not registered: ", _addressToString(voter))));
        }

        // Check if proposal allows vote changes
        if (
            proposalState.getProposalVoteMutability(proposalId)
                == IProposalState.VoteMutability.IMMUTABLE
        ) {
            revert(string(abi.encodePacked("Vote changes not allowed for proposal ", _uintToString(proposalId), " - immutable voting")));
        }

        // Check if proposal is active
        if (!proposalState.isProposalActive(proposalId)) {
            revert(string(abi.encodePacked("Proposal not active: ", _uintToString(proposalId))));
        }

        // Check if new option exists
        if (!proposalState.optionExists(proposalId, newOption)) {
            revert(string(abi.encodePacked("Invalid option '", newOption, "' for proposal ", _uintToString(proposalId))));
        }
    }

    /**
     * @dev Validate proposal title
     * @param title The proposal title to validate
     */
    function _validateTitle(string calldata title) private pure {
        bytes memory titleBytes = bytes(title);

        if (titleBytes.length < MIN_TITLE_LENGTH) {
            revert(string(abi.encodePacked("Title too short: ", _uintToString(titleBytes.length), " characters (minimum ", _uintToString(MIN_TITLE_LENGTH), ")")));
        }

        if (titleBytes.length > MAX_TITLE_LENGTH) {
            revert(string(abi.encodePacked("Title too long: ", _uintToString(titleBytes.length), " characters (maximum ", _uintToString(MAX_TITLE_LENGTH), ")")));
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
            revert("Title cannot be empty or contain only whitespace characters");
        }
    }

    /**
     * @dev Validate voting options
     * @param options The voting options to validate
     */
    function _validateOptions(string[] memory options) private pure {
        if (options.length < MIN_OPTIONS) {
            revert(string(abi.encodePacked("Not enough options: ", _uintToString(options.length), " provided (minimum ", _uintToString(MIN_OPTIONS), ")")));
        }

        if (options.length > MAX_OPTIONS) {
            revert(string(abi.encodePacked("Too many options: ", _uintToString(options.length), " provided (maximum ", _uintToString(MAX_OPTIONS), ")")));
        }

        // Check for duplicate options and empty options
        for (uint256 i = 0; i < options.length; i++) {
            bytes memory option = bytes(options[i]);

            // Check for empty options
            if (option.length == 0) {
                revert(string(abi.encodePacked("Empty option not allowed at index ", _uintToString(i))));
            }

            // Check for duplicates
            for (uint256 j = i + 1; j < options.length; j++) {
                if (keccak256(option) == keccak256(bytes(options[j]))) {
                    revert(string(abi.encodePacked("Duplicate option '", options[i], "' found at indices ", _uintToString(i), " and ", _uintToString(j))));
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
            revert(string(abi.encodePacked("Start date cannot be in the past: ", _uintToString(startDate), " < ", _uintToString(block.timestamp))));
        }

        // End date must be after start date
        if (endDate <= startDate) {
            revert(string(abi.encodePacked("End date must be after start date: ", _uintToString(endDate), " <= ", _uintToString(startDate))));
        }

        // Check minimum voting duration
        if (endDate - startDate < MIN_VOTING_DURATION) {
            revert(string(abi.encodePacked("Voting duration too short: ", _uintToString(endDate - startDate), " seconds (minimum ", _uintToString(MIN_VOTING_DURATION), ")")));
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

    /**
     * @dev Convert address to string
     */
    function _addressToString(address addr) private pure returns (string memory) {
        return _toHexString(uint256(uint160(addr)), 20);
    }

    /**
     * @dev Convert uint to string
     */
    function _uintToString(uint256 value) private pure returns (string memory) {
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

    /**
     * @dev Convert to hex string
     */
    function _toHexString(uint256 value, uint256 length) private pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        uint256 tempValue = value;
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[tempValue & 0xf];
            tempValue >>= 4;
        }
        require(tempValue == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

}
