// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RoleBasedAccessControl} from "./AccessControl.sol";

contract VoterRegistry is RoleBasedAccessControl {
    /* Erros and Events */
    error VoterAlreadyVerified(address voter);

    event VoterVerified(address indexed voter);

    /* User Defined Datatypes */
    struct Voter {
        string name;
        bool isVerified;
        uint256[] featureVector;
    }

    /* State Variables */
    mapping(address => Voter) public voters;

    /* Constructor */
    constructor() {}


    /* Public Methods */
    function verifyVoter(
        address _voter,
        string calldata _voterName,
        uint256[] calldata _featureVector
        ) public onlyRole(DEFAULT_ADMIN_ROLE) {

        if (voters[_voter].isVerified) {
            revert VoterAlreadyVerified(_voter);
        }

        // register voter
        voters[_voter].name = _voterName;
        voters[_voter].isVerified = true;
        voters[_voter].featureVector = _featureVector;

        // verify voter
        _grantRole(VERIFIED_VOTER, _voter);

        emit VoterVerified(_voter);
    }

    function getVoterVerification(address _voter) public view returns (bool) {
        return hasRole(VERIFIED_VOTER, _voter);
    }
}
