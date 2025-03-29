// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

enum VerifierType {
    LargerThan,
    SmallerThan,
    EqualTo
}

// FIXME: Should we apply a mapping on the type and the acceptable filter?

// FIXME: we need to have an encrypted value which bring some qustion

struct Filter {
    VerifierType verifier;
    bytes value;
}

// TODO: Do we want the query created by someone public?
// We could push the encryption boundaries further, by encrypting the query too
// Or we want transparency on the user data requested?

struct QueryData {
    uint256 surveyId;
    Filter[][] filters;
    euint256 pendingResult;
    euint256 numberOfSelected; // TODO: naming counting ?
    uint256 cursor; // Better Naing PLS
    // FIXME: Need to update the flag
    bool isFinished;
    // Gateway id maybe?
    uint256 selectedCount;
    uint256 result;
}

// 1. Create/Register a new analyse
// 2. Iterate over it
// 2.a Before revealing the data, double check if not sensible
// 3. Reveal the result or not

// Simple int
// Polling yes/no -> yes vote
// Benchmark -> avg metric

interface IAnalyze {
    error UnauthorizePendingQuery();

    function createQuery(uint256 surveyId, Filter[][] memory params) external returns (uint256);

    function executeQuery(uint256 queryId) external;

    // FIXME:
    // function getQueryData(uint256 queryId) external view returns (QueryData memory);
}
