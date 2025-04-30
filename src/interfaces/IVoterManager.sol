// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVoterManager {

    function verifyVoter(
        address voter,
        string calldata voterName,
        uint8 nid,
        uint8[] memory featureVector
    ) external;

    function getVoterParticipatedProposals(address voter)
        external
        view
        returns (uint256[] memory);

    function getVoterSelectedOption(
        address voter,
        uint256 proposalId
    ) external view returns (string memory);

    function getVoterCreatedProposals(address voter)
        external
        view
        returns (uint256[] memory);

    function recordUserParticipation(
        address voter,
        uint256 proposalId,
        string calldata selectedOption
    ) external;

    function recordUserCreatedProposal(
        address voter,
        uint256 proposalId
    ) external;

    function removeUserParticipation(
        address voter,
        uint256 proposalId
    ) external;

    function removeUserProposal(address user, uint256 proposalId) external;

    function getParticipatedProposalsCount(address voter)
        external
        view
        returns (uint256);

    function getCreatedProposalsCount(address voter)
        external
        view
        returns (uint256);

}
