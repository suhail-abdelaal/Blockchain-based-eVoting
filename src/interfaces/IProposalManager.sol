// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IProposalManager {

    function addProposal(
        address creator,
        string memory title,
        string[] memory options,
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
        string memory newOption
    ) external;

    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) external view returns (uint256);

    function getProposalDetails(uint256 proposalId)
        external
        returns (
            string memory title,
            string[] memory options,
            uint256 startDate,
            uint256 endDate,
            address owner,
            bool isDraw,
            string[] memory winners
        );

    function getProposalCount() external view returns (uint256);

    function getProposalWinner(uint256 proposalId)
        external
        returns (string[] memory winners, bool isDraw);

}
