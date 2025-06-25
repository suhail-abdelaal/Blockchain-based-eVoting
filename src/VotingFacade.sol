// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./interfaces/IVotingSystem.sol";
import "./interfaces/IAccessControlManager.sol";
import "./interfaces/IProposalManager.sol";
import "./interfaces/IVoterManager.sol";
import "./access/AccessControlWrapper.sol";

contract VotingFacade is AccessControlWrapper {

    IProposalManager private immutable proposalManager;
    IVoterManager private immutable voterManager;

    constructor(
        address _accessControl,
        address _voterManager,
        address _proposalManager
    ) AccessControlWrapper(_accessControl) {
        voterManager = IVoterManager(_voterManager);
        proposalManager = IProposalManager(_proposalManager);
    }

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

    function castVote(uint256 proposalId, string memory option) external onlyVerifiedVoter {
        proposalManager.castVote(msg.sender, proposalId, option);
    }

    function retractVote(uint256 proposalId) external onlyVerifiedVoter {
        proposalManager.retractVote(msg.sender, proposalId);
    }

    function changeVote(uint256 proposalId, string memory newOption) external onlyVerifiedVoter {
        proposalManager.changeVote(msg.sender, proposalId, newOption);
    }

    function grantRole(bytes32 role, address account) external onlyAdmin {
        accessControl.grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyAdmin {
        accessControl.revokeRole(role, account);
    }

    function verifyVoter(address voter) external onlyAdmin {
        accessControl.verifyVoter(voter);
    }

    function removeUserProposal(uint256 proposalId) external {
        proposalManager.removeUserProposal(msg.sender, proposalId);
    }

    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) external view returns (uint256) {
        return proposalManager.getVoteCount(proposalId, option);
    }

    function getProposalCount() external view returns (uint256) {
        return proposalManager.getProposalCount();
    }

    function getProposalWinner(uint256 proposalId)
        external
        returns (string[] memory winners, bool isDraw)
    {
        return proposalManager.getProposalWinner(proposalId);
    }

    function getProposalManager() external view returns (address) {
        return address(proposalManager);
    }

    function getVoterManager() external view returns (address) {
        return address(voterManager);
    }

    function registerVoter(
        address voter,
        uint64 nid,
        int256[] memory embeddings
    ) external onlyAuthorizedCaller(msg.sender) {
        voterManager.registerVoter(voter, nid, embeddings);
        // Also verify the voter in the access control system
        accessControl.verifyVoter(voter);
    }

    function isNidRegistered(uint64 nid) external view returns (bool) {
        return voterManager.nidRegistered(nid);
    }

    function getVoterParticipatedProposals()
        external
        view
        returns (uint256[] memory)
    {
        return voterManager.getVoterParticipatedProposals(msg.sender);
    }

    function getVoterCreatedProposals()
        external
        view
        returns (uint256[] memory)
    {
        return voterManager.getVoterCreatedProposals(msg.sender);
    }

    function getVoterSelectedOption(uint256 proposalId)
        external
        view
        returns (string memory)
    {
        return voterManager.getVoterSelectedOption(msg.sender, proposalId);
    }

    function getProposalDetails(uint256 proposalId)
        external
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

    function getVoterEmbeddings() external view returns (int256[] memory) {
        return voterManager.getVoterEmbeddings(msg.sender);
    }
}
