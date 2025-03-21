// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RBAC} from "./RBAC.sol";

contract Ballot is RBAC{

    /* Erros and Events */
    error ProposalStartDateTooEarly(uint256 startDate);
    error PrposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed owner,
        string title,
        uint256 startDate,
        uint256 endDate
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        string option
    );


    /* User Defined Datatypes */
    enum VoteStatus {
        PENDING,
        ACITVE,
        COMPLETED
    }

    struct Proposal {
        address owner;
        string title;
        string[] options;
        mapping(string candidateName => uint256 voteCount) optionVoteCounts;
        VoteStatus proposalStatus;
        uint256 startDate;
        uint256 endDate;
    }

    /* State Variables */
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;


    /* Public Methods */
    function addProposal(
        address _owner,
        string calldata _title,
        string[] calldata _options,
        uint256 _startDate,
        uint256 _endDate
    ) external onlyVerifiedVoterAddr(_owner) returns(uint256) {
        if (_startDate <= block.timestamp + 10 minutes) {
            revert ProposalStartDateTooEarly(_startDate);
        } else if (_endDate <= _startDate) {
            revert PrposalEndDateLessThanStartDate(_startDate, _endDate);
        }

        ++proposalCount;
        Proposal storage proposal = proposals[proposalCount];

        proposal.owner = _owner;
        proposal.title = _title;
        proposal.startDate = _startDate;
        proposal.endDate = _endDate;

        for (uint256 i = 0; i < _options.length; ++i) {
            proposal.options.push(_options[i]);
            proposal.optionVoteCounts[_options[i]] = 0;
        }

        proposal.proposalStatus = (_startDate >= block.timestamp)
        ? VoteStatus.ACITVE
        : VoteStatus.PENDING;

        emit ProposalCreated(proposalCount, _owner, _title, _startDate, _endDate);

        return proposalCount;
    }


    function increaseOptionVoteCount(
        address _voter,
        uint256 _proposalId,
        string calldata _option
        ) external onlyVerifiedVoterAddr(_voter) {

        proposals[_proposalId].optionVoteCounts[_option] += 1;

        emit VoteCast(_proposalId, _voter, _option);
    }

    function getProposalStatus(uint256 _proposalId) external view returns (VoteStatus) {
        return proposals[_proposalId].proposalStatus;
    }

    function getProposalOwner(uint256 _proposalId) external view returns (address) {
        return proposals[_proposalId].owner;
    }
}
