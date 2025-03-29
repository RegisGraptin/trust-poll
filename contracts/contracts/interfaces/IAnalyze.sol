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
    uint256 surveyId; // Survey we are analysis
    Filter[][] filters; // Filters apply on each metadata, acts as a AND operation
    euint256 pendingResult;
    euint256 numberOfSelected; // TODO: naming counting ?
    uint256 cursor; // Better Naing PLS
    // FIXME: Need to update the flag
    bool isCompleted;
    bool isInvalid;
    // Gateway id maybe?
    uint256 selectedCount;
    uint256 result;
}

// TODO: Review all the naming for the structure

// /// @title Analysis Execution State
// /// @notice Tracks progress and results of a data analysis operation
// struct AnalysisJob {
//     /// @notice Reference ID of the survey being analyzed
//     uint256 surveyId;
//     /// @notice Nested filter sets applied sequentially (AND between arrays, OR within)
//     FilterGroup[] filterGroups;
//     /// @notice Intermediate encrypted result before final computation
//     euint256 intermediateEncryptedResult;
//     /// @notice Number of records matching current filter stage
//     uint256 filteredRecordCount;
//     /// @notice Position tracking for batch processing
//     uint256 processingBatchIndex;
//     /// @notice Flag indicating if analysis reached final state
//     bool isFinalized;
//     /// @notice Flag indicating irrecoverable processing errors
//     bool hasValidationErrors;
//     /// @notice Validated result count after integrity checks
//     uint256 validatedResultCount;
//     /// @notice Final decrypted analysis outcome
//     uint256 finalDecryptedOutcome;
//     /// @notice Identifier for external computation gateway (if used)
//     uint256 gatewayId;
// }

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
    error AlreadyCompletedQuery();

    event QueryCreated(uint256 indexed queryId, uint256 indexed surveyId, address analyser);

    function createQuery(uint256 surveyId, Filter[][] memory params) external returns (uint256);

    function executeQuery(uint256 queryId) external;

    function executeQuery(uint256 queryId, uint256 limit) external;

    function getQueryData(uint256 queryId) external view returns (QueryData memory);
}
