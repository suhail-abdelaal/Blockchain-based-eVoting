// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ProposalManager} from "./ProposalManager.sol";
import {VoterManager} from "./VoterManager.sol";
import {RBAC} from "./RBAC.sol";
import {RBACWrapper} from "./RBACWrapper.sol";

contract VotingSystem is RBACWrapper {
    ProposalManager private immutable proposalManager;
    VoterManager private immutable voterManager;

    constructor() RBACWrapper(address(new RBAC())) {
        address rbac = getRBACaddr();
        voterManager = new VoterManager(rbac);
        proposalManager =
            new ProposalManager(rbac, address(this), address(voterManager));
    }

    function createProposal(
        string calldata title,
        string[] calldata options,
        uint256 startDate,
        uint256 endDate
    ) external onlyVerifiedAddr(msg.sender) returns (uint256) {
        // Create proposal
        uint256 proposalId = proposalManager.addProposal(
            msg.sender, title, options, startDate, endDate
        );
        return proposalId;
    }

    function castVote(
        uint256 proposalId,
        string calldata option
    ) external onlyVerifiedAddr(msg.sender) {
        // Cast vote
        proposalManager.castVote(msg.sender, proposalId, option);
    }

    function retractVote(
        uint256 proposalId
    ) external onlyVerifiedAddr(msg.sender) {
        // Cast vote
        proposalManager.retractVote(msg.sender, proposalId);
    }

    function changeVote(
        uint256 proposalId,
        string calldata option
    ) external onlyVerifiedAddr(msg.sender) {
        // Change vote
        proposalManager.changeVote(msg.sender, proposalId, option);
    }

    function grantRole(bytes32 role, address account) public {
        rbac.grantRole(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) public {
        rbac.revokeRole(role, account, msg.sender);
    }

    function verifyVoter(
        address voter
    ) public {
        rbac.verifyVoter(voter, msg.sender);
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

    function getProposalWinner(
        uint256 proposalId
    ) external onlyVerifiedAddr(msg.sender) returns (string[] memory, bool) {
        return proposalManager.getProposalWinner(proposalId);
    }

    function getVoterManager() external view returns (address) {
        return address(voterManager);
    }

    function getProposalManager() external view returns (address) {
        return address(proposalManager);
    }
}
