// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./interfaces/IAccessControlManager.sol";
import "./interfaces/IProposalManager.sol";
import "./interfaces/IVoterManager.sol";
import "./access/AccessControlWrapper.sol";

/**
 * @title VotingFacade
 * @author Suhail Abdelaal
 * @notice Main entry point for the voting system
 * @dev Implements the Facade pattern to provide a simplified interface to the voting system
 */
contract VotingFacade is AccessControlWrapper {

    IProposalManager private immutable proposalManager;
    IVoterManager private immutable voterManager;

    /**
     * @notice Initializes the VotingFacade contract
     * @param _accessControl Address of the access control contract
     * @param _voterManager Address of the voter manager contract
     * @param _proposalManager Address of the proposal manager contract
     */
    constructor(
        address _accessControl,
        address _voterManager,
        address _proposalManager
    ) AccessControlWrapper(_accessControl) {
        voterManager = IVoterManager(_voterManager);
        proposalManager = IProposalManager(_proposalManager);
    }

    /**
     * @notice Creates a new proposal
     * @param title Title of the proposal
     * @param options Array of voting options
     * @param voteMutability Whether votes can be changed after casting
     * @param startTime Timestamp when voting begins
     * @param endTime Timestamp when voting ends
     * @return proposalId Unique identifier of the created proposal
     */
    function createProposal(
        string calldata title,
        string[] memory options,
        IProposalState.VoteMutability voteMutability,
        uint256 startTime,
        uint256 endTime
    ) external onlyVerifiedVoter returns (uint256) {
        return proposalManager.createProposal(
            msg.sender, title, options, voteMutability, startTime, endTime
        );
    }

    /**
     * @notice Casts a vote for a specific option in a proposal
     * @param proposalId ID of the target proposal
     * @param option Selected voting option
     */
    function castVote(
        uint256 proposalId,
        string memory option
    ) external onlyVerifiedVoter {
        proposalManager.castVote(msg.sender, proposalId, option);
    }

    /**
     * @notice Retracts a previously cast vote
     * @param proposalId ID of the target proposal
     */
    function retractVote(uint256 proposalId) external onlyVerifiedVoter {
        proposalManager.retractVote(msg.sender, proposalId);
    }

    /**
     * @notice Changes a previously cast vote to a new option
     * @param proposalId ID of the target proposal
     * @param newOption New voting option
     */
    function changeVote(
        uint256 proposalId,
        string memory newOption
    ) external onlyVerifiedVoter {
        proposalManager.changeVote(msg.sender, proposalId, newOption);
    }

    /**
     * @notice Grants a role to an account
     * @param role Role identifier
     * @param account Address to grant the role to
     */
    function grantRole(bytes32 role, address account) external onlyAdmin {
        accessControl.grantRole(role, account);
    }

    /**
     * @notice Revokes a role from an account
     * @param role Role identifier
     * @param account Address to revoke the role from
     */
    function revokeRole(bytes32 role, address account) external onlyAdmin {
        accessControl.revokeRole(role, account);
    }

    /**
     * @notice Verifies a voter
     * @param voter Address to verify
     */
    function verifyVoter(address voter) external onlyAuthorizedCaller(msg.sender) {
        accessControl.verifyVoter(voter);
    }

    /**
     * @notice Removes a proposal
     * @param proposalId ID of the proposal to remove
     */
    function removeProposal(uint256 proposalId) external onlyVerifiedVoter {
        proposalManager.removeUserProposal(msg.sender, proposalId);
    }

    /**
     * @notice Removes a proposal with admin privileges
     * @param user Address of the proposal creator
     * @param proposalId ID of the proposal to remove
     */
    function removeProposalWithAdmin(address user, uint256 proposalId) external onlyAdmin {
        proposalManager.removeProposalWithAdmin(user, proposalId);
    }

    /**
     * @notice Gets the vote count for a specific option
     * @param proposalId ID of the target proposal
     * @param option Option to get votes for
     * @return Number of votes for the option
     */
    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) external view returns (uint256) {
        return proposalManager.getVoteCount(proposalId, option);
    }

    /**
     * @notice Gets the total number of proposals
     * @return Total number of proposals in the system
     */
    function getProposalCount() external view returns (uint256) {
        return proposalManager.getProposalCount();
    }

    /**
     * @notice Gets the winning options for a proposal
     * @param proposalId ID of the target proposal
     * @return winners Array of winning options
     * @return isDraw Whether there is a tie among winners
     */
    function getProposalWinners(uint256 proposalId)
        external
        view
        returns (string[] memory winners, bool isDraw)
    {
        return proposalManager.getProposalWinners(proposalId);
    }

    /**
     * @notice Registers a new voter
     * @param voter Address to register
     * @param nid National ID hash
     * @param embeddings Biometric embeddings for verification
     */
    function registerVoter(
        address voter,
        bytes32 nid,
        int256[] memory embeddings
    ) external onlyAdmin {
        voterManager.registerVoter(voter, nid, embeddings);
        accessControl.verifyVoter(voter);
    }

    /**
     * @notice Unregisters a voter
     * @param voter Address to unregister
     */
    function unRegisterVoter(address voter) external onlyAdmin {
        voterManager.unRegisterVoter(voter);
        accessControl.revokeVoterVerification(voter);
    }

    /**
     * @notice Checks if a national ID is registered
     * @param nid National ID hash to check
     * @return True if the NID is registered
     */
    function isNidRegistered(bytes32 nid) external view returns (bool) {
        return voterManager.isNidRegistered(nid);
    }

    /**
     * @notice Gets all proposals a voter has participated in
     * @return Array of proposal IDs the voter has participated in
     */
    function getVoterParticipatedProposals()
        external
        view
        returns (uint256[] memory)
    {
        return voterManager.getVoterParticipatedProposals(msg.sender);
    }

    /**
     * @notice Gets all proposals created by a voter
     * @return Array of proposal IDs created by the voter
     */
    function getVoterCreatedProposals()
        external
        view
        returns (uint256[] memory)
    {
        return voterManager.getVoterCreatedProposals(msg.sender);
    }

    /**
     * @notice Gets the option selected by a voter in a proposal
     * @param proposalId ID of the target proposal
     * @return Selected option by the voter
     */
    function getVoterSelectedOption(uint256 proposalId)
        external
        view
        returns (string memory)
    {
        return voterManager.getVoterSelectedOption(msg.sender, proposalId);
    }

    /**
     * @notice Updates the status of a proposal
     * @param proposalId ID of the target proposal
     */
    function updateProposalStatus(uint256 proposalId) external {
        proposalManager.updateProposalStatus(proposalId);
    }

    /**
     * @notice Checks if a proposal has been finalized
     * @param proposalId ID of the target proposal
     * @return True if the proposal is finalized
     */
    function isProposalFinalized(uint256 proposalId) external view returns (bool) {
        return proposalManager.isProposalFinalized(proposalId);
    }

    /**
     * @notice Checks if a proposal exists
     * @param proposalId ID of the target proposal
     * @return True if the proposal exists
     */
    function isProposalExists(uint256 proposalId) external view returns (bool) {
        return proposalManager.isProposalExists(proposalId);
    }

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
        onlyVerifiedAddr(msg.sender)
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
        return proposalManager.getProposalDetails(proposalId);
    }

    /**
     * @notice Gets the biometric embeddings for the caller
     * @return Array of biometric embedding values
     */
    function getVoterEmbeddings() external view returns (int256[] memory) {
        return voterManager.getVoterEmbeddings(msg.sender);
    }

    /**
     * @notice Fallback function
     * @dev Reverts all calls to prevent accidental Ether transfers
     */
    fallback() external payable {
        revert("Fallback function called");
    }

    /**
     * @notice Receive function
     * @dev Reverts all Ether transfers
     */
    receive() external payable {
        revert("Receive function called");
    }
}
