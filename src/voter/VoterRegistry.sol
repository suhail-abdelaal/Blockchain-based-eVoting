// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IVoterManager.sol";
import "../access/AccessControlWrapper.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title VoterRegistry
 * @author Suhail Abdelaal
 * @notice Manages voter registration and participation tracking
 * @dev Implements IVoterManager interface for voter management
 */
contract VoterRegistry is IVoterManager, AccessControlWrapper {

    using Strings for address;
    using Strings for uint256;

    /**
     * @notice Emitted when a voter is verified
     * @param voter Address of the verified voter
     */
    event VoterVerified(address indexed voter);

    /**
     * @notice Emitted when a voter is unregistered
     * @param voter Address of the unregistered voter
     */
    event VoterUnregistered(address indexed voter);

    /**
     * @notice Struct to store voter information and participation history
     * @dev Uses mappings for efficient lookup of proposal participation
     */
    struct Voter {
        bytes32 NID;                                    // National ID hash
        int256[] embeddings;                           // Biometric embeddings
        uint256[] participatedProposalsId;            // List of proposals voted in
        mapping(uint256 => uint256) participatedProposalIndex;  // Proposal ID to index mapping
        mapping(uint256 => string) selectedOption;     // Selected options in proposals
        uint256[] createdProposalsId;                 // List of created proposals
        mapping(uint256 => uint256) createdProposalIndex;      // Created proposal ID to index mapping
    }

    mapping(address => Voter) public voters;
    mapping(bytes32 => bool) private nidRegistered;

    /**
     * @notice Initializes the VoterRegistry contract
     * @param _accessControl Address of the access control contract
     */
    constructor(address _accessControl) AccessControlWrapper(_accessControl) {}

    /**
     * @notice Registers a new voter
     * @dev Only authorized callers can register voters
     * @param voter Address to register
     * @param nid National ID hash
     * @param embeddings Biometric embeddings for verification
     */
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

    /**
     * @notice Unregisters a voter
     * @dev Only authorized callers can unregister voters
     * @param voter Address to unregister
     */
    function unRegisterVoter(
        address voter
    ) external override onlyAuthorizedCaller(msg.sender) {
        if (!isVoterVerified(voter)) {
            revert(string(abi.encodePacked("Voter not registered: ", voter.toHexString())));
        }

        nidRegistered[voters[voter].NID] = false;
        delete voters[voter];
        emit VoterUnregistered(voter);
    }

    /**
     * @notice Checks if a national ID is registered
     * @param nid National ID hash to check
     * @return bool True if the NID is registered
     */
    function isNidRegistered(bytes32 nid) external view returns (bool) {
        return nidRegistered[nid];
    }

    /**
     * @notice Gets all proposals a voter has participated in
     * @param voter Address of the voter
     * @return Array of proposal IDs the voter has participated in
     */
    function getVoterParticipatedProposals(address voter)
        external
        view
        override
        returns (uint256[] memory)
    {
        return voters[voter].participatedProposalsId;
    }

    /**
     * @notice Gets the option selected by a voter in a proposal
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     * @return Selected option by the voter
     */
    function getVoterSelectedOption(
        address voter,
        uint256 proposalId
    ) external view override returns (string memory) {
        return voters[voter].selectedOption[proposalId];
    }

    /**
     * @notice Gets all proposals created by a voter
     * @param voter Address of the voter
     * @return Array of proposal IDs created by the voter
     */
    function getVoterCreatedProposals(address voter)
        external
        view
        override
        returns (uint256[] memory)
    {
        return voters[voter].createdProposalsId;
    }

    /**
     * @notice Records a voter's participation in a proposal
     * @dev Only authorized callers can record participation
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     * @param selectedOption Option selected by the voter
     */
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

    /**
     * @notice Records a proposal created by a voter
     * @dev Only authorized callers can record proposal creation
     * @param voter Address of the voter
     * @param proposalId ID of the created proposal
     */
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

    /**
     * @notice Removes a voter's participation record from a proposal
     * @dev Only authorized callers can remove participation records
     * @param voter Address of the voter
     * @param proposalId ID of the target proposal
     */
    function removeUserParticipation(
        address voter,
        uint256 proposalId
    ) external override onlyAuthorizedCaller(msg.sender) {
        uint256 index = voters[voter].participatedProposalIndex[proposalId];
        if (index == 0) {
            revert(string(abi.encodePacked("Voter ", voter.toHexString(), " has not participated in proposal ", proposalId.toString())));
        }
        index--;

        uint256 lastIndex = voters[voter].participatedProposalsId.length - 1;
        if (index != lastIndex) {
            uint256 lastProposalId = voters[voter].participatedProposalsId[lastIndex];
            voters[voter].participatedProposalsId[index] = lastProposalId;
            voters[voter].participatedProposalIndex[lastProposalId] = index + 1;
        }

        voters[voter].participatedProposalsId.pop();
        delete voters[voter].participatedProposalIndex[proposalId];
        delete voters[voter].selectedOption[proposalId];
    }

    /**
     * @notice Removes a proposal created by a voter
     * @dev Only authorized callers can remove proposals
     * @param user Address of the voter
     * @param proposalId ID of the proposal to remove
     */
    function removeUserProposal(
        address user,
        uint256 proposalId
    ) external override onlyAuthorizedCaller(msg.sender) {
        uint256 index = voters[user].createdProposalIndex[proposalId];
        if (index == 0) {
            revert(string(abi.encodePacked("User ", user.toHexString(), " has not created proposal ", proposalId.toString())));
        }
        index--;

        uint256 lastIndex = voters[user].createdProposalsId.length - 1;
        if (index != lastIndex) {
            uint256 lastProposalId = voters[user].createdProposalsId[lastIndex];
            voters[user].createdProposalsId[index] = lastProposalId;
            voters[user].createdProposalIndex[lastProposalId] = index + 1;
        }

        voters[user].createdProposalsId.pop();
        delete voters[user].createdProposalIndex[proposalId];
    }

    /**
     * @notice Gets the number of proposals a voter has participated in
     * @param voter Address of the voter
     * @return Number of proposals participated in
     */
    function getParticipatedProposalsCount(
        address voter
    ) external view override returns (uint256) {
        return voters[voter].participatedProposalsId.length;
    }

    /**
     * @notice Gets the number of proposals created by a voter
     * @param voter Address of the voter
     * @return Number of proposals created
     */
    function getCreatedProposalsCount(
        address voter
    ) external view override returns (uint256) {
        return voters[voter].createdProposalsId.length;
    }

    /**
     * @notice Gets the biometric embeddings for a voter
     * @param voter Address of the voter
     * @return Array of biometric embedding values
     */
    function getVoterEmbeddings(
        address voter
    ) external view override returns (int256[] memory) {
        return voters[voter].embeddings;
    }


}
