// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ballot} from "./Ballot.sol";
import {VoterRegistry} from "./VoterRegistry.sol";
import {RBAC} from "./RBAC.sol";
import {RBACWrapper} from "./RBACWrapper.sol";

contract Vote is RBACWrapper {
    Ballot public immutable ballot;
    VoterRegistry public immutable voterRegistry;

    constructor(
        address _rbac
    ) RBACWrapper(_rbac) {
        rbac = RBAC(_rbac);
        voterRegistry = new VoterRegistry(_rbac);
        ballot = new Ballot(_rbac, address(this), address(voterRegistry));
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
            Ballot.VoteMutability.MUTABLE,
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
    ) external onlyVerifiedVoter {
        // Cast vote
        ballot.retractVote(msg.sender, proposalId);
    }

    function changeVote(
        uint256 proposalId,
        string calldata option
    ) external onlyVerifiedVoter {
        // Change vote
        ballot.changeVote(msg.sender, proposalId, option);
    }

    function grantRole(bytes32 role, address account) public onlyAdmin {
        rbac.grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyAdmin {
        rbac.revokeRole(role, account);
    }

    function verifyVoter(
        address voter
    ) external onlyAdmin {
        rbac.verifyVoter(voter);
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
}
