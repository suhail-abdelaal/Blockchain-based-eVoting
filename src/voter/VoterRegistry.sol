// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IVoterManager.sol";
import "../access/AccessControlWrapper.sol";

contract VoterRegistry is IVoterManager, AccessControlWrapper {

    event VoterVerified(address indexed voter);

    struct Voter {
        uint64 NID;
        int256[] embeddings;
        uint256[] participatedProposalsId;
        mapping(uint256 => uint256) participatedProposalIndex;
        mapping(uint256 => string) selectedOption;
        uint256[] createdProposalsId;
        mapping(uint256 => uint256) createdProposalIndex;
    }

    mapping(address => Voter) public voters;
    mapping(uint64 => bool) private nidRegistered;

    constructor(address _accessControl) AccessControlWrapper(_accessControl) {}

    function registerVoter(
        address voter,
        uint64 nid,
        int256[] memory embeddings
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (isVoterVerified(voter)) {
            revert(string(abi.encodePacked("Voter already registered: ", _addressToString(voter))));
        }

        voters[voter].embeddings = embeddings;
        voters[voter].NID = nid;
        nidRegistered[nid] = true;

        emit VoterVerified(voter);
    }

    function isNidRegistered(uint64 nid) external view returns (bool) {
        return nidRegistered[nid];
    }

    function recordUserParticipation(
        address voter,
        uint256 proposalId,
        string calldata selectedOption
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (voters[voter].participatedProposalIndex[proposalId] != 0) {
            revert(string(abi.encodePacked("Participation record already exists for voter ", _addressToString(voter), " in proposal ", _uintToString(proposalId))));
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
            revert(string(abi.encodePacked("Created proposal record already exists for voter ", _addressToString(voter), " and proposal ", _uintToString(proposalId))));
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
            revert(string(abi.encodePacked("Participation not found for voter ", _addressToString(voter), " in proposal ", _uintToString(proposalId))));
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
            revert(string(abi.encodePacked("Created proposal not found for user ", _addressToString(user), " and proposal ", _uintToString(proposalId))));
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

    /**
     * @dev Convert address to string
     */
    function _addressToString(address addr) private pure returns (string memory) {
        return _toHexString(uint256(uint160(addr)), 20);
    }

    /**
     * @dev Convert uint to string
     */
    function _uintToString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 tempValue = value;
        while (tempValue != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(tempValue % 10)));
            tempValue /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Convert to hex string
     */
    function _toHexString(uint256 value, uint256 length) private pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        uint256 tempValue = value;
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[tempValue & 0xf];
            tempValue >>= 4;
        }
        require(tempValue == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

}
