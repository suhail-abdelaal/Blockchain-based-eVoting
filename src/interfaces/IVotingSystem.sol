// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVotingSystem {
    function createProposal(
        string calldata title,
        string[] calldata options,
        uint256 startTime,
        uint256 endTime
    ) external returns (uint256);

    function castVote(uint256 proposalId, string memory option) external;

    function retractVote(uint256 proposalId) external;

    function changeVote(uint256 proposalId, string memory newOption) external;

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function verifyVoter(address voter) external;

    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) external view returns (uint256);

    function getProposalCount() external view returns (uint256);

    function getProposalWinner(uint256 proposalId)
        external
        returns (string[] memory winners, bool isDraw);

    function getProposalManager() external view returns (address);

    function getVoterManager() external view returns (address);
}
