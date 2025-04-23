// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVoterManager {
    function verifyVoter(
        address voter,
        string memory voterName,
        uint256[] calldata featureVector
    ) external;

    function getVoterVerification(address voter) external view returns (bool);

    function getVoterParticipatedProposals(address voter)
        external
        view
        returns (uint256[] memory);

    function getVoterSelectedOption(
        address voter,
        uint256 proposalId
    ) external view returns (bytes32);

    function getVoterCreatedProposals(address voter)
        external
        view
        returns (uint256[] memory);

    function recordUserParticipation(
        address voter,
        uint256 proposalId,
        bytes32 selectedOption
    ) external;

    function recordUserCreatedProposal(
        address voter,
        uint256 proposalId
    ) external;

    function removeUserParticipation(
        address voter,
        uint256 proposalId
    ) external;

    function removeUserProposal(address voter, uint256 proposalId) external;

    function getParticipatedProposalsCount(address voter)
        external
        view
        returns (uint256);

    function getCreatedProposalsCount(address voter)
        external
        view
        returns (uint256);
}
