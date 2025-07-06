// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IProposalState.sol";
import "../access/AccessControlWrapper.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ProposalState
 * @author Suhail Abdelaal
 * @notice Manages the state and lifecycle of proposals
 * @dev Implements IProposalState interface for proposal state management
 */
contract ProposalState is IProposalState, AccessControlWrapper {

    using Strings for uint256;

    /**
     * @notice Struct to store proposal information and voting data
     * @dev Uses mappings for efficient vote counting and participant tracking
     */
    struct Proposal {
        uint256 id;                                    // Unique identifier
        address owner;                                 // Proposal creator
        string title;                                  // Proposal title
        string[] options;                             // Voting options
        ProposalStatus status;                        // Current status
        VoteMutability voteMutability;                // Vote change setting
        mapping(string => uint256) voteCount;         // Votes per option
        mapping(string => bool) optionExistence;      // Valid options
        mapping(address => bool) isParticipant;       // Voter participation
        uint256 numOfParticipants;                    // Total participants
        uint256 startDate;                            // Start timestamp
        uint256 endDate;                              // End timestamp
        bool isDraw;                                  // Tie status
        string[] winners;                             // Winning options
    }

    mapping(uint256 => Proposal) private proposals;
    uint256 private proposalCount;
    uint256 private id;

    /**
     * @notice Emitted when a proposal's status changes
     * @param proposalId ID of the proposal
     * @param status New status
     */
    event ProposalStatusUpdated(
        uint256 indexed proposalId, ProposalStatus status
    );

    /**
     * @notice Emitted when a proposal is finalized
     * @param proposalId ID of the proposal
     * @param winners Array of winning options
     * @param isDraw Whether there is a tie
     */
    event ProposalFinalized(
        uint256 indexed proposalId, string[] winners, bool isDraw
    );

    /**
     * @notice Initializes the ProposalState contract
     * @param _accessControl Address of the access control contract
     */
    constructor(address _accessControl) AccessControlWrapper(_accessControl) {
        id = 1;
    }

    /**
     * @notice Gets the current status of a proposal
     * @param proposalId ID of the target proposal
     * @return Current status
     */
    function getProposalStatus(uint256 proposalId)
        external
        view
        override
        returns (ProposalStatus)
    {
        return proposals[proposalId].status;
    }

    /**
     * @notice Gets and updates the current status of a proposal
     * @param proposalId ID of the target proposal
     * @return Current status after update
     */
    function getCurrentProposalStatus(uint256 proposalId)
        external
        override
        returns (ProposalStatus)
    {
        _updateProposalStatus(proposalId);
        return proposals[proposalId].status;
    }

    /**
     * @notice Updates the status of a proposal
     * @dev Only authorized callers can update status
     * @param proposalId ID of the target proposal
     */
    function updateProposalStatus(uint256 proposalId)
        external
        override
        onlyAuthorizedCaller(msg.sender)
    {
        _updateProposalStatus(proposalId);
    }

    /**
     * @notice Internal function to update proposal status
     * @dev Updates based on current time and emits events
     * @param proposalId ID of the target proposal
     */
    function _updateProposalStatus(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        uint256 currentTime = block.timestamp;

        if (
            proposal.status != ProposalStatus.ACTIVE
                && proposal.startDate <= currentTime
                && proposal.endDate > currentTime
        ) {
            proposal.status = ProposalStatus.ACTIVE;
            emit ProposalStatusUpdated(proposalId, ProposalStatus.ACTIVE);
        } else if (
            proposal.status != ProposalStatus.CLOSED
                && proposal.endDate <= currentTime
        ) {
            proposal.status = ProposalStatus.CLOSED;
            emit ProposalStatusUpdated(proposalId, ProposalStatus.CLOSED);
            tallyVotes(proposalId);
            proposal.status = ProposalStatus.FINALIZED;
            emit ProposalFinalized(
                proposalId,
                proposals[proposalId].winners,
                proposals[proposalId].isDraw
            );
        }
    }

    /**
     * @notice Gets the vote mutability setting of a proposal
     * @param proposalId ID of the target proposal
     * @return Vote mutability setting
     */
    function getProposalVoteMutability(uint256 proposalId)
        external
        view
        override
        returns (VoteMutability)
    {
        return proposals[proposalId].voteMutability;
    }

    /**
     * @notice Checks if a proposal is currently active
     * @param proposalId ID of the target proposal
     * @return True if the proposal is active
     */
    function isProposalActive(uint256 proposalId)
        external
        view
        override
        returns (bool)
    {
        return proposals[proposalId].status == ProposalStatus.ACTIVE;
    }

    /**
     * @notice Checks if a proposal is closed
     * @param proposalId ID of the target proposal
     * @return True if the proposal is closed
     */
    function isProposalClosed(uint256 proposalId)
        external
        view
        override
        returns (bool)
    {
        return proposals[proposalId].status == ProposalStatus.CLOSED;
    }

    /**
     * @notice Creates a new proposal
     * @dev Only authorized callers can create proposals
     * @param owner Address of the proposal creator
     * @param title Title of the proposal
     * @param options Array of voting options
     * @param voteMutability Whether votes can be changed
     * @param startDate Timestamp when voting begins
     * @param endDate Timestamp when voting ends
     * @return proposalId Unique identifier of the created proposal
     */
    function createProposal(
        address owner,
        string calldata title,
        string[] memory options,
        VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) external override onlyAuthorizedCaller(msg.sender) returns (uint256) {
        Proposal storage proposal = proposals[id];

        proposal.id = id;
        proposal.owner = owner;
        proposal.title = title;
        proposal.options = options;
        proposal.startDate = startDate;
        proposal.endDate = endDate;
        proposal.status = ProposalStatus.PENDING;
        proposal.voteMutability = voteMutability;

        for (uint256 i = 0; i < options.length; ++i) {
            proposal.optionExistence[options[i]] = true;
        }

        id++;
        proposalCount++;

        _updateProposalStatus(proposal.id);

        return proposal.id;
    }

    /**
     * @notice Removes a proposal
     * @dev Only authorized callers can remove proposals
     * @param proposalId ID of the proposal to remove
     */
    function removeProposal(uint256 proposalId) external onlyAuthorizedCaller(msg.sender) {
        delete proposals[proposalId];
        proposalCount--;
    }

    /**
     * @notice Increments the vote count for an option
     * @dev Only authorized callers can increment votes
     * @param proposalId ID of the target proposal
     * @param option Option to increment votes for
     */
    function incrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].voteCount[option]++;
    }

    /**
     * @notice Decrements the vote count for an option
     * @dev Only authorized callers can decrement votes
     * @param proposalId ID of the target proposal
     * @param option Option to decrement votes for
     */
    function decrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].voteCount[option]--;
    }

    /**
     * @notice Adds a participant to a proposal
     * @dev Only authorized callers can add participants
     * @param proposalId ID of the target proposal
     * @param voter Address of the participant
     */
    function addParticipant(
        uint256 proposalId,
        address voter
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].isParticipant[voter] = true;
        proposals[proposalId].numOfParticipants++;
    }

    /**
     * @notice Removes a participant from a proposal
     * @dev Only authorized callers can remove participants
     * @param proposalId ID of the target proposal
     * @param voter Address of the participant
     */
    function removeParticipant(
        uint256 proposalId,
        address voter
    ) external onlyAuthorizedCaller(msg.sender) {
        proposals[proposalId].isParticipant[voter] = false;
        proposals[proposalId].numOfParticipants--;
    }

    /**
     * @notice Tallies the votes for a proposal
     * @dev Only authorized callers can tally votes
     * @param proposalId ID of the target proposal
     */
    function tallyVotes(uint256 proposalId) public override onlyAuthorizedCaller(msg.sender) {
        Proposal storage proposal = proposals[proposalId];
        uint256 maxVotes = 0;
        bool isDraw = false;

        // Find the maximum number of votes
        for (uint256 i = 0; i < proposal.options.length; i++) {
            uint256 votes = proposal.voteCount[proposal.options[i]];
            if (votes > maxVotes) {
                maxVotes = votes;
                isDraw = false;
            } else if (votes == maxVotes && votes > 0) {
                isDraw = true;
            }
        }

        // Collect winning options
        string[] memory winners = new string[](proposal.options.length);
        uint256 winnerCount = 0;

        for (uint256 i = 0; i < proposal.options.length; i++) {
            if (proposal.voteCount[proposal.options[i]] == maxVotes) {
                winners[winnerCount] = proposal.options[i];
                winnerCount++;
            }
        }

        // Resize winners array to actual size
        string[] memory finalWinners = new string[](winnerCount);
        for (uint256 i = 0; i < winnerCount; i++) {
            finalWinners[i] = winners[i];
        }

        proposal.winners = finalWinners;
        proposal.isDraw = isDraw;
    }

    /**
     * @notice Gets the vote count for a specific option
     * @param proposalId ID of the target proposal
     * @param option Option to get votes for
     * @return Number of votes for the option
     */
    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) public view override returns (uint256) {
        return proposals[proposalId].voteCount[option];
    }

    /**
     * @notice Gets the winning options for a proposal
     * @param proposalId ID of the target proposal
     * @return winners Array of winning options
     * @return isDraw Whether there is a tie
     */
    function getWinners(uint256 proposalId)
        public
        view
        override
        returns (string[] memory, bool)
    {
        return (proposals[proposalId].winners, proposals[proposalId].isDraw);
    }

    /**
     * @notice Checks if an address has participated in a proposal
     * @param proposalId ID of the target proposal
     * @param voter Address to check
     * @return True if the address has participated
     */
    function isParticipant(
        uint256 proposalId,
        address voter
    ) external view returns (bool) {
        return proposals[proposalId].isParticipant[voter];
    }

    /**
     * @notice Decrements the total proposal count
     * @dev Only authorized callers can decrement count
     */
    function decrementProposalCount()
        external
        onlyAuthorizedCaller(msg.sender)
    {
        proposalCount--;
    }

    /**
     * @notice Gets detailed information about a proposal
     * @param proposalId ID of the target proposal
     * @return owner Address of the proposal creator
     * @return title Title of the proposal
     * @return options Array of voting options
     * @return startDate Timestamp when voting begins
     * @return endDate Timestamp when voting ends
     * @return status Current status of the proposal
     * @return voteMutability Whether votes can be changed
     */
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address owner,
            string memory title,
            string[] memory options,
            uint256 startDate,
            uint256 endDate,
            ProposalStatus status,
            VoteMutability voteMutability
        )
    {
        if (!isProposalExists(proposalId)) {
            revert(string(abi.encodePacked("Proposal does not exist: ", proposalId.toString())));
        }

        owner = proposals[proposalId].owner;
        title = proposals[proposalId].title;
        options = proposals[proposalId].options;
        startDate = proposals[proposalId].startDate;
        endDate = proposals[proposalId].endDate;
        status = proposals[proposalId].status;
        voteMutability = proposals[proposalId].voteMutability;
    }

    /**
     * @notice Gets the total number of proposals
     * @return Total number of proposals in the system
     */
    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    /**
     * @notice Gets the number of participants in a proposal
     * @param proposalId ID of the target proposal
     * @return Number of participants
     */
    function getParticipantCount(uint256 proposalId)
        external
        view
        returns (uint256)
    {
        return proposals[proposalId].numOfParticipants;
    }

    /**
     * @notice Checks if a proposal has been finalized
     * @param proposalId ID of the target proposal
     * @return True if the proposal is finalized
     */
    function isProposalFinalized(uint256 proposalId)
        external
        view
        returns (bool)
    {
        return proposals[proposalId].status == ProposalStatus.FINALIZED;
    }

    /**
     * @notice Checks if a voting option exists for a proposal
     * @param proposalId ID of the target proposal
     * @param option Option to check
     * @return True if the option exists
     */
    function optionExists(
        uint256 proposalId,
        string calldata option
    ) external view returns (bool) {
        return proposals[proposalId].optionExistence[option];
    }

    /**
     * @notice Gets the voting options for a proposal
     * @param proposalId ID of the target proposal
     * @return Array of voting options
     */
    function getProposalOptions(uint256 proposalId)
        external
        view
        returns (string[] memory)
    {
        return proposals[proposalId].options;
    }

    /**
     * @notice Checks if a proposal exists
     * @param proposalId ID of the target proposal
     * @return True if the proposal exists
     */
    function isProposalExists(uint256 proposalId) public view returns (bool) {
        return proposals[proposalId].id != 0;
    }
}
