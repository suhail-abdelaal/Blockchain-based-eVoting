// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RBACWrapper} from "./RBACWrapper.sol";

contract VoterRegistry is RBACWrapper {
    /* Errors and Events */
    error VoterAlreadyVerified(address voter);
    error ProposalNotFound(uint256 proposalId);
    error RecordAlreadyExists(address voter, uint256 proposalId);

    event VoterVerified(address indexed voter);

    /* User Defined Datatypes */
    struct Voter {
        bytes32 name;
        bytes32 name;
        uint256[] featureVector;
        uint256[] participatedProposalsId;
        mapping(uint256 proposalId => uint256 proposalIdx)
            participatedProposalIndex;
        mapping(uint256 => bytes32) selectedOption;
        mapping(uint256 => bytes32) selectedOption;
        mapping(uint256 proposalId => uint256 proposalIdx) createdProposalIndex;
        uint256[] createdProposalsId;
    }

    /* State Variables */
    mapping(address => Voter) public voters;
    mapping(address voter => mapping(uint256 proposalId => bytes32 option))
    mapping(address voter => mapping(uint256 proposalId => bytes32 option))
        public systemLog;

    /* Constructor */
    constructor(
        address _rbac
    ) RBACWrapper(_rbac) {}

    /* Public Methods */
    function verifyVoter(
        address voter,
        string memory voterName,
        string memory voterName,
        uint256[] calldata featureVector
    ) external onlyAdmin(msg.sender) {
        if (isVoterVerified(voter)) revert VoterAlreadyVerified(voter);

        bytes32 bytesVoterName;
        assembly {
            bytesVoterName := mload(add(voterName, 32))
        }
        // register voter
        voters[voter].name = bytesVoterName;
        voters[voter].name = bytesVoterName;
        for (uint256 i = 0; i < featureVector.length; ++i) {
            voters[voter].featureVector.push(featureVector[i]);
        }

        // verify voter
        rbac.verifyVoter(voter, msg.sender);
        rbac.verifyVoter(voter, msg.sender);

        emit VoterVerified(voter);
    }

    function getVoterVerification(
        address voter
    ) external view returns (bool) {
        return isVoterVerified(voter);
    }

    function getVoterParticipatedProposals(
        address voter
    ) external view returns (uint256[] memory) {
        return voters[voter].participatedProposalsId;
    }

    function getVoterSelectedOption(
        address voter,
        uint256 proposalId
    ) external view returns (bytes32) {
    ) external view returns (bytes32) {
        return voters[voter].selectedOption[proposalId];
    }

    function getVoterCreatedProposals(
        address voter
    ) external view returns (uint256[] memory) {
        return voters[voter].createdProposalsId;
    }

    function recordUserParticipation(
        address voter,
        uint256 proposalId,
        bytes32 selectedOption
        bytes32 selectedOption
    ) external {
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
    ) external {
        if (voters[voter].createdProposalIndex[proposalId] != 0) {
            revert RecordAlreadyExists(voter, proposalId);
        }

        voters[voter].createdProposalsId.push(proposalId);
        voters[voter].createdProposalIndex[proposalId] =
            voters[voter].createdProposalsId.length;
    }

    function removeUserParticipation(
        address _voter,
        uint256 proposalId
    ) external {
        Voter storage voter = voters[_voter];

        uint256 index = voter.participatedProposalIndex[proposalId];
        if (index == 0) revert ProposalNotFound(proposalId);

        uint256 lastIndex = voter.participatedProposalsId.length - 1;
        uint256 lastProposalId = voter.participatedProposalsId[lastIndex];

        // Swap and pop
        voter.participatedProposalsId[index - 1] = lastProposalId;
        voter.participatedProposalIndex[lastProposalId] = index;

        voter.participatedProposalsId.pop();
        delete voter.participatedProposalIndex[proposalId];
        delete voter.selectedOption[proposalId];
    }

    function removeUserProposal(address _voter, uint256 proposalId) external {
        Voter storage voter = voters[_voter];

        uint256 index = voter.createdProposalIndex[proposalId];
        if (index == 0) revert ProposalNotFound(proposalId);

        uint256 lastIndex = voter.createdProposalsId.length - 1;
        uint256 lastProposalId = voter.createdProposalsId[lastIndex];

        // Swap and pop
        voter.createdProposalsId[index - 1] = lastProposalId;
        voter.createdProposalIndex[lastProposalId] = index;

        voter.createdProposalsId.pop();
        delete voter.createdProposalIndex[proposalId];
    }

    function getParticipatedProposalsCount(
        address voter
    ) external view returns (uint256) {
        return voters[voter].participatedProposalsId.length;
    }

    function getCreatedProposalsCount(
        address voter
    ) external view returns (uint256) {
        return voters[voter].createdProposalsId.length;
    }
}
