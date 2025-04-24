// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// ------------------- Imports -------------------

import {RBACWrapper} from "./RBACWrapper.sol";
import {IVoterManager} from "./interfaces/IVoterManager.sol";

// ------------------- Contract -------------------

contract VoterManager is IVoterManager, RBACWrapper {

    // ------------------- Errors and Events -------------------

    error VoterAlreadyVerified(address voter);
    error ProposalNotFound(uint256 proposalId);
    error RecordAlreadyExists(address voter, uint256 proposalId);

    event VoterVerified(address indexed voter);

    // ------------------- State Variables -------------------

    struct Voter {
        string name;
        uint256[] featureVector;
        uint256[] participatedProposalsId;
        mapping(uint256 => uint256) participatedProposalIndex;
        mapping(uint256 => string) selectedOption;
        mapping(uint256 => uint256) createdProposalIndex;
        uint256[] createdProposalsId;
    }

    mapping(address => Voter) public voters;
    mapping(address => mapping(uint256 => string)) public systemLog;

    // ------------------- Constructor -------------------

    constructor(address _rbac) RBACWrapper(_rbac) {}

    // ------------------- External Methods -------------------

    function verifyVoter(
        address voter,
        string calldata voterName,
        uint256[] calldata featureVector
    ) external onlyAdmin {
        if (isVoterVerified(voter)) revert VoterAlreadyVerified(voter);

        // Register voter
        voters[voter].name = voterName;
        for (uint256 i = 0; i < featureVector.length; ++i) {
            voters[voter].featureVector.push(featureVector[i]);
        }

        // Verify voter
        rbac.verifyVoter(voter);

        emit VoterVerified(voter);
    }

    function recordUserParticipation(
        address voter,
        uint256 proposalId,
        string calldata selectedOption
    ) external onlyAuthorizedCaller(msg.sender) {
        if (voters[voter].participatedProposalIndex[proposalId] != 0) {
            revert RecordAlreadyExists(voter, proposalId);
        }

        voters[voter].participatedProposalsId.push(proposalId);
        voters[voter].participatedProposalIndex[proposalId] =
            voters[voter].participatedProposalsId.length;
        voters[voter].selectedOption[proposalId] = selectedOption;
    }

    function recordUserCreatedProposal(
        address voter,
        uint256 proposalId
    ) external onlyAuthorizedCaller(msg.sender) {
        if (voters[voter].createdProposalIndex[proposalId] != 0) {
            revert RecordAlreadyExists(voter, proposalId);
        }

        voters[voter].createdProposalsId.push(proposalId);
        voters[voter].createdProposalIndex[proposalId] =
            voters[voter].createdProposalsId.length;
    }

    function removeUserParticipation(
        address voter,
        uint256 proposalId
    ) external onlyAuthorizedCaller(msg.sender) {
        Voter storage voterData = voters[voter];

        uint256 index = voterData.participatedProposalIndex[proposalId];
        if (index == 0) revert ProposalNotFound(proposalId);

        uint256 lastIndex = voterData.participatedProposalsId.length - 1;
        uint256 lastProposalId = voterData.participatedProposalsId[lastIndex];

        // Swap and pop
        voterData.participatedProposalsId[index - 1] = lastProposalId;
        voterData.participatedProposalIndex[lastProposalId] = index;

        voterData.participatedProposalsId.pop();
        delete voterData.participatedProposalIndex[proposalId];
        delete voterData.selectedOption[proposalId];
    }

    function removeUserProposal(
        address user,
        uint256 proposalId
    ) external onlyAuthorizedCaller(msg.sender) {
        Voter storage userData = voters[user];

        uint256 index = userData.createdProposalIndex[proposalId];
        if (index == 0) revert ProposalNotFound(proposalId);

        uint256 lastIndex = userData.createdProposalsId.length - 1;
        uint256 lastProposalId = userData.createdProposalsId[lastIndex];

        // Swap and pop
        userData.createdProposalsId[index - 1] = lastProposalId;
        userData.createdProposalIndex[lastProposalId] = index;

        userData.createdProposalsId.pop();
        delete userData.createdProposalIndex[proposalId];
    }

    function getVoterVerification(address voter) external view returns (bool) {
        return isVoterVerified(voter);
    }

    function getVoterParticipatedProposals(address voter)
        external
        view
        returns (uint256[] memory)
    {
        return voters[voter].participatedProposalsId;
    }

    function getVoterSelectedOption(
        address voter,
        uint256 proposalId
    ) external view returns (string memory) {
        return voters[voter].selectedOption[proposalId];
    }

    function getVoterCreatedProposals(address voter)
        external
        view
        returns (uint256[] memory)
    {
        return voters[voter].createdProposalsId;
    }

    function getParticipatedProposalsCount(address voter)
        external
        view
        returns (uint256)
    {
        return voters[voter].participatedProposalsId.length;
    }

    function getCreatedProposalsCount(address voter)
        external
        view
        returns (uint256)
    {
        return voters[voter].createdProposalsId.length;
    }

}
