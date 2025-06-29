// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IVoterManager.sol";
import "../access/AccessControlWrapper.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VoterRegistry is IVoterManager, AccessControlWrapper {

    using Strings for address;
    using Strings for uint256;

    event VoterVerified(address indexed voter);
    event VoterUnregistered(address indexed voter);

    struct Voter {
        bytes32 NID;
        int256[] embeddings;
        uint256[] participatedProposalsId;
        mapping(uint256 => uint256) participatedProposalIndex;
        mapping(uint256 => string) selectedOption;
        uint256[] createdProposalsId;
        mapping(uint256 => uint256) createdProposalIndex;
    }

    mapping(address => Voter) public voters;
    mapping(bytes32 => bool) private nidRegistered;

    constructor(address _accessControl) AccessControlWrapper(_accessControl) {}

    function registerVoter(
        address voter,
        bytes32 nid,
        int256[] memory embeddings
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (isVoterVerified(voter)) {
            revert(string(abi.encodePacked("Voter already registered: ", voter.toHexString())));
        }

        voters[voter].embeddings = embeddings;
        voters[voter].NID = nid;
        nidRegistered[nid] = true;

        emit VoterVerified(voter);
    }

    function unRegisterVoter(
        address voter
    ) external override onlyAdmin {
        if (!isVoterVerified(voter)) {
            revert(string(abi.encodePacked("Voter not registered: ", voter.toHexString())));
        }

        nidRegistered[voters[voter].NID] = false;
        delete voters[voter];
        emit VoterUnregistered(voter);
    }

    function isNidRegistered(bytes32 nid) external view returns (bool) {
        return nidRegistered[nid];
    }

    function recordUserParticipation(
        address voter,
        uint256 proposalId,
        string calldata selectedOption
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (voters[voter].participatedProposalIndex[proposalId] != 0) {
            revert(string(abi.encodePacked("Participation record already exists for voter ", voter.toHexString(), " in proposal ", proposalId.toString())));
        }

        voters[voter].participatedProposalsId.push(proposalId);
        voters[voter].participatedProposalIndex[proposalId] =
            voters[voter].participatedProposalsId.length;
        voters[voter].selectedOption[proposalId] = selectedOption;
    }

    function recordUserCreatedProposal(
        address voter,
        uint256 proposalId
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (voters[voter].createdProposalIndex[proposalId] != 0) {
            revert(string(abi.encodePacked("Created proposal record already exists for voter ", voter.toHexString(), " and proposal ", proposalId.toString())));
        }

        voters[voter].createdProposalsId.push(proposalId);
        voters[voter].createdProposalIndex[proposalId] =
            voters[voter].createdProposalsId.length;
    }

    function removeUserParticipation(
        address voter,
        uint256 proposalId
    ) external override onlyAuthorizedCaller(msg.sender) {
        Voter storage voterData = voters[voter];

        uint256 index = voterData.participatedProposalIndex[proposalId];
        if (index == 0) {
            revert(string(abi.encodePacked("Participation not found for voter ", voter.toHexString(), " in proposal ", proposalId.toString())));
        }

        uint256 lastIndex = voterData.participatedProposalsId.length - 1;
        uint256 lastProposalId = voterData.participatedProposalsId[lastIndex];

        voterData.participatedProposalsId[index - 1] = lastProposalId;
        voterData.participatedProposalIndex[lastProposalId] = index;

        voterData.participatedProposalsId.pop();
        delete voterData.participatedProposalIndex[proposalId];
        delete voterData.selectedOption[proposalId];
    }

    function removeUserProposal(
        address user,
        uint256 proposalId
    ) external override onlyAuthorizedCaller(msg.sender) {
        Voter storage userData = voters[user];

        uint256 index = userData.createdProposalIndex[proposalId];
        if (index == 0) {
            revert(string(abi.encodePacked("Created proposal not found for user ", user.toHexString(), " and proposal ", proposalId.toString())));
        }

        uint256 lastIndex = userData.createdProposalsId.length - 1;
        uint256 lastProposalId = userData.createdProposalsId[lastIndex];

        userData.createdProposalsId[index - 1] = lastProposalId;
        userData.createdProposalIndex[lastProposalId] = index;

        userData.createdProposalsId.pop();
        delete userData.createdProposalIndex[proposalId];
    }

    function getVoterParticipatedProposals(address voter)
        external
        view
        override
        returns (uint256[] memory)
    {
        return voters[voter].participatedProposalsId;
    }

    function getVoterSelectedOption(
        address voter,
        uint256 proposalId
    ) external view override returns (string memory) {
        return voters[voter].selectedOption[proposalId];
    }

    function getVoterCreatedProposals(address voter)
        external
        view
        override
        returns (uint256[] memory)
    {
        return voters[voter].createdProposalsId;
    }

    function getParticipatedProposalsCount(address voter)
        external
        view
        override
        returns (uint256)
    {
        return voters[voter].participatedProposalsId.length;
    }

    function getCreatedProposalsCount(address voter)
        external
        view
        override
        returns (uint256)
    {
        return voters[voter].createdProposalsId.length;
    }

    function getVoterEmbeddings(address voter)
        external
        view
        override
        returns (int256[] memory)
    {
        return voters[voter].embeddings;
    }


}
