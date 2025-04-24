// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IVotingSystem} from "./interfaces/IVotingSystem.sol";
import {IVoterManager} from "./interfaces/IVoterManager.sol";
import {IProposalManager} from "./interfaces/IProposalManager.sol";
import {RBACWrapper} from "./RBACWrapper.sol";

contract VotingSystem is IVotingSystem, RBACWrapper {

    IProposalManager private immutable proposalManager;
    IVoterManager private immutable voterManager;

    constructor(
        address _rbac,
        address _voterManager,
        address _propossalManager
    ) RBACWrapper(_rbac) {
        voterManager = IVoterManager(_voterManager);
        proposalManager = IProposalManager(_propossalManager);
    }

    function createProposal(
        string calldata title,
        string[] calldata options,
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256) {
        // Create proposal
        uint256 proposalId = proposalManager.createProposal(
            msg.sender, title, options, startDate, endDate
        );
        return proposalId;
    }

    function castVote(
        uint256 proposalId,
        string calldata option
    ) external {
        // Cast vote
        proposalManager.castVote(msg.sender, proposalId, option);
    }

    function retractVote(uint256 proposalId)
        external
    {
        // Cast vote
        proposalManager.retractVote(msg.sender, proposalId);
    }

    function changeVote(
        uint256 proposalId,
        string calldata option
    ) external  {
        // Change vote
        proposalManager.changeVote(msg.sender, proposalId, option);
    }

    function registerVoter(
        address voter,
        string calldata voterName,
        uint256[] calldata featureVector
    ) external onlyAdmin {
        // Register voter
        voterManager.verifyVoter(voter, voterName, featureVector);
    }

    function removeUserProposal(
        uint256 proposalId
    ) external onlyAdmin {
        // Remove user proposal
        proposalManager.removeUserProposal(msg.sender, proposalId);
    }

    function grantRole(bytes32 role, address account) public {
        rbac.grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public {
        rbac.revokeRole(role, account);
    }

    function verifyVoter(address voter) public {
        rbac.verifyVoter(voter);
    }

    function getVoterParticipatedProposals(address voter)
        external
        view
        onlyAdmin
        returns (uint256[] memory)
    {
        return voterManager.getVoterParticipatedProposals(voter);
    }

    function getVoterCreatedProposals(address voter)
        external
        view
        onlyAdmin
        returns (uint256[] memory)
    {
        return voterManager.getVoterCreatedProposals(voter);
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view onlyVerifiedAddr(msg.sender) returns (uint256) {
        return proposalManager.getVoteCount(proposalId, option);
    }

    function getProposalCount()
        external
        view
        onlyVerifiedAddr(msg.sender)
        returns (uint256)
    {
        return proposalManager.getProposalCount();
    }

    function getProposalWinner(uint256 proposalId)
        external
        onlyVerifiedAddr(msg.sender)
        returns (string[] memory, bool)
    {
        return proposalManager.getProposalWinner(proposalId);
    }

    function getVoterManager() external view returns (address) {
        return address(voterManager);
    }

    function getProposalManager() external view returns (address) {
        return address(proposalManager);
    }

    function getProposalDetails(uint256 proposalId)
        external
        onlyVerifiedAddr(msg.sender)
        returns (
            string memory title,
            string[] memory options,
            uint256 startDate,
            uint256 endDate,
            address owner,
            bool isDraw,
            string[] memory winners
        )
    {
        return proposalManager.getProposalDetails(proposalId);
    }

}
