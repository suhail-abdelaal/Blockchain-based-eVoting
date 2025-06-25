// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IVoteTallying.sol";
import "../interfaces/IProposalState.sol";
import "../access/AccessControlWrapper.sol";

contract VoteTallying is IVoteTallying, AccessControlWrapper {

    IProposalState private proposalState;

    mapping(uint256 => mapping(string => uint256)) private voteCounts;
    mapping(uint256 => string[]) private winners;
    mapping(uint256 => bool) private isDraw;

    constructor(
        address _accessControl,
        address _proposalState
    ) AccessControlWrapper(_accessControl) {
        proposalState = IProposalState(_proposalState);
    }

    function tallyVotes(uint256 proposalId)
        external
        override
        onlyAuthorizedCaller(msg.sender)
        returns (string[] memory, bool)
    {
        // Check if votes have already been tallied
        if (winners[proposalId].length > 0 || isDraw[proposalId]) {
            return getWinningOptions(proposalId);
        }

        // Get all options for this proposal
        string[] memory options = proposalState.getProposalOptions(proposalId);

        if (options.length == 0) return (new string[](0), false);

        // Find the maximum vote count
        uint256 maxVotes = 0;
        for (uint256 i = 0; i < options.length; i++) {
            uint256 currentVotes = voteCounts[proposalId][options[i]];
            if (currentVotes > maxVotes) maxVotes = currentVotes;
        }

        // If no votes were cast, return empty result
        if (maxVotes == 0) {
            setWinners(proposalId, new string[](0), false);
            return (new string[](0), false);
        }

        // Count how many options have the maximum votes
        uint256 winnerCount = 0;
        for (uint256 i = 0; i < options.length; i++) {
            if (voteCounts[proposalId][options[i]] == maxVotes) winnerCount++;
        }

        // Create winners array
        string[] memory winningOptions = new string[](winnerCount);
        uint256 winnerIndex = 0;
        for (uint256 i = 0; i < options.length; i++) {
            if (voteCounts[proposalId][options[i]] == maxVotes) {
                winningOptions[winnerIndex] = options[i];
                winnerIndex++;
            }
        }

        // Determine if it's a draw (multiple winners with same vote count)
        bool draw = winnerCount > 1;

        // Store the results
        setWinners(proposalId, winningOptions, draw);

        return (winningOptions, draw);
    }

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view override returns (uint256) {
        return voteCounts[proposalId][option];
    }

    function getWinningOptions(uint256 proposalId)
        public
        view
        override
        returns (string[] memory, bool)
    {
        return (winners[proposalId], isDraw[proposalId]);
    }

    function incrementVoteCount(
        uint256 proposalId,
        string calldata option
    ) external onlyAuthorizedCaller(msg.sender) {
        voteCounts[proposalId][option]++;
    }

    function decrementVoteCount(
        uint256 proposalId,
        string calldata option
    ) external onlyAuthorizedCaller(msg.sender) {
        voteCounts[proposalId][option]--;
    }

    function setWinners(
        uint256 proposalId,
        string[] memory _winners,
        bool _isDraw
    ) public onlyAuthorizedCaller(msg.sender) {
        winners[proposalId] = _winners;
        isDraw[proposalId] = _isDraw;
    }

}
