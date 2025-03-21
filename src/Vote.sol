// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ballot} from "./Ballot.sol";
import {VoterRegistry} from "./VoterRegistry.sol";
import {RoleBasedAccessControl} from "./RoleBasedAccessControl.sol";

contract Vote is RoleBasedAccessControl {
    error ProposalCompleted(uint256 proposalId);
    error ProposalNotStartedYet(uint256 proposalId);


    Ballot public immutable ballot;
    VoterRegistry public immutable voterRegistry;


    constructor() {
        ballot = new Ballot();
        voterRegistry = new VoterRegistry();
    }


    function createProposal(
        string calldata _title,
        string[] calldata _candidates,
        uint256 _startDate,
        uint256 _endDate
    ) external onlyVerifiedVoter returns(uint256) {

        // Create proposal
        uint256 proposalId = ballot.addProposal(msg.sender, _title, _candidates, _startDate, _endDate);
        // Add proposal to the voter's history
        voterRegistry.addUserCreatedProposal(msg.sender, proposalId);

        return proposalId;
    }


    function castVote(
        address voter,
        uint256 proposalId,
        string calldata option) external onlyVerifiedVoter {

        if (ballot.getProposalStatus(proposalId) == Ballot.VoteStatus.COMPLETED) {
            revert ProposalCompleted(proposalId);
        } else if (ballot.getProposalStatus(proposalId) == Ballot.VoteStatus.PENDING) {
            revert ProposalNotStartedYet(proposalId);
        }

        // Cast vote
        ballot.increaseOptionVoteCount(voter, proposalId, option);

        // Add proposal to the voter's history
        voterRegistry.addUserParticipatedProposal(msg.sender, proposalId, option);
    }

}
