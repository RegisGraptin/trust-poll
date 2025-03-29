// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { MetadataType } from "./interfaces/IMetadata.sol";

import { ISurvey, SurveyParams, SurveyData, VoteData } from "./interfaces/ISurvey.sol";
import { IAnalyze, QueryData, Filter, VerifierType } from "./interfaces/IAnalyze.sol";

contract Survey is ISurvey, IAnalyze, SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller {
    uint256 private _surveyIds;

    mapping(uint256 => SurveyParams) public surveyParams;
    mapping(uint256 => SurveyData) public surveyData;

    mapping(uint256 => VoteData[]) voteData;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    //////////////////////////////////////////////////////////////////
    /// Survey management
    //////////////////////////////////////////////////////////////////

    function createSurvey(SurveyParams memory params) external returns (uint256) {
        if (bytes(params.surveyPrompt).length == 0) revert InvalidSurveyPrompt();
        if (params.isWhitelisted && params.whitelistRootHash == bytes32(0)) {
            revert InvalidSurveyWhitelist();
        }
        if (params.isWhitelisted && params.numberOfParticipants < 2) {
            revert InvalidNumberOfParticipants();
        }
        if (params.surveyEndTime <= block.timestamp) revert InvalidEndTime();
        if (params.minResponseThreshold <= 3) revert InvalidResponseThreshold();

        euint256 eResponses = TFHE.asEuint256(0);
        TFHE.allowThis(eResponses);

        surveyParams[_surveyIds] = params;
        surveyData[_surveyIds] = SurveyData({
            participantCount: 0,
            encryptedResponses: eResponses,
            lastDecryptedCount: 0,
            decryptedResponses: 0 // FIXME: add indicator for decrypted or not
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
        // require(block.timestamp == 0 || block.timestamp > endVoteTime, "VOTE_PENDING");
        require(surveyId < _surveyIds, "invalid");
        require(!hasVoted[surveyId][msg.sender], "already_voted");
        require(surveyParams[surveyId].metadataTypes.length == metadata.length, "Invalid length");

        // TODO: Defined in readme explicitaly all the parameter
        // params.surveyEndTime <= block.timestamp

        // In case of whitelisted survey, check the user access
        if (surveyParams[surveyId].isWhitelisted) {
            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
            require(
                MerkleProof.verify(whitelistProof, surveyParams[surveyId].whitelistRootHash, leaf),
                "Invalid proof"
            );
        }

        // Check metadata type
        uint256[] memory checkedMetadatValue = new uint256[](surveyParams[surveyId].metadataTypes.length);
        for (uint256 i = 0; i < surveyParams[surveyId].metadataTypes.length; i++) {
            MetadataType _type = surveyParams[surveyId].metadataTypes[i];

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

        // Add a new vote
        euint256 eVote = TFHE.asEuint256(eInputVote, inputProof);
        TFHE.allowThis(eVote);

        surveyData[surveyId].encryptedResponses = TFHE.add(surveyData[surveyId].encryptedResponses, eVote);
        surveyData[surveyId].participantCount++;
        TFHE.allowThis(surveyData[surveyId].encryptedResponses);

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

    mapping(uint256 requestId => uint256 surveyId) gatewayRequestId;
    mapping(uint256 requestId => uint256) countRequested;

    function revealResults(uint256 surveyId) external {
        if (surveyParams[surveyId].authorizePendingReveal) {
            // Be sure that the next time we ask to reveal, we have enough vote
            if (
                (surveyData[surveyId].lastDecryptedCount + surveyParams[surveyId].minResponseThreshold) >
                surveyData[surveyId].participantCount
            ) {
                revert ThresholdNeeded();
            }

            // In a whitelisted scenario, we want to avoid the scenario where we do not have enough
            // participants which would leak the vote value.
            if (
                surveyParams[surveyId].isWhitelisted &&
                surveyData[surveyId].participantCount >
                (surveyParams[surveyId].numberOfParticipants - surveyParams[surveyId].minResponseThreshold)
            ) {
                // An exception if we have all the participants that have voted
                if (
                    surveyData[surveyId].participantCount !=
                    (surveyParams[surveyId].numberOfParticipants - surveyParams[surveyId].minResponseThreshold)
                ) {
                    revert InvalidRevealAction();
                }
            }
        } else {
            if (block.timestamp <= surveyParams[surveyId].surveyEndTime) {
                revert UnfinishedSurveyPeriod();
            }
        }

        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(surveyData[surveyId].encryptedResponses);
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

    uint256 private _queryIds;
    mapping(uint256 => QueryData) public queryData;

    function createQuery(uint256 surveyId, Filter[][] memory params) external returns (uint256) {
        // TODO: At what time could we consider starting to do analytics on the data?
        // Can we authorize it from the beginning?
        // Should we wait a certain number of votes

        // FIXME: add constraint on the current vote.
        // Do we want to add constraint on the current vote?
        // Min threshold maybe?

        // // FIXME: Need to verify the input filter compared to the type
        // Filter[][] storage _filters = new Filter[][](params.length);
        // for (uint256 i = 0; i < params.length; i++) {
        //     _filters[i] = new Filter[](params[i].length);
        //     for (uint256 j = 0; j < params[i].length; j++) {
        //         // Copy individual Filter struct
        //         _filters[i][j] = params[i][j];
        //     }
        // }

        // Check if the survey authorize "pending analysis".
        // TODO: Do we consider when all the people has voted to be finished?
        if (surveyParams[surveyId].authorizePendingAnalyze && block.timestamp < surveyParams[surveyId].surveyEndTime) {
            revert UnauthorizePendingQuery();
        }

        euint256 pendingResult = TFHE.asEuint256(0);
        euint256 numberOfSelected = TFHE.asEuint256(0);

        // Define the limit

        uint256 limit;

        if (!surveyParams[surveyId].authorizePendingAnalyze) {
            if (block.timestamp <= surveyParams[surveyId].surveyEndTime) {
                revert InvalidRevealAction(); // TODO: Change naming
            }
            // Safely choose the whole participants
            limit = surveyData[surveyId].participantCount;
        } else {
            // Need to authorize only based on a threshold
            // FIXME: need to link with traditional reveal
            // as it can leak some data
        }

        // When survey is finished

        // When whitelisted, we expect a total number of participants

        // Add a limit
        // We do not have a dynamic query anymore. From the start we are defining the limit
        // of the data we can analyse.
        // If whitelist -
        //      - If complete take it
        //      -

        // 10 // 3 => 3 / 1
        // 7 authorize
        // ((total - theshold) / threshold) * threshold
        // 7 / 3 = 2 => * 3 => 6
        // 6 / 3 = 2 => * 3 => 6

        // FIXME: here issue ----
        queryData[_queryIds] = QueryData({
            surveyId: surveyId,
            filters: params,
            pendingResult: pendingResult,
            numberOfSelected: numberOfSelected,
            cursor: 0,
            isFinished: false,
            selectedCount: 0,
            result: 0
        });

        _queryIds++;

        // FIXME: emit event

        return _queryIds - 1;
    }

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

    // Check if we can reveal NOW without compromision on privacy
    mapping(uint256 surveyId => uint256 nbVotes) lastAnalysisVoting;

    // FIXME: Possibility to add another functions that will take a integer as parameter
    // allowing us to handle the iteration logic with a custom integer.
    function executeQuery(uint256 queryId) external {
        require(queryId < _queryIds, "INVALID_QUERY_ID");
        // FIXME: Other things in mind??

        uint256 surveyId = queryData[queryId].surveyId;

        uint256 limit = 10;
        uint256 start = queryData[queryId].cursor;

        // FIXME: Simplify all the code
        // Please: first check that you understand the allowthis --> which one do I need!
        // To avoid potential leaks!

        while (
            queryData[queryId].cursor < start + limit && // Limit the iterator
            queryData[queryId].cursor < voteData[surveyId].length // Still data to read
        ) {
            // Process
            VoteData memory data = voteData[surveyId][queryData[queryId].cursor];

            // Apply the filter
            ebool takeIt = _applyMetadataFilter(queryData[queryId].filters, data.metadata);
            // TFHE.allowThis(takeIt);
            // ebool takeIt = TFHE.asEbool(true);

            euint256 one = TFHE.asEuint256(1);
            euint256 zero = TFHE.asEuint256(0);

            euint256 increment = TFHE.select(takeIt, one, zero);
            euint256 addValue = TFHE.select(takeIt, data.data, zero);

            queryData[queryId].numberOfSelected = TFHE.add(queryData[queryId].numberOfSelected, increment);

            queryData[queryId].pendingResult = TFHE.add(queryData[queryId].pendingResult, addValue);

            queryData[queryId].cursor++;
        }

        // In case of last iteration - Potentially reveal the value
        // FIXME: handle it
        // Check the threshold of data and also the opposite one!

        // Add a double check here on the data.
        // Based on the previous analyse, check if we can reveal or not
        // Or wait new data points

        if (queryData[queryId].cursor >= voteData[surveyId].length) {
            // FIXME: allow this check only if we are in pending authorize
            // + Double check we do not reveal it before

            // Issue if we only have one more voter can block it...
            if (
                queryData[queryId].cursor <= lastAnalysisVoting[surveyId] + surveyParams[surveyId].minResponseThreshold
            ) {
                // Not possible to decypher now!
                // Need to wait more votes
                return;
            }

            // In the case we have a leak
            // TODO: See how we can execute the boolean value

            // FIXME: double check that we do not have a potential leak
            // Else we assume that we reach a correct threshold and does not impact privacy

            // TFHE.allowThis(queryData[queryId].numberOfSelected);
            // TFHE.allowThis(queryData[queryId].pendingResult);

            lastAnalysisVoting[surveyId] = queryData[queryId].cursor;

            uint256[] memory cts = new uint256[](2);
            cts[0] = Gateway.toUint256(queryData[queryId].numberOfSelected);
            cts[1] = Gateway.toUint256(queryData[queryId].pendingResult);
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

    //////////////////////////////////////////////////////////////////
    /// Gateway Callback Functions
    //////////////////////////////////////////////////////////////////

    /// Gateway Callback - Decrypt the vote result
    function gatewayDecryptVoteResult(uint256 requestId, uint256 result) public onlyGateway {
        uint256 surveyId = gatewayRequestId[requestId];
        surveyData[surveyId].decryptedResponses = result;

        // emit GatewayTotalValueRequested(_gatewayProcess[requestId], result);
    }

    ///
    function gatewayDecryptAnalyse(
        uint256 requestId,
        uint256 numberOfSelected,
        uint256 pendingResult
    ) public onlyGateway {
        uint256 queryId = gatewayRequestId[requestId];

        // FIXME: have better naming please
        queryData[queryId].selectedCount = numberOfSelected;
        queryData[queryId].result = pendingResult;
        queryData[requestId].isFinished = true;

        // emit event
    }
}
