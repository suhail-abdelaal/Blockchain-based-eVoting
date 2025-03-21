// SPDX-License-Identifier: MIT
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
        string[] options;
        mapping(string candidateName => uint256 voteCount) optionVoteCounts;
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
        string calldata _title,
        string[] calldata _options,
        uint256 _startDate,
        uint256 _endDate
    ) external onlyVerifiedVoter {
        if (_startDate <= block.timestamp + 10 minutes) {
            revert ProposalStartDateTooEarly(_startDate);
        } else if (_endDate <= _startDate) {
            revert PrposalEndDateLessThanStartDate(_startDate, _endDate);
        }

        ++proposalCount;
        Proposal storage proposal = proposals[proposalCount];

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
    }

    function increaseCanditateVoteCount(uint256 _proposalId, string calldata _candidateName) external onlyVerifiedVoter {
        proposals[_proposalId].candidateVoteCounts[_candidateName] += 1;
    }

    function getProposalStatus(uint256 _proposalId) external view returns (VoteStatus) {
        return proposals[_proposalId].proposalStatus;
    }
}
