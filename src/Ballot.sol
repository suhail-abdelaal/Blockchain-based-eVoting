// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RBAC} from "./RBAC.sol";
import {VoterRegistry} from "./VoterRegistry.sol";

contract Ballot is RBAC {

    /* Erros and Events */
    error ProposalStartDateTooEarly(uint256 startDate);
    error PrposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);
    error ProposalCompleted(uint256 proposalId);
    error ProposalNotStartedYet(uint256 proposalId);
    error VoteAlreadyCast(uint256 proposalId, address voter);

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

    event VoteRetracted(
        uint256 indexed proposalId,
        address indexed voter,
        string option
    );


    /* User Defined Datatypes */
    enum ProposalStatus {
        PENDING,
        ACITVE,
        COMPLETED
    }

    enum VoteMutability {
        IMMUTABLE,
        MUTABLE
    }

    struct Proposal {
        address owner;
        string title;
        string[] options;
        mapping(string candidateName => uint256 voteCount) optionVoteCounts;
        ProposalStatus proposalStatus;
        VoteMutability voteMutability;
        uint256 startDate;
        uint256 endDate;
    }

    /* State Variables */
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    VoterRegistry public voterRegistry;

    constructor (address _voterRegistry) {
        voterRegistry = VoterRegistry(_voterRegistry);
        proposalCount = 1;
    }

    // ---------------------------------Modifiers---------------------------------
    // modifier onlyOnce(uint256 _proposalId, address _voter) {
    //     if (proposals[_proposalId].participants[_voter]) {
    //         revert VoteAlreadyCast(_proposalId, _voter);
    //     }
    //     _;
    // }


    /* Public Methods */
    function addProposal(
        address _owner,
        string calldata _title,
        string[] calldata _options,
        uint256 _startDate,
        uint256 _endDate
    ) external onlyVerifiedVoterAddr(_owner) returns (uint256) {
        if (_startDate <= block.timestamp + 10 minutes) {
            revert ProposalStartDateTooEarly(_startDate);
        } else if (_endDate <= _startDate) {
            revert PrposalEndDateLessThanStartDate(_startDate, _endDate);
        }

        Proposal storage proposal = proposals[proposalCount];
        ++proposalCount;

        proposal.owner = _owner;
        proposal.title = _title;
        proposal.startDate = _startDate;
        proposal.endDate = _endDate;

        for (uint256 i = 0; i < _options.length; ++i) {
            proposal.options.push(_options[i]);
            proposal.optionVoteCounts[_options[i]] = 0;
        }

        proposal.proposalStatus = (_startDate >= block.timestamp)
        ? ProposalStatus.ACITVE
        : ProposalStatus.PENDING;

        emit ProposalCreated(proposalCount, _owner, _title, _startDate, _endDate);

        return proposalCount;
    }


    function castVote(
        address _voter,
        uint256 _proposalId,
        string calldata _option
        ) external onlyVerifiedVoterAddr(_voter) {

        ProposalStatus proposalStatus = getProposalStatus(_proposalId);
        if (proposalStatus == ProposalStatus.COMPLETED) {
            revert ProposalCompleted(_proposalId);
        } else if (proposalStatus == ProposalStatus.PENDING) {
            revert ProposalNotStartedYet(_proposalId);
        }

        if (proposals[_proposalId].voteMutability == VoteMutability.IMMUTABLE
            && voterRegistry.checkVoterParticipation(_voter, _proposalId)
        ) {
            revert VoteAlreadyCast(_proposalId, _voter);
        }

        proposals[_proposalId].optionVoteCounts[_option] += 1;
        voterRegistry.recordUserParticipation(_voter, _proposalId, _option);

        emit VoteCast(_proposalId, _voter, _option);
    }

    function retractVote(address _voter,
        uint256 _proposalId,
        string calldata _option
        ) external {

        proposals[_proposalId].optionVoteCounts[_option] -= 1;
        voterRegistry.removeUserParticipation(_voter, _proposalId);

        emit VoteRetracted(_proposalId, _voter, _option);

    }

    function getProposalStatus(uint256 _proposalId) public view returns (ProposalStatus) {
        return proposals[_proposalId].proposalStatus;
    }

    function getProposalVoteMutability(uint256 _proposalId) public view returns (VoteMutability) {
        return proposals[_proposalId].voteMutability;
    }

    function getProposalOwner(uint256 _proposalId) public view returns (address) {
        return proposals[_proposalId].owner;
    }
}
