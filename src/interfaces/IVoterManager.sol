// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IVoterManager
 * @author Suhail Abdelaal
 * @notice Interface for managing voter registration and participation
 * @dev Defines core functionality for voter management and tracking
 */
interface IVoterManager {

    /**
     * @notice Registers a new voter in the system
     * @dev Only authorized callers can register voters
     * @param voter Address of the voter to register
     * @param nid National ID hash of the voter
     * @param embeddings Biometric embeddings for voter verification
     */
    function registerVoter(
        address voter,
        bytes32 nid,
        int256[] memory embeddings
    ) external;

    /**
     * @notice Checks if a national ID is already registered
     * @param nid National ID hash to check
     * @return True if the NID is already registered
     */
    function isNidRegistered(bytes32 nid) external view returns (bool);

    /**
     * @notice Unregisters a voter from the system
     * @dev Only authorized callers can unregister voters
     * @param voter Address of the voter to unregister
     */
    function unRegisterVoter(address voter) external;

    /**
     * @notice Gets all proposals a voter has participated in
     * @param voter Address of the voter
     * @return Array of proposal IDs the voter has participated in
     */
    function getVoterParticipatedProposals(address voter)
        external
        view
        returns (uint256[] memory);

    /**
     * @notice Gets the option selected by a voter in a specific proposal
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     * @return Selected option by the voter
     */
    function getVoterSelectedOption(
        address voter,
        uint256 proposalId
    ) external view returns (string memory);

    /**
     * @notice Gets all proposals created by a voter
     * @param voter Address of the voter
     * @return Array of proposal IDs created by the voter
     */
    function getVoterCreatedProposals(address voter)
        external
        view
        returns (uint256[] memory);

    /**
     * @notice Records a voter's participation in a proposal
     * @dev Only authorized callers can record participation
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     * @param selectedOption Option selected by the voter
     */
    function recordUserParticipation(
        address voter,
        uint256 proposalId,
        string calldata selectedOption
    ) external;

    /**
     * @notice Records a proposal created by a voter
     * @dev Only authorized callers can record proposal creation
     * @param voter Address of the voter
     * @param proposalId ID of the created proposal
     */
    function recordUserCreatedProposal(
        address voter,
        uint256 proposalId
    ) external;

    /**
     * @notice Removes a voter's participation record from a proposal
     * @dev Only authorized callers can remove participation records
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     */
    function removeUserParticipation(
        address voter,
        uint256 proposalId
    ) external;

    /**
     * @notice Removes a proposal created by a voter
     * @dev Only authorized callers can remove proposals
     * @param user Address of the voter
     * @param proposalId ID of the proposal to remove
     */
    function removeUserProposal(address user, uint256 proposalId) external;

    /**
     * @notice Gets the number of proposals a voter has participated in
     * @param voter Address of the voter
     * @return Number of proposals participated in
     */
    function getParticipatedProposalsCount(address voter)
        external
        view
        returns (uint256);

    /**
     * @notice Gets the number of proposals created by a voter
     * @param voter Address of the voter
     * @return Number of proposals created
     */
    function getCreatedProposalsCount(address voter)
        external
        view
        returns (uint256);

    /**
     * @notice Gets the biometric embeddings for a voter
     * @param voter Address of the voter
     * @return Array of biometric embedding values
     */
    function getVoterEmbeddings(address voter)
        external
        view
        returns (int256[] memory);
}
