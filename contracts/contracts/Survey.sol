// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { Filter, MetadataType } from "./interfaces/IFilter.sol";
import { MetadataVerifier } from "./MetadataVerifier.sol";

import { ISurvey, SurveyParams, SurveyData, VoteData } from "./interfaces/ISurvey.sol";
import { IAnalyze, QueryData } from "./interfaces/IAnalyze.sol";

struct GatewayUserEntry {
    uint256 surveyId;
    uint256 voteId;
}

/// @title Trust Poll - Confidential Survey powered by FHE
/// @dev This contract manages confidentia survey.
///
/// On the protocol, anyone can create a new survey. It
contract Survey is ISurvey, IAnalyze, SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller {
    /// @notice Delay of the Zama's gateway to decrypt the data
    uint256 constant MAX_GATEWAY_DELAY = 100;

    uint256 private _surveyIds;
    mapping(uint256 surveyId => SurveyParams) _surveyParams;
    mapping(uint256 surveyId => SurveyData) _surveyData;

    mapping(uint256 surveyId => VoteData[]) public voteData;
    mapping(uint256 surveyId => mapping(address userAddress => bool)) public hasVoted;

    uint256 private _queryIds;
    mapping(uint256 => QueryData) public queryData;

    // Gateway helper to retrieved context data
    mapping(uint256 requestId => uint256 surveyId) gatewayRequestIdToSurveyId;
    mapping(uint256 requestId => GatewayUserEntry) gatewayRequestIdToConfirmUserEntry;

    /// @notice Verifier used for the metadata filtering and validation
    MetadataVerifier _verifier;

    constructor() {
        _verifier = new MetadataVerifier();
    }

    //////////////////////////////////////////////////////////////////
    /// View functions
    //////////////////////////////////////////////////////////////////

    function surveyParams(uint256 surveyId) external view returns (SurveyParams memory) {
        return _surveyParams[surveyId];
    }

    function surveyData(uint256 surveyId) external view returns (SurveyData memory) {
        return _surveyData[surveyId];
    }

    //////////////////////////////////////////////////////////////////
    /// Survey management
    //////////////////////////////////////////////////////////////////

    function createSurvey(SurveyParams memory params) external returns (uint256) {
        // Have a valid prompt
        if (bytes(params.surveyPrompt).length == 0) revert InvalidSurveyParameter("Survey prompt is empty");

        if (params.isWhitelisted) {
            // Have a valid root hash in case of whitelisted
            if (params.whitelistRootHash == bytes32(0)) {
                revert InvalidSurveyParameter("Whitelist root hash is null");
            }
        }

        // Have a valid end time
        if (params.surveyEndTime < block.timestamp) revert InvalidSurveyParameter("Invalid end time");

        // Have a valid threshold
        if (params.minResponseThreshold <= 3) revert InvalidSurveyParameter("Invalid minimum response threshold");

        euint256 eResponses = TFHE.asEuint256(0);
        TFHE.allowThis(eResponses);

        _surveyParams[_surveyIds] = params;
        _surveyData[_surveyIds] = SurveyData({
            currentParticipants: 0,
            encryptedResponses: eResponses,
            finalResult: 0,
            isCompleted: false,
            isValid: false
        });

        emit SurveyCreated(_surveyIds, msg.sender, params.surveyType, params.surveyPrompt);
        _surveyIds++;

        return _surveyIds - 1;
    }

    function _confirmUserEntry(uint256 surveyId, uint256 voteId) internal {
        // Add the vote to the poll
        _surveyData[surveyId].encryptedResponses = TFHE.add(
            _surveyData[surveyId].encryptedResponses,
            voteData[surveyId][voteId].data
        );
        _surveyData[surveyId].currentParticipants++;
        TFHE.allowThis(_surveyData[surveyId].encryptedResponses);

        // Validate the user vote
        voteData[surveyId][voteId].isValid = true;

        // Confirm the user entry
        emit ConfirmUserEntry(surveyId, voteData[surveyId][voteId].userAddress, true);
    }

    function _checkSurveyValidity(uint256 surveyId) internal view {
        if (surveyId >= _surveyIds) revert InvalidSurveyId();
        if (block.timestamp >= _surveyParams[surveyId].surveyEndTime) revert FinishedSurvey();
        if (hasVoted[surveyId][msg.sender]) revert UserAlreadyVoted();
    }

    /// @dev Some survey might have a list of constraint on the metadata to verify it is correct value.
    /// In that case, we are using the gateway to verify the expected validity of the metadata input.
    /// When no constraints defined, we are skipping this behaviour.
    /// FEATURE: We can think on an incentivize mechanism, when doing a verification on the user metadata.
    function _submitEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof,
        bytes32[] memory whitelistProof
    ) internal {
        _checkSurveyValidity(surveyId);

        if (_surveyParams[surveyId].metadataTypes.length != metadata.length) {
            revert InvalidUserMetadata();
        }

        // In case of whitelisted survey, check the user access
        if (_surveyParams[surveyId].isWhitelisted) {
            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
            if (!MerkleProof.verify(whitelistProof, _surveyParams[surveyId].whitelistRootHash, leaf)) {
                revert InvalidMerkleProof();
            }
        }

        // Check metadata type
        uint256[] memory checkedMetadataValue = new uint256[](_surveyParams[surveyId].metadataTypes.length);
        for (uint256 i = 0; i < _surveyParams[surveyId].metadataTypes.length; i++) {
            MetadataType _type = _surveyParams[surveyId].metadataTypes[i];

            if (_type == MetadataType.BOOLEAN) {
                ebool val = TFHE.asEbool(metadata[i], inputProof);
                checkedMetadataValue[i] = ebool.unwrap(val);
                TFHE.allowThis(val);
                TFHE.allow(val, address(_verifier));
            } else if (_type == MetadataType.UINT256) {
                euint256 val = TFHE.asEuint256(metadata[i], inputProof);
                checkedMetadataValue[i] = euint256.unwrap(val);
                TFHE.allowThis(val);
                TFHE.allow(val, address(_verifier));
            }
        }

        // Save the entry and then call the gateway to verify it
        euint256 eVote = TFHE.asEuint256(eInputVote, inputProof);
        TFHE.allowThis(eVote);

        VoteData memory _voteData = VoteData({
            userAddress: msg.sender,
            data: eVote,
            metadata: checkedMetadataValue,
            isValid: false
        });
        voteData[surveyId].push(_voteData);

        // Add user to the hasvoted list
        hasVoted[surveyId][msg.sender] = true;

        // Emit event
        emit EntrySubmitted(surveyId, msg.sender);

        // Verification of the user metadata
        if (_surveyParams[surveyId].constraints.length > 0) {
            ebool isValid = _verifier.applyFilterOnMetadata(
                _surveyParams[surveyId].constraints,
                _surveyParams[surveyId].metadataTypes,
                checkedMetadataValue
            );

            // Call the Gateway to verify the user metadata
            uint256[] memory cts = new uint256[](1);
            cts[0] = Gateway.toUint256(isValid);
            uint256 _requestId = Gateway.requestDecryption(
                cts,
                this.gatewayConfirmUserEntry.selector,
                0,
                block.timestamp + MAX_GATEWAY_DELAY,
                false
            );

            gatewayRequestIdToConfirmUserEntry[_requestId] = GatewayUserEntry({
                surveyId: surveyId,
                voteId: voteData[surveyId].length - 1
            });
        } else {
            // If no verification needed save execution cost and validate the user entry
            _confirmUserEntry(surveyId, voteData[surveyId].length - 1);
        }
    }

    function submitEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof
    ) external {
        _submitEntry(surveyId, eInputVote, metadata, inputProof, new bytes32[](0));
    }

    function submitWhitelistedEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof,
        bytes32[] memory whitelistProof
    ) external {
        _submitEntry(surveyId, eInputVote, metadata, inputProof, whitelistProof);
    }

    function revealResults(uint256 surveyId) external {
        if (surveyId >= _surveyIds) {
            revert InvalidSurveyId();
        }

        // Survey must be finished
        // Wait for verification on the encrypted entries
        if (block.timestamp < _surveyParams[surveyId].surveyEndTime + MAX_GATEWAY_DELAY) {
            revert UnfinishedSurvey();
        }

        // Already completed
        if (_surveyData[surveyId].isCompleted) {
            revert ResultAlreadyReveal();
        }

        // Check we have enough participants
        if (_surveyData[surveyId].currentParticipants < _surveyParams[surveyId].minResponseThreshold) {
            _surveyData[surveyId].isCompleted = true;
            emit SurveyCompleted(
                surveyId,
                false,
                _surveyParams[surveyId].surveyType,
                _surveyData[surveyId].currentParticipants,
                0
            );
            return;
        }

        // Decypher the result
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(_surveyData[surveyId].encryptedResponses);
        uint256 _requestId = Gateway.requestDecryption(
            cts,
            this.gatewayDecryptSurveyResult.selector,
            0,
            block.timestamp + MAX_GATEWAY_DELAY,
            false
        );

        gatewayRequestIdToSurveyId[_requestId] = surveyId;
    }

    //////////////////////////////////////////////////////////////////
    /// Analyse the data
    //////////////////////////////////////////////////////////////////

    function getQueryData(uint256 queryId) external view returns (QueryData memory) {
        return queryData[queryId];
    }

    // FEATURE: Possibility to add fees when creating new analysis to reward the participants
    function createQuery(uint256 surveyId, Filter[][] memory params) external returns (uint256) {
        if (surveyId >= _surveyIds) {
            revert InvalidSurveyId();
        }

        if (!_surveyData[surveyId].isCompleted) {
            revert UnfinishedSurvey();
        }

        if (!_surveyData[surveyId].isValid) {
            revert InvalidSurvey();
        }

        // Verify the filter operation are valid based on the metadata
        _verifier.validateFilter(_surveyParams[surveyId].metadataTypes, params);

        euint256 pendingEncryptedResult = TFHE.asEuint256(0);
        euint256 pendingSelectedNumber = TFHE.asEuint256(0);

        queryData[_queryIds] = QueryData({
            surveyId: surveyId,
            filters: params,
            pendingEncryptedResult: pendingEncryptedResult,
            pendingSelectedNumber: pendingSelectedNumber,
            cursor: 0,
            isCompleted: false,
            isValid: false,
            finalSelectedCount: 0,
            finalResult: 0
        });

        emit QueryCreated(_queryIds, surveyId, msg.sender);

        _queryIds++;

        return _queryIds - 1;
    }

    function executeQuery(uint256 queryId, uint256 limit) public {
        if (queryId >= _queryIds) {
            revert InvalidQueryId();
        }

        if (queryData[queryId].isCompleted) {
            revert AlreadyCompletedQuery();
        }

        uint256 surveyId = queryData[queryId].surveyId;
        uint256 start = queryData[queryId].cursor;

        // Limit the iteration possible based on the cursor limit allow (cursor + limit)
        // Or by the total number of data available
        uint256 allowToRead = start + limit;
        uint256 maxIterations = allowToRead < voteData[surveyId].length ? allowToRead : voteData[surveyId].length;

        euint256 one = TFHE.asEuint256(1);
        euint256 zero = TFHE.asEuint256(0);

        while (queryData[queryId].cursor < maxIterations) {
            // Get the vote data
            VoteData memory data = voteData[surveyId][queryData[queryId].cursor];

            if (data.isValid) {
                // Apply the filter
                ebool takeIt = _verifier.applyFilterOnMetadata(
                    queryData[queryId].filters,
                    _surveyParams[surveyId].metadataTypes,
                    data.metadata
                );

                euint256 isSelected = TFHE.select(takeIt, one, zero);
                euint256 valueSelected = TFHE.select(takeIt, data.data, zero);

                // Update the state
                queryData[queryId].pendingSelectedNumber = TFHE.add(
                    queryData[queryId].pendingSelectedNumber,
                    isSelected
                );
                queryData[queryId].pendingEncryptedResult = TFHE.add(
                    queryData[queryId].pendingEncryptedResult,
                    valueSelected
                );
            }

            queryData[queryId].cursor++;
        }

        // In case of the last iteration - Potentially reveal the value
        if (queryData[queryId].cursor >= voteData[surveyId].length) {
            // Check the threshold of data and also the opposite one!
            euint256 thresholdDown = TFHE.asEuint256(_surveyParams[surveyId].minResponseThreshold);
            euint256 thresholdUp = TFHE.asEuint256(
                _surveyData[surveyId].currentParticipants - _surveyParams[surveyId].minResponseThreshold
            );

            ebool reachedThreshold = TFHE.and(
                TFHE.gt(queryData[queryId].pendingSelectedNumber, thresholdDown),
                TFHE.lt(queryData[queryId].pendingSelectedNumber, thresholdUp)
            );

            euint256 sPendingSelectedNumber = TFHE.select(
                reachedThreshold,
                queryData[queryId].pendingSelectedNumber,
                zero
            );
            euint256 sPendingEncryptedResult = TFHE.select(
                reachedThreshold,
                queryData[queryId].pendingEncryptedResult,
                zero
            );

            uint256[] memory cts = new uint256[](2);
            cts[0] = Gateway.toUint256(sPendingSelectedNumber);
            cts[1] = Gateway.toUint256(sPendingEncryptedResult);
            uint256 _requestId = Gateway.requestDecryption(
                cts,
                this.gatewayDecryptQueryResult.selector,
                0,
                block.timestamp + MAX_GATEWAY_DELAY,
                false
            );

            gatewayRequestIdToSurveyId[_requestId] = queryId;
        }
    }

    function executeQuery(uint256 queryId) external {
        executeQuery(queryId, 10);
    }

    //////////////////////////////////////////////////////////////////
    /// Gateway Callback Functions
    //////////////////////////////////////////////////////////////////

    /// Gateway Callback - Decrypt the survey result
    /// @dev When calling the Gateway, we have verified beforehand that we had enough participants, meaning
    /// that we had reached the expected threshold from the survey. In that case we are considering the survey
    /// has valid and completed.
    function gatewayDecryptSurveyResult(uint256 requestId, uint256 result) public onlyGateway {
        uint256 surveyId = gatewayRequestIdToSurveyId[requestId];
        _surveyData[surveyId].finalResult = result;
        _surveyData[surveyId].isCompleted = true;
        _surveyData[surveyId].isValid = true;

        emit SurveyCompleted(
            surveyId,
            true,
            _surveyParams[surveyId].surveyType,
            _surveyData[surveyId].currentParticipants,
            result
        );
    }

    /// Gateway Callback - Confirm user entry
    /// Depending of the survey, we can attached constraints on the metadata. By using the gateway, we
    /// can request to decrypt the encrypted verification parameter allowing us to confirm or not
    /// the user entry for the given survey.
    function gatewayConfirmUserEntry(uint256 requestId, bool isValid) public onlyGateway {
        GatewayUserEntry memory _gatewayUserEntry = gatewayRequestIdToConfirmUserEntry[requestId];

        uint256 surveyId = _gatewayUserEntry.surveyId;
        uint256 voteId = _gatewayUserEntry.voteId;

        // In case of valid vote, update our poll data
        if (isValid) {
            _confirmUserEntry(surveyId, voteId);
        } else {
            emit ConfirmUserEntry(surveyId, voteData[surveyId][voteId].userAddress, false);
        }
    }

    /// Gateway Callback - Decrypt the query result
    /// @dev To optimize the verification process, when we have an invalid query result, meaning we do not have reached
    /// the expected threshold for the survey, we expect to received a `_finalSelectedCount` equals to 0.
    /// In the contrary scenario, when having a valid query, we should have the expected decrypted result.
    function gatewayDecryptQueryResult(
        uint256 requestId,
        uint256 _finalSelectedCount,
        uint256 _finalResult
    ) public onlyGateway {
        uint256 queryId = gatewayRequestIdToSurveyId[requestId];

        // Handle the case where we do not reach enough threshold votes
        if (_finalSelectedCount == 0) {
            queryData[queryId].isCompleted = true;
        } else {
            queryData[queryId].finalSelectedCount = _finalSelectedCount;
            queryData[queryId].finalResult = _finalResult;
            queryData[queryId].isCompleted = true;
            queryData[queryId].isValid = true;
        }

        emit QueryCompleted(
            queryId,
            queryData[queryId].surveyId,
            queryData[queryId].isValid,
            queryData[queryId].finalSelectedCount,
            queryData[queryId].finalResult
        );
    }
}
