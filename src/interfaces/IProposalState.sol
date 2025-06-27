// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IProposalState {

    enum ProposalStatus {
        NONE,
        PENDING,
        ACTIVE,
        CLOSED,
        FINALIZED
    }

    enum VoteMutability {
        IMMUTABLE,
        MUTABLE
    }

    function createProposal(
        address creator,
        string calldata title,
        string[] memory options,
        VoteMutability voteMutability,
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256);

    function removeProposal(uint256 proposalId) external;

    function getProposalStatus(uint256 proposalId)
        external
        view
        returns (ProposalStatus);

    function getCurrentProposalStatus(uint256 proposalId)
        external
        returns (ProposalStatus);
    function updateProposalStatus(uint256 proposalId) external;

    function getProposalVoteMutability(uint256 proposalId)
        external
        view
        returns (VoteMutability);

    function isProposalActive(uint256 proposalId)
        external
        view
        returns (bool);

    function isProposalClosed(uint256 proposalId)
        external
        view
        returns (bool);

    function isParticipant(
        uint256 proposalId,
        address voter
    ) external view returns (bool);

    function optionExists(
        uint256 proposalId,
        string calldata option
    ) external view returns (bool);

    function addParticipant(uint256 proposalId, address voter) external;

    function removeParticipant(uint256 proposalId, address voter) external;

    function decrementProposalCount() external;

    function incrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external;

    function decrementVoteCount(
        uint256 proposalId,
        string memory option
    ) external;

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
        );

    function getProposalCount() external view returns (uint256);

    function getParticipantCount(uint256 proposalId)
        external
        view
        returns (uint256);

    function getProposalOptions(uint256 proposalId)
        external
        view
        returns (string[] memory);

    function isProposalExists(uint256 proposalId)
        external
        view
        returns (bool);

    function tallyVotes(uint256 proposalId) external;

    function getVoteCount(
        uint256 proposalId,
        string memory option
    ) external view returns (uint256);

    function getWinners(uint256 proposalId)
        external
        view
        returns (string[] memory, bool);

    function isProposalFinalized(uint256 proposalId) external view returns (bool);

}
