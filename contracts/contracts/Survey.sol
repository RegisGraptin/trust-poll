// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { ISurvey, SurveyParams } from "./interfaces/ISurvey.sol";

contract Survey is ISurvey {
    uint256 private _surveyIds;
    mapping(uint256 => SurveyParams) surveyParams;

    function createSurvey(SurveyParams memory params) external returns (uint256) {
        // FIXME: check params value
        
        surveyParams[_surveyIds] = params;
        _surveyIds++;

        // TODO: emit event

        return _surveyIds - 1;
    }
}
