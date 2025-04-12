// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RBAC} from "./RBAC.sol";

contract VoterRegistry is RBAC {
    /* Erros and Events */
    error VoterAlreadyVerified(address voter);
    error ProposalNotFound(uint256 proposalId);
    error RecordAlreadyExists(address voter, uint256 proposalId);

    event VoterVerified(address indexed voter);

    /* User Defined Datatypes */
    struct Voter {
        string name;
        bool isVerified;
        uint256[] featureVector;
        uint256[] participatedProposalsId;
        mapping(uint256 proposalId => uint256 proposalIdx) participatedProposalIndex;
        mapping(uint256 => string) selectedOption;
        mapping(uint256 proposalId => uint256 proposalIdx) createdProposalIndex;
        uint256[] createdProposalsId;
    }

    /* State Variables */
    mapping(address => Voter) public voters;
    mapping(address voter => mapping(uint256 proposalId => string option)) public systemLog;

    /* Constructor */
    constructor() {
    }


    /* Public Methods */
    function verifyVoter(
        address _voter,
        string calldata _voterName,
        uint256[] calldata _featureVector
        ) external onlyAdmin {


        if (voters[_voter].isVerified) {
            revert VoterAlreadyVerified(_voter);
        }

        // register voter
        voters[_voter].name = _voterName;
        voters[_voter].isVerified = true;
        for (uint256 i = 0; i < _featureVector.length; ++i) {
            voters[_voter].featureVector.push(_featureVector[i]);
        }

        // verify voter
        _verifyVoter(_voter);

        emit VoterVerified(_voter);
    }

    function getVoterVerification(address _voter) external view returns (bool) {
        return isVoterVerified(_voter);
    }

    function getVoterParticipatedProposals(
        address _voter
        ) external view returns (uint256[] memory) {

        return voters[_voter].participatedProposalsId;
    }

    function getVoterSelectedOption(
        address _voter,
        uint256 _proposalId
        ) external view returns (string memory) {

        return voters[_voter].selectedOption[_proposalId];
    }

    function getVoterCreatedProposals(
        address _voter
        ) external view returns (uint256[] memory) {

        return voters[_voter].createdProposalsId;
    }

    function checkVoterParticipation(address _voter, uint256 _proposalId) public view returns (bool) {
        uint256 index = voters[_voter].participatedProposalIndex[_proposalId];
        return (index == 0) ? false : true;
    }

    function recordUserParticipation(
        address _voter,
        uint256 _proposalId,
        string calldata _selectedOption) external {

        if (voters[_voter].participatedProposalIndex[_proposalId] != 0) {
            revert RecordAlreadyExists(_voter, _proposalId);
        }

        voters[_voter].participatedProposalsId.push(_proposalId);
        voters[_voter].participatedProposalIndex[_proposalId] = voters[_voter].participatedProposalsId.length - 1;
        voters[_voter].selectedOption[_proposalId] = _selectedOption;
    }

    function recordUserCreatedProposal(
        address _voter,
        uint256 _proposalId
        ) external {

        if (voters[_voter].createdProposalIndex[_proposalId] != 0) {
            revert RecordAlreadyExists(_voter, _proposalId);
        }

        voters[_voter].createdProposalsId.push(_proposalId);
        voters[_voter].createdProposalIndex[_proposalId] = voters[_voter].createdProposalsId.length;
    }

    function removeUserParticipation(address _voter, uint256 _proposalId) external {
        Voter storage voter = voters[_voter];

        uint256 index = voter.participatedProposalIndex[_proposalId];
        if (index == 0) revert ProposalNotFound(_proposalId);

        uint256 lastIndex = voter.participatedProposalsId.length - 1;
        uint256 lastProposalId = voter.participatedProposalsId[lastIndex];

        // Swap and pop
        voter.participatedProposalsId[index - 1] = lastProposalId;
        voter.participatedProposalIndex[lastProposalId] = index;

        voter.participatedProposalsId.pop();
        delete voter.participatedProposalIndex[_proposalId];
        delete voter.selectedOption[_proposalId];
    }

    function removeUserProposal(address _voter, uint256 _proposalId) external {
        Voter storage voter = voters[_voter];

        uint256 index = voter.createdProposalIndex[_proposalId];
        if (index == 0) revert ProposalNotFound(_proposalId);

        uint256 lastIndex = voter.createdProposalsId.length - 1;
        uint256 lastProposalId = voter.createdProposalsId[lastIndex];

        // Swap and pop
        voter.createdProposalsId[index - 1] = lastProposalId;
        voter.createdProposalIndex[lastProposalId] = index;

        voter.createdProposalsId.pop();
        delete voter.createdProposalIndex[_proposalId];
    }

}
