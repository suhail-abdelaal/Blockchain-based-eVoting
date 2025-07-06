// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IProposalState
 * @author Suhail Abdelaal
 * @notice Interface for managing proposal state and lifecycle
 * @dev Defines core functionality for proposal state management and vote tracking
 */
interface IProposalState {

    /**
     * @notice Enum representing the possible states of a proposal
     * @dev NONE is used as a default state for non-existent proposals
     */
    enum ProposalStatus {
        NONE,       // Default state for non-existent proposals
        PENDING,    // Created but not yet active
        ACTIVE,     // Currently accepting votes
        CLOSED,     // Voting period ended
        FINALIZED   // Results tallied and winners determined
    }

    /**
     * @notice Enum representing whether votes can be changed after casting
     */
    enum VoteMutability {
        IMMUTABLE,  // Votes cannot be changed once cast
        MUTABLE     // Votes can be changed after casting
    }

    /**
     * @notice Creates a new proposal in the system
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
        VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256);

    /**
     * @notice Removes a proposal from the system
     * @param proposalId ID of the proposal to remove
     */
    function removeProposal(uint256 proposalId) external;

    /**
     * @notice Gets the current status of a proposal
     * @param proposalId ID of the target proposal
     * @return Current status of the proposal
     */
    function getProposalStatus(uint256 proposalId)
        external
        view
        returns (ProposalStatus);

    /**
     * @notice Gets and updates the current status of a proposal
     * @param proposalId ID of the target proposal
     * @return Current status after update
     */
    function getCurrentProposalStatus(uint256 proposalId)
        external
        returns (ProposalStatus);

    /**
     * @notice Updates the status of a proposal based on current time
     * @param proposalId ID of the target proposal
     */
    function updateProposalStatus(uint256 proposalId) external;

    /**
     * @notice Gets the vote mutability setting of a proposal
     * @param proposalId ID of the target proposal
     * @return Vote mutability setting
     */
    function getProposalVoteMutability(uint256 proposalId)
        external
        view
        returns (VoteMutability);

    /**
     * @notice Checks if a proposal is currently active
     * @param proposalId ID of the target proposal
     * @return True if the proposal is active
     */
    function isProposalActive(uint256 proposalId)
        external
        view
        returns (bool);

    /**
     * @notice Checks if a proposal is closed
     * @param proposalId ID of the target proposal
     * @return True if the proposal is closed
     */
    function isProposalClosed(uint256 proposalId)
        external
        view
        returns (bool);

    /**
     * @notice Checks if an address has participated in a proposal
     * @param proposalId ID of the target proposal
     * @param voter Address to check
     * @return True if the address has participated
     */
    function isParticipant(
        uint256 proposalId,
        address voter
    ) external view returns (bool);

    /**
     * @notice Checks if a voting option exists for a proposal
     * @param proposalId ID of the target proposal
     * @param option Option to check
     * @return True if the option exists
     */
    function optionExists(
        uint256 proposalId,
        string calldata option
    ) external view returns (bool);

    /**
     * @notice Adds a participant to a proposal
     * @param proposalId ID of the target proposal
     * @param voter Address of the participant
     */
    function addParticipant(uint256 proposalId, address voter) external;

    /**
     * @notice Removes a participant from a proposal
     * @param proposalId ID of the target proposal
     * @param voter Address of the participant
     */
    function removeParticipant(uint256 proposalId, address voter) external;

    /**
     * @notice Decrements the total proposal count
     */
    function decrementProposalCount() external;

    /**
     * @notice Increments the vote count for an option
     * @param proposalId ID of the target proposal
     * @param option Option to increment votes for
     */
    function incrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external;

    /**
     * @notice Decrements the vote count for an option
     * @param proposalId ID of the target proposal
     * @param option Option to decrement votes for
     */
    function decrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external;

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
     */
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
        );

    /**
     * @notice Gets the total number of proposals
     * @return Total number of proposals in the system
     */
    function getProposalCount() external view returns (uint256);

    /**
     * @notice Gets the number of participants in a proposal
     * @param proposalId ID of the target proposal
     * @return Number of participants
     */
    function getParticipantCount(uint256 proposalId)
        external
        view
        returns (uint256);

    /**
     * @notice Gets the voting options for a proposal
     * @param proposalId ID of the target proposal
     * @return Array of voting options
     */
    function getProposalOptions(uint256 proposalId)
        external
        view
        returns (string[] memory);

    /**
     * @notice Checks if a proposal exists
     * @param proposalId ID of the target proposal
     * @return True if the proposal exists
     */
    function isProposalExists(uint256 proposalId)
        external
        view
        returns (bool);

    /**
     * @notice Tallies the votes for a proposal
     * @param proposalId ID of the target proposal
     */
    function tallyVotes(uint256 proposalId) external;

    /**
     * @notice Gets the vote count for a specific option
     * @param proposalId ID of the target proposal
     * @param option Option to get votes for
     * @return Number of votes for the option
     */
    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) external view returns (uint256);

    /**
     * @notice Gets the winning options for a proposal
     * @param proposalId ID of the target proposal
     * @return winners Array of winning options
     * @return isDraw Whether there is a tie among winners
     */
    function getWinners(uint256 proposalId)
        external
        view
        returns (string[] memory, bool);

    /**
     * @notice Checks if a proposal has been finalized
     * @param proposalId ID of the target proposal
     * @return True if the proposal is finalized
     */
    function isProposalFinalized(uint256 proposalId) external view returns (bool);
}
