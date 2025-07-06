// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IProposalValidator
 * @dev Interface for proposal validation operations
 * Follows Interface Segregation Principle by containing only validation-related
 * functions
 */
interface IProposalValidator {

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
    ) external view;

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
    ) external view;

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
    ) external view;

}
