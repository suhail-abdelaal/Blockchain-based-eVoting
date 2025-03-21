// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ballot} from "./Ballot.sol";
import {VoterRegistry} from "./VoterRegistry.sol";

contract Vote {
    error ProposalCompleted(uint256 proposalId);
    error ProposalNotStartedYet(uint256 proposalId);


    Ballot public immutable ballot;
    VoterRegistry public immutable voterRegistry;


    constructor() {
        ballot = new Ballot();
        voterRegistry = new VoterRegistry();
    }


    // function createProposal(
    //     string calldata _title,
    //     string[] calldata _candidates,
    //     uint256 _startDate,
    //     uint256 _endDate
    // ) external returns(string calldata id) {
    //     string calldata id = ballot.addProposal(_title, _candidates, _startDate, _endDate);
    //     return id;
    // }


    function castVote(uint256 proposalId, string calldata option) external {
        if (ballot.getProposalStatus(proposalId) == Ballot.VoteStatus.COMPLETED) {
            revert ProposalCompleted(proposalId);
        } else if (ballot.getProposalStatus(proposalId) == Ballot.VoteStatus.PENDING) {
            revert ProposalNotStartedYet(proposalId);
        }
        ballot.increaseOptionVoteCount(proposalId, option);
    }

}
