// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RBAC} from "./RBAC.sol";
import {VoterRegistry} from "./VoterRegistry.sol";
import {Vote} from "./Vote.sol";

contract Ballot is RBAC {
    /* Errors and Events */
    error ProposalNotFound(uint256 proposalId);
    error ProposalStartDateTooEarly(uint256 startDate);
    error ProposalEndDateLessThanStartDate(uint256 startDate, uint256 endDate);
    error ProposalCompleted(uint256 proposalId);
    error ProposalNotStartedYet(uint256 proposalId);
    error NotAuthorized(address addr);
    error VoteAlreadyCast(uint256 proposalId, address voter);
    error ImmutableVote(uint256 proposalId, address voter);
    error VoterNotParticipated(uint256 proposalId, address voter);
    error VoteOptionIdentical(
        uint256 proposalId, string oldOption, string newOption
    );
    error InvalidOption(uint256 proposalId, string option);

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed owner,
        string title,
        uint256 startDate,
        uint256 endDate
    );

    event VoteCast(
        uint256 indexed proposalId, address indexed voter, string option
    );

    event VoteRetracted(
        uint256 indexed proposalId, address indexed voter, string option
    );

    event VoteChanged(
        uint256 indexed proposalId,
        address indexed voter,
        string oldOption,
        string newOption
    );

    enum ProposalStatus {
        PENDING,
        ACTIVE,
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
        mapping(string => bool) optionExistence;
        mapping(string => uint256) optionVoteCounts;
        ProposalStatus proposalStatus;
        VoteMutability voteMutability;
        mapping(address => bool) isParticipant;
        uint256 startDate;
        uint256 endDate;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    VoterRegistry public voterRegistry;
    address authorizedCaller;

    constructor(address _authorizedCaller, address _voterRegistry) {
        authorizedCaller = _authorizedCaller;
        voterRegistry = VoterRegistry(_voterRegistry);
        proposalCount = 0;
    }

    // ------------------- Modifiers -------------------

    modifier onActiveProposals(
        uint256 proposalId
    ) {
        // if (proposalId > proposalCount) revert ProposalNotFound(proposalId);
        ProposalStatus status = proposals[proposalId].proposalStatus;
        if (status == ProposalStatus.COMPLETED) {
            revert ProposalCompleted(proposalId);
        }
        if (status == ProposalStatus.PENDING) {
            revert ProposalNotStartedYet(proposalId);
        }
        _;
    }

    modifier onlyParticipants(address voter, uint256 proposalId) {
        if (!checkVoterParticipation(voter, proposalId)) {
            revert VoterNotParticipated(proposalId, voter);
        }
        _;
    }

    modifier onlyValidOptions(uint256 proposalId, string calldata option) {
        if (!proposals[proposalId].optionExistence[option]) {
            revert InvalidOption(proposalId, option);
        }
        _;
    }

    // ------------------- External Methods -------------------

    function addProposal(
        address _voter,
        string calldata _title,
        string[] calldata _options,
        VoteMutability _voteMutability,
        uint256 _startDate,
        uint256 _endDate
    ) external onlyVerifiedVoterAddr(_voter) returns (uint256) {
        if (msg.sender != authorizedCaller) {
            revert NotAuthorized(msg.sender);
        }

        if (_startDate <= block.timestamp + 10 minutes) {
            revert ProposalStartDateTooEarly(_startDate);
        }
        if (_endDate <= _startDate) {
            revert ProposalEndDateLessThanStartDate(_startDate, _endDate);
        }

        ++proposalCount;
        uint256 id = proposalCount;
        Proposal storage proposal = proposals[id];
        _initializeProposal(
            proposal,
            _voter,
            _title,
            _options,
            _voteMutability,
            _startDate,
            _endDate
        );

        voterRegistry.recordUserCreatedProposal(_voter, id);
        emit ProposalCreated(id, _voter, _title, _startDate, _endDate);

        return id;
    }

    function castVote(
        address _voter,
        uint256 _proposalId,
        string calldata _option
    )
        external
        onlyVerifiedVoterAddr(_voter)
        onActiveProposals(_proposalId)
        onlyValidOptions(_proposalId, _option)
    {
        if (msg.sender != authorizedCaller) {
            revert NotAuthorized(msg.sender);
        }
        if (checkVoterParticipation(_voter, _proposalId)) {
            revert VoteAlreadyCast(_proposalId, _voter);
        }

        _castVote(_proposalId, _voter, _option);
    }

    function retractVote(
        address _voter,
        uint256 _proposalId
    )
        external
        onlyVerifiedVoterAddr(_voter)
        onActiveProposals(_proposalId)
        onlyParticipants(_voter, _proposalId)
    {
        if (msg.sender != authorizedCaller) {
            revert NotAuthorized(msg.sender);
        }
        if (getProposalVoteMutability(_proposalId) == VoteMutability.IMMUTABLE)
        {
            revert ImmutableVote(_proposalId, _voter);
        }

        string memory option =
            voterRegistry.getVoterSelectedOption(_voter, _proposalId);
        if (!proposals[_proposalId].optionExistence[option]) {
            revert InvalidOption(_proposalId, option);
        }

        _retractVote(_proposalId, _voter, option);
    }

    function changeVote(
        address _voter,
        uint256 _proposalId,
        string calldata _newOption
    )
        external
        onlyVerifiedVoterAddr(_voter)
        onActiveProposals(_proposalId)
        onlyParticipants(_voter, _proposalId)
    {
        if (msg.sender != authorizedCaller) {
            revert NotAuthorized(msg.sender);
        }
        if (getProposalVoteMutability(_proposalId) == VoteMutability.IMMUTABLE)
        {
            revert ImmutableVote(_proposalId, _voter);
        }

        string memory previousOption =
            voterRegistry.getVoterSelectedOption(_voter, _proposalId);
        if (!proposals[_proposalId].optionExistence[previousOption]) {
            revert InvalidOption(_proposalId, previousOption);
        }

        if (_cmpStrings(previousOption, _newOption)) {
            revert VoteOptionIdentical(_proposalId, previousOption, _newOption);
        }

        _retractVote(_proposalId, _voter, previousOption);
        _castVote(_proposalId, _voter, _newOption);

        emit VoteChanged(_proposalId, _voter, previousOption, _newOption);
    }

    // ------------------- Public Methods -------------------

    function checkVoterParticipation(
        address _voter,
        uint256 _proposalId
    ) public view returns (bool) {
        return proposals[_proposalId].isParticipant[_voter];
    }

    function getVoteCount(
        uint256 _proposalId,
        string calldata _option
    ) external view returns (uint256) {
        return proposals[_proposalId].optionVoteCounts[_option];
    }

    function getProposalStatus(
        uint256 _proposalId
    ) public view returns (ProposalStatus) {
        return proposals[_proposalId].proposalStatus;
    }

    function getProposalVoteMutability(
        uint256 _proposalId
    ) public view returns (VoteMutability) {
        return proposals[_proposalId].voteMutability;
    }

    function getProposalOwner(
        uint256 _proposalId
    ) public view returns (address) {
        return proposals[_proposalId].owner;
    }

    // ------------------- Internal Methods -------------------

    function _castVote(
        uint256 _proposalId,
        address _voter,
        string calldata _option
    ) internal {
        proposals[_proposalId].optionVoteCounts[_option] += 1;
        proposals[_proposalId].isParticipant[_voter] = true;
        voterRegistry.recordUserParticipation(_voter, _proposalId, _option);

        emit VoteCast(_proposalId, _voter, _option);
    }

    function _retractVote(
        uint256 _proposalId,
        address _voter,
        string memory _option
    ) internal {
        proposals[_proposalId].optionVoteCounts[_option] -= 1;
        proposals[_proposalId].isParticipant[_voter] = false;
        // voterRegistry.removeUserParticipation(_voter, _proposalId);

        emit VoteRetracted(_proposalId, _voter, _option);
    }

    function _initializeProposal(
        Proposal storage proposal,
        address _owner,
        string calldata _title,
        string[] calldata _options,
        VoteMutability _voteMutability,
        uint256 _startDate,
        uint256 _endDate
    ) internal {
        proposal.owner = _owner;
        proposal.title = _title;
        proposal.startDate = _startDate;
        proposal.endDate = _endDate;
        // proposal.proposalStatus = (_startDate >= block.timestamp)
        // ? ProposalStatus.ACTIVE
        // : ProposalStatus.PENDING;
        proposal.proposalStatus = ProposalStatus.ACTIVE;
        proposal.voteMutability = _voteMutability;

        for (uint256 i = 0; i < _options.length; ++i) {
            proposal.options.push(_options[i]);
            proposal.optionExistence[_options[i]] = true;
            // proposal.optionVoteCounts[_options[i]] = 0;
        }
    }

    function _cmpStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        // Convert the strings to bytes and check if they are of the same length
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
