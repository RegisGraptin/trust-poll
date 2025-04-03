// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { Filter } from "./IFilters.sol";

struct QueryData {
    uint256 surveyId; // Survey we are analysis
    Filter[][] filters; // Filters apply on each metadata, acts as a AND operation
    euint256 pendingEncryptedResult;
    euint256 pendingSelectedNumber;
    uint256 cursor; // Processing index of the batch
    bool isCompleted; // Is the anlysis completed
    bool isValid; // When completed, indicate if the analysis is invalid or not
    // Store result attributes
    uint256 finalSelectedCount;
    uint256 finalResult;
}

/// IAnalyse interface.
/// Analyse workflow:
/// 1. Create/Register a new analyse
/// 2. Iterate over it
/// 3. Before revealing, verify we have reached the expected threshold
/// 4. Reveal or not the result
interface IAnalyze {
    error UnauthorizePendingQuery();
    error InvalidQueryId();
    error InvalidSurvey();
    error AlreadyCompletedQuery();

    event QueryCreated(uint256 indexed queryId, uint256 indexed surveyId, address analyser);

    /// @notice In case of "invalid" query, meaning we have not reach the expected
    /// threshold number, the `finalSelectedCount` should be equal to 0.
    event QueryCompleted(
        uint256 indexed queryId,
        uint256 indexed surveyId,
        bool isValid,
        uint256 finalSelectedCount,
        uint256 finalResult
    );

    /// @notice Create a new analysis.
    /// @param surveyId Survey we want to analyse.
    /// @param params Filters we want to applied on the user metadata.
    /// @return queryId The id of the query created.
    function createQuery(uint256 surveyId, Filter[][] memory params) external returns (uint256);

    /// @notice Iterate over the query
    /// @dev Helper with a limit of 10.
    /// @param queryId Query we want to execute.
    function executeQuery(uint256 queryId) external;

    /// @notice Iterate over the query
    /// @param queryId Query we want to execute.
    /// @param limit Number of item we want to iterate.
    function executeQuery(uint256 queryId, uint256 limit) external;

    /// @notice Get the data of the query
    /// @param queryId Id of the query.
    /// @return QueryData Data of the query.
    function getQueryData(uint256 queryId) external view returns (QueryData memory);
}
