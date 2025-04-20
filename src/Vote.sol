// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ballot} from "./Ballot.sol";
import {VoterRegistry} from "./VoterRegistry.sol";
import {RBAC} from "./RBAC.sol";
import {RBACWrapper} from "./RBACWrapper.sol";

contract Vote is RBACWrapper {
    Ballot private immutable ballot;
    VoterRegistry private immutable voterRegistry;

    constructor() RBACWrapper(address(new RBAC())) {
        address rbac = getRBACaddr();
        voterRegistry = new VoterRegistry(rbac);
        ballot = new Ballot(rbac, address(this), address(voterRegistry));
    }

    function createProposal(
        string calldata title,
        string[] calldata options,
        uint256 startDate,
        uint256 endDate
    ) external onlyVerifiedVoterAddr(msg.sender) returns (uint256) {
        // Create proposal
        uint256 proposalId = ballot.addProposal(
            msg.sender,
            title,
            options,
            startDate,
            endDate
        );
        return proposalId;
    }

    function castVote(
        uint256 proposalId,
        string calldata option
    ) external onlyVerifiedVoterAddr(msg.sender) {
        // Cast vote
        ballot.castVote(msg.sender, proposalId, option);
    }

    function retractVote(
        uint256 proposalId
    ) external onlyVerifiedVoterAddr(msg.sender) {
        // Cast vote
        ballot.retractVote(msg.sender, proposalId);
    }

    function changeVote(
        uint256 proposalId,
        string calldata option
    ) external onlyVerifiedVoterAddr(msg.sender) {
        // Change vote
        ballot.changeVote(msg.sender, proposalId, option);
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
    ) external view onlyVerifiedVoterAddr(msg.sender) returns (uint256) {
        return ballot.getVoteCount(proposalId, option);
    }

    function getProposalCount()
        external
        view
        onlyVerifiedVoterAddr(msg.sender)
        returns (uint256)
    {
        return ballot.getProposalCount();
    }

    function getVoterRegistry() external view returns (address) {
        return address(voterRegistry);
    }

    function getBallot() external view returns (address) {
        return address(ballot);
    }
}
