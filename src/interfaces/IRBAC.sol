// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IRBAC {

    function onlyAdmin() external view;

    function onlyVerifiedVoter() external view;

    function onlyVerifiedAddr(address voter) external view;

    function onlyAuthorizedCaller(address caller) external view;

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function verifyVoter(address voter) external;

    function isVoterVerified(address voter) external view returns (bool);

}
