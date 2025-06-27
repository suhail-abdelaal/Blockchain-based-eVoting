// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./IProposalState.sol";

interface IProposalManager {

    function createProposal(
        address creator,
        string calldata title,
        string[] memory options,
        IProposalState.VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256);

    function castVote(
        address voter,
        uint256 proposalId,
        string memory option
    ) external;

    function retractVote(address voter, uint256 proposalId) external;

    function changeVote(
        address voter,
        uint256 proposalId,
        string calldata newOption
    ) external;

    function removeUserProposal(address user, uint256 proposalId) external;

    function getVoteCount(
        uint256 proposalId,
        string calldata option
    ) external view returns (uint256);

    function getProposalDetails(uint256 proposalId)
        external
        view
        returns (
            address owner,
            string memory title,
            string[] memory options,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        );

    function updateProposalStatus(uint256 proposalId) external;

    function getProposalCount() external view returns (uint256);

    function getProposalWinnersWithUpdate(uint256 proposalId)
        external
        returns (string[] memory winners, bool isDraw);

    function getProposalWinners(uint256 proposalId)
        external
        view
        returns (string[] memory winners, bool isDraw);

}
