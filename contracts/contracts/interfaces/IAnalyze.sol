// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { Filter } from "./IFilters.sol";

// FIXME: Should we apply a mapping on the type and the acceptable filter?

// FIXME: we need to have an encrypted value which bring some qustion

// TODO: Do we want the query created by someone public?
// We could push the encryption boundaries further, by encrypting the query too
// Or we want transparency on the user data requested?

struct QueryData {
    uint256 surveyId; // Survey we are analysis
    Filter[][] filters; // Filters apply on each metadata, acts as a AND operation
    euint256 pendingEncryptedResult;
    euint256 pendingSelectedNumber;
    uint256 cursor; // Processing index of the batch
    bool isCompleted; // Is the anlysis completed
    bool isInvalid; // When completed, indicate if the analysis is invalid or not
    // Store result attributes
    uint256 finalSelectedCount;
    uint256 finalResult;
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
    error InvalidQueryId();
    error InvalidSurvey();
    error AlreadyCompletedQuery();

    event QueryCreated(uint256 indexed queryId, uint256 indexed surveyId, address analyser);

    function createQuery(uint256 surveyId, Filter[][] memory params) external returns (uint256);

    function executeQuery(uint256 queryId) external;

    function executeQuery(uint256 queryId, uint256 limit) external;

    function getQueryData(uint256 queryId) external view returns (QueryData memory);
}
