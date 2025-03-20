// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

enum VerifierType {
    LargerThan,
    SmallerThan,
    EqualTo
}

struct Filter {
    VerifierType verifier;
    bytes data;
}

interface IAnalyze {
    function createQuery(uint256 voteId, Filter[][] memory params) external;

    function executeQuery(uint256 queryId) external;

    function resultQuery() external returns (bytes memory);
}

// Simple int
// Polling yes/no -> yes vote
// Benchmark -> avg metric

// Issue when polling has multiple value.
