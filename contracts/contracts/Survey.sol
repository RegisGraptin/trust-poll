// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { MetadataType, VerifierType, Filter } from "./interfaces/IFilters.sol";

import { ISurvey, SurveyParams, SurveyData, VoteData } from "./interfaces/ISurvey.sol";
import { IAnalyze, QueryData } from "./interfaces/IAnalyze.sol";

contract Survey is ISurvey, IAnalyze, SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller {
    uint256 private _surveyIds;
    mapping(uint256 => SurveyParams) _surveyParams;
    mapping(uint256 => SurveyData) _surveyData;

    mapping(uint256 => VoteData[]) voteData;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 private _queryIds;
    mapping(uint256 => QueryData) public queryData;

    mapping(uint256 requestId => uint256 surveyId) gatewayRequestId;

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
        if (bytes(params.surveyPrompt).length == 0) revert InvalidSurveyPrompt();

        if (params.isWhitelisted) {
            // Have a valid root hash in case of whitelisted
            if (params.whitelistRootHash == bytes32(0)) {
                revert InvalidSurveyWhitelist();
            }

            // Have enough participants
            if (params.numberOfParticipants < 2) {
                revert InvalidNumberOfParticipants();
            }
        }

        // Have a valid end time
        if (params.surveyEndTime < block.timestamp) revert InvalidEndTime();

        // Have a valid threshold
        if (params.minResponseThreshold <= 3) revert InvalidResponseThreshold();

        euint256 eResponses = TFHE.asEuint256(0);
        TFHE.allowThis(eResponses);

        _surveyParams[_surveyIds] = params;
        _surveyData[_surveyIds] = SurveyData({
            currentParticipants: 0,
            encryptedResponses: eResponses,
            finalResult: 0,
            isCompleted: false,
            isInvalid: false
        });

        emit SurveyCreated(_surveyIds, msg.sender, params.surveyType, params.surveyPrompt);
        _surveyIds++;

        return _surveyIds - 1;
    }

    /// metadata parameter will be a list of encrypted arguments that should match the user type
    /// We could have [euint256, ebool, euint8, ...] input
    function _submitEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof,
        bytes32[] memory whitelistProof
    ) internal {
        if (surveyId >= _surveyIds) {
            revert InvalidSurveyId();
        }

        if (block.timestamp >= _surveyParams[surveyId].surveyEndTime) {
            revert FinishedSurvey();
        }

        if (hasVoted[surveyId][msg.sender]) {
            revert UserAlreadyVoted();
        }

        if (_surveyParams[surveyId].metadataTypes.length != metadata.length) {
            revert InvalidUserMetadata();
        }

        // In case of whitelisted survey, check the user access
        if (_surveyParams[surveyId].isWhitelisted) {
            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
            require(
                MerkleProof.verify(whitelistProof, _surveyParams[surveyId].whitelistRootHash, leaf),
                "Invalid proof"
            );
        }

        // Check metadata type
        // TODO: Internal function as we need to check if it is valid?
        uint256[] memory checkedMetadatValue = new uint256[](_surveyParams[surveyId].metadataTypes.length);
        for (uint256 i = 0; i < _surveyParams[surveyId].metadataTypes.length; i++) {
            MetadataType _type = _surveyParams[surveyId].metadataTypes[i];

            if (_type == MetadataType.BOOLEAN) {
                ebool val = TFHE.asEbool(metadata[i], inputProof);
                checkedMetadatValue[i] = ebool.unwrap(val);
                TFHE.allowThis(val);
            } else if (_type == MetadataType.UINT256) {
                euint256 val = TFHE.asEuint256(metadata[i], inputProof);
                checkedMetadatValue[i] = euint256.unwrap(val);
                TFHE.allowThis(val);
            }
        }

        // Check the value of the metadata
        // FIXME: Not sure we can reveal it and use it. This means, we potentially needs to have another
        // verification layer. What can be done, is to add a boolean isValid, that will valiate it
        // in another step.
        ebool validEntry = _applyMetadataFilter(_surveyParams[surveyId].constraints, checkedMetadatValue);
        // FIXME: check with zama how to filter on it
        // TODO: Possibility to check the medata value by adding some constraint on it

        // Add a new vote
        euint256 eVote = TFHE.asEuint256(eInputVote, inputProof);
        TFHE.allowThis(eVote);

        _surveyData[surveyId].encryptedResponses = TFHE.add(_surveyData[surveyId].encryptedResponses, eVote);
        _surveyData[surveyId].currentParticipants++;
        TFHE.allowThis(_surveyData[surveyId].encryptedResponses);

        // Save vote info
        VoteData memory _voteData = VoteData({ data: eVote, metadata: checkedMetadatValue });
        voteData[surveyId].push(_voteData);

        // Add user to the hasvoted list
        hasVoted[surveyId][msg.sender] = true;

        // Emit event
        emit EntrySubmitted(surveyId, msg.sender);
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
        // Need the survey to be finished
        if (block.timestamp < _surveyParams[surveyId].surveyEndTime) {
            revert UnfinishedSurveyPeriod();
        }

        // Already completed
        if (_surveyData[surveyId].isCompleted) {
            revert ResultAlreadyReveal();
        }

        // Check we have enough participants
        if (_surveyData[surveyId].currentParticipants < _surveyParams[surveyId].minResponseThreshold) {
            _surveyData[surveyId].isInvalid = true;
            _surveyData[surveyId].isCompleted = true;

            // TODO: Emit event / Should we keep the completed one?

            return;
        }

        // Decypher the result
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(_surveyData[surveyId].encryptedResponses);
        uint256 _requestId = Gateway.requestDecryption(
            cts,
            this.gatewayDecryptVoteResult.selector,
            0,
            block.timestamp + 100,
            false
        );

        gatewayRequestId[_requestId] = surveyId;
    }

    //////////////////////////////////////////////////////////////////
    /// Analyse the data
    //////////////////////////////////////////////////////////////////

    function getQueryData(uint256 queryId) external view returns (QueryData memory) {
        return queryData[queryId];
    }

    function createQuery(uint256 surveyId, Filter[][] memory params) external returns (uint256) {
        if (!_surveyData[surveyId].isCompleted) {
            revert UnfinishedSurveyPeriod();
        }

        if (_surveyData[surveyId].isInvalid) {
            revert InvalidSurvey();
        }

        // // TODO: Need to verify the input filter compared to the type
        // Filter[][] storage _filters = new Filter[][](params.length);
        // for (uint256 i = 0; i < params.length; i++) {
        //     _filters[i] = new Filter[](params[i].length);
        //     for (uint256 j = 0; j < params[i].length; j++) {
        //         // Copy individual Filter struct
        //         _filters[i][j] = params[i][j];
        //     }
        // }

        euint256 pendingEncryptedResult = TFHE.asEuint256(0);
        euint256 pendingSelectedNumber = TFHE.asEuint256(0);

        queryData[_queryIds] = QueryData({
            surveyId: surveyId,
            filters: params,
            pendingEncryptedResult: pendingEncryptedResult,
            pendingSelectedNumber: pendingSelectedNumber,
            cursor: 0,
            isCompleted: false,
            isInvalid: false,
            finalSelectedCount: 0,
            finalResult: 0
        });

        emit QueryCreated(_queryIds, surveyId, msg.sender);

        _queryIds++;

        return _queryIds - 1;
    }

    // TODO: Adjust where to put it the function as used on the two parts

    function _applyFilter(Filter memory filter, uint256 userData) internal returns (ebool) {
        ebool isVerified;

        VerifierType _verifierType = filter.verifier;

        if (_verifierType == VerifierType.LargerThan) {
            // TODO: Depending of th number of data, we can have a huge cost here
            // by doing abi.decode() and asEuint256 operation.
            // Need to think a smarter approach, maybe?
            euint256 eVal = TFHE.asEuint256(abi.decode(filter.value, (uint256)));

            euint256 eUsr = euint256.wrap(userData);

            isVerified = TFHE.gt(eUsr, eVal);
        } else if (_verifierType == VerifierType.SmallerThan) {
            // TODO:
        } else {
            // FIXME:
        }

        return isVerified;
    }

    function _applyMetadataFilter(Filter[][] memory filters, uint256[] memory userFilter) internal returns (ebool) {
        // By default, it is accepted
        ebool isValid = TFHE.asEbool(true);

        // In this part, we can assume the filter are valid, as we will verify them before
        for (uint256 i = 0; i < filters.length; i++) {
            // Apply the filter on the user metadata
            for (uint256 j = 0; j < filters[i].length; j++) {
                isValid = TFHE.and(isValid, _applyFilter(filters[i][j], userFilter[i]));
            }
        }

        return isValid;
    }

    function executeQuery(uint256 queryId, uint256 limit) public {
        if (queryId >= _queryIds) {
            revert InvalidQueryId();
        }

        if (queryData[queryId].isCompleted) {
            revert AlreadyCompletedQuery();
        }

        // TODO: Other things in mind??

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

            // Apply the filter
            ebool takeIt = _applyMetadataFilter(queryData[queryId].filters, data.metadata);
            euint256 isSelected = TFHE.select(takeIt, one, zero);
            euint256 valueSelected = TFHE.select(takeIt, data.data, zero);

            // Update the state
            queryData[queryId].pendingSelectedNumber = TFHE.add(queryData[queryId].pendingSelectedNumber, isSelected);
            queryData[queryId].pendingEncryptedResult = TFHE.add(
                queryData[queryId].pendingEncryptedResult,
                valueSelected
            );
            queryData[queryId].cursor++;
        }

        // In case of last iteration - Potentially reveal the value
        if (queryData[queryId].cursor >= voteData[surveyId].length) {
            // Check the threshold of data and also the opposite one!

            // TFHE.select()

            // In the case we have a leak
            // TODO: See how we can execute the boolean value

            // FIXME: double check that we do not have a potential leak
            // Else we assume that we reach a correct threshold and does not impact privacy

            uint256[] memory cts = new uint256[](2);
            cts[0] = Gateway.toUint256(queryData[queryId].pendingSelectedNumber);
            cts[1] = Gateway.toUint256(queryData[queryId].pendingEncryptedResult);
            uint256 _requestId = Gateway.requestDecryption(
                cts,
                this.gatewayDecryptAnalyse.selector, // FIXME: naming
                0,
                block.timestamp + 100,
                false
            );

            gatewayRequestId[_requestId] = queryId;
        }
    }

    function executeQuery(uint256 queryId) external {
        return executeQuery(queryId, 10);
    }

    //////////////////////////////////////////////////////////////////
    /// Gateway Callback Functions
    //////////////////////////////////////////////////////////////////

    /// Gateway Callback - Decrypt the vote result
    function gatewayDecryptVoteResult(uint256 requestId, uint256 result) public onlyGateway {
        uint256 surveyId = gatewayRequestId[requestId];
        _surveyData[surveyId].finalResult = result;
        _surveyData[surveyId].isCompleted = true;

        emit SurveyCompleted(
            surveyId,
            _surveyParams[surveyId].surveyType,
            _surveyData[surveyId].currentParticipants,
            result
        );
    }

    ///
    function gatewayDecryptAnalyse(
        uint256 requestId,
        uint256 _finalSelectedCount,
        uint256 _finalResult
    ) public onlyGateway {
        uint256 queryId = gatewayRequestId[requestId];

        // FIXME: have better naming please
        queryData[queryId].finalSelectedCount = _finalSelectedCount;
        queryData[queryId].finalResult = _finalResult;
        queryData[queryId].isCompleted = true;

        // emit event
    }
}
