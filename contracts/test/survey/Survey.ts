import { expect } from "chai";
import { network } from "hardhat";

import { createInstance } from "../instance";
import { reencryptEuint64 } from "../reencrypt";
import { getSigners, initSigners } from "../signers";
import { debug } from "../utils";
import { deploySurveyFixture } from "./Survey.fixture";

enum SurveyType {
  POLLING = 0,
  BENCHMARK = 1,
}

describe("Survey", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const contract = await deploySurveyFixture();
    this.contractAddress = await contract.getAddress();
    this.survey = contract;
    this.fhevm = await createInstance();
  });

  it("should create a new survey", async function () {
    const surveyParam = {
      surveyPrompt: "Are you in favor of privacy?",
      surveyType: SurveyType.POLLING,
      isWhitelisted: false,
      whitelistRootHash: new Uint8Array(32),
      surveyEndTime: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // Current timestamp + 7 days in seconds
      responseThreshold: 100, // Example value, replace with actual threshold
      metadataTypes: [], // Example value, replace with actual metadata types
    };

    const transaction = await this.survey.createSurvey(surveyParam);
    await transaction.wait();

    // Get the survey information at the index 0
    const surveyData = await this.survey.surveyParams(0);
    console.log("surveyData:", surveyData);
  });
});
