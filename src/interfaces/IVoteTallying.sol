// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVoteTallying {

    function incrementVoteCount(
        uint256 proposalId,
        string calldata option
    ) external;
    function decrementVoteCount(
        uint256 proposalId,
        string calldata option
    ) external;
    function tallyVotes(uint256 proposalId)
        external
        returns (string[] memory winners, bool isDraw);
    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view returns (uint256);
    function getWinningOptions(uint256 proposalId)
        external
        view
        returns (string[] memory winners, bool isDraw);
    function setWinners(
        uint256 proposalId,
        string[] memory winners,
        bool isDraw
    ) external;

}
