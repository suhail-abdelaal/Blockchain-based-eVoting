// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Ballot {


    /* Erros and Events */
    error ProposalStartDateTooEarly(uint256 startDate);
    error PrposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);

    /* User Defined Datatypes */
    enum VoteStatus {
        PENDING,
        ACITVE,
        COMPLETED
    }

    struct Proposal {
        string title;
        string[] candidates;
        mapping(string candidateName => uint256 voteCount) candidateVoteCounts;
        VoteStatus proposalStatus;
        uint256 startDate;
        uint256 endDate;
    }

    /* State Variables */
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;


    /* Modifiers */
    modifier onlyVerifiedVoter() {
        // if (!voterRegistry.getVoterRegistration(msg.sender)) {
        //     revert NotRegisteredVoter(msg.sender);
        // }
        // if (!voterRegistry.getVoterVerification(msg.sender)) {
        //     revert NotVerifiedVoter(msg.sender);
        // }
        _;
    }

    /* Public Methods */
    function addProposal(
        string memory _title,
        string[] memory _candidates,
        uint256 _startDate,
        uint256 _endDate
    ) public onlyVerifiedVoter {
        if (_startDate <= block.timestamp) {
            revert ProposalStartDateTooEarly(_startDate);
        } else if (_endDate <= _startDate) {
            revert PrposalEndDateLessThanStartDate(_startDate, _endDate);
        }

        ++proposalCount;
        Proposal storage proposal = proposals[proposalCount];

        proposal.title = _title;
        proposal.startDate = _startDate;
        proposal.endDate = _endDate;

        for (uint256 i = 0; i < _candidates.length; ++i) {
            proposal.candidates.push(_candidates[i]);
            proposal.candidateVoteCounts[_candidates[i]] = 0;
        }

        proposal.proposalStatus = (_startDate >= block.timestamp)
        ? VoteStatus.ACITVE
        : VoteStatus.PENDING;
    }
}
