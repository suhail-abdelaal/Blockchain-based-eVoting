// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ballot} from "./Ballot.sol";
import {VoterRegistry} from "./VoterRegistry.sol";
import {RBAC} from "./RBAC.sol";

contract Vote is RBAC {

    Ballot public immutable ballot;
    VoterRegistry public immutable voterRegistry;


    constructor() {
        voterRegistry = new VoterRegistry();
        ballot = new Ballot(address(voterRegistry));
    }


    function createProposal(
        string calldata _title,
        string[] calldata _options,
        uint256 _startDate,
        uint256 _endDate
    ) external onlyVerifiedVoter returns(uint256) {

        // Create proposal
        uint256 proposalId = ballot.addProposal(_title, _options, _startDate, _endDate);

        return proposalId;
    }


    function castVote(
        uint256 proposalId,
        string calldata option) external onlyVerifiedVoter {

        // Cast vote
        ballot.castVote(msg.sender, proposalId, option);
    }


    function retractVote(
        uint256 proposalId,
        string calldata option) external onlyVerifiedVoter {

        // Cast vote
        ballot.retractVote(msg.sender, proposalId, option);
    }

}
