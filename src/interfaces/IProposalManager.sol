// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./IProposalState.sol";

/**
 * @title IProposalManager
 * @author Suhail Abdelaal
 * @notice Interface for managing proposal lifecycle and voting operations
 * @dev Defines core functionality for proposal creation, voting, and management
 */
interface IProposalManager {

    /**
     * @notice Creates a new proposal
     * @dev Only authorized callers can create proposals
     * @param creator Address of the proposal creator
     * @param title Title of the proposal
     * @param options Array of voting options
     * @param voteMutability Whether votes can be changed after casting
     * @param startDate Timestamp when voting begins
     * @param endDate Timestamp when voting ends
     * @return proposalId Unique identifier of the created proposal
     */
    function createProposal(
        address creator,
        string calldata title,
        string[] memory options,
        IProposalState.VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256);

    /**
     * @notice Casts a vote for a specific option in a proposal
     * @dev Only authorized callers can cast votes
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     * @param option Selected voting option
     */
    function castVote(
        address voter,
        uint256 proposalId,
        string memory option
    ) external;

    /**
     * @notice Retracts a previously cast vote
     * @dev Only authorized callers can retract votes
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     */
    function retractVote(address voter, uint256 proposalId) external;

    /**
     * @notice Changes a previously cast vote to a new option
     * @dev Only authorized callers can change votes
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     * @param newOption New voting option
     */
    function changeVote(
        address voter,
        uint256 proposalId,
        string calldata newOption
    ) external;

    /**
     * @notice Removes a proposal created by a user
     * @dev Only authorized callers can remove proposals
     * @param user Address of the proposal creator
     * @param proposalId ID of the proposal to remove
     */
    function removeUserProposal(address user, uint256 proposalId) external;

    /**
     * @notice Removes a proposal with admin privileges
     * @dev Only authorized callers with admin rights can remove proposals
     * @param user Address of the proposal creator
     * @param proposalId ID of the proposal to remove
     */
    function removeProposalWithAdmin(address user, uint256 proposalId) external;

    /**
     * @notice Gets the vote count for a specific option in a proposal
     * @param proposalId ID of the target proposal
     * @param option Voting option to count
     * @return Number of votes for the specified option
     */
    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view returns (uint256);

    /**
     * @notice Gets detailed information about a proposal
     * @param proposalId ID of the target proposal
     * @return owner Address of the proposal creator
     * @return title Title of the proposal
     * @return options Array of voting options
     * @return startDate Timestamp when voting begins
     * @return endDate Timestamp when voting ends
     * @return status Current status of the proposal
     * @return voteMutability Whether votes can be changed
     * @return winners Array of winning options
     * @return isDraw Whether there is a tie among winners
     */
    function getProposalDetails(uint256 proposalId)
        external
        view
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
        );

    /**
     * @notice Updates the status of a proposal based on current time
     * @param proposalId ID of the target proposal
     */
    function updateProposalStatus(uint256 proposalId) external;

    /**
     * @notice Gets the total number of proposals
     * @return Total number of proposals in the system
     */
    function getProposalCount() external view returns (uint256);

    /**
     * @notice Gets the winning options for a proposal
     * @param proposalId ID of the target proposal
     * @return winners Array of winning options
     * @return isDraw Whether there is a tie among winners
     */
    function getProposalWinners(uint256 proposalId)
        external
        view
        returns (string[] memory winners, bool isDraw);

    /**
     * @notice Checks if a proposal has been finalized
     * @param proposalId ID of the target proposal
     * @return True if the proposal is finalized
     */
    function isProposalFinalized(uint256 proposalId) external view returns (bool);

    /**
     * @notice Checks if a proposal exists
     * @param proposalId ID of the target proposal
     * @return True if the proposal exists
     */
    function isProposalExists(uint256 proposalId) external view returns (bool);
}
