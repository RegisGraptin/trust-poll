import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

import { awaitAllDecryptionResults } from "../asyncDecrypt";
import { ACCOUNT_NAMES } from "../constants";
import { createInstance } from "../instance";
import { reencryptEuint64 } from "../reencrypt";
import { getSigners, initSigners } from "../signers";
import { debug } from "../utils";
import { deploySurveyFixture } from "./Survey.fixture";

enum SurveyType {
  POLLING = 0,
  BENCHMARK = 1,
}

enum MetadataType {
  BOOLEAN = 0,
  UINT256 = 1,
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

    // Helper functions

    /// Submit entry for polling survey
    this.submitPollingEntry = async (
      signer: HardhatEthersSigner,
      surveyId: number,
      entry: boolean,
      surveyMetadataType: [] = [], // Optional - Depends on the survey
      userMetadata: [] = [],
    ) => {
      const input = this.fhevm.createEncryptedInput(this.contractAddress, signer.address);
      let inputs = input.add256(Number(entry));

      // In case we have metadata, encrypt it
      if (surveyMetadataType) {
        for (let index = 0; index < surveyMetadataType.length; index++) {
          const metadataType = surveyMetadataType[index];
          const data = userMetadata[index];

          switch (metadataType) {
            case MetadataType.BOOLEAN:
              inputs = inputs.addBool(data);
              break;
            case MetadataType.UINT256:
              inputs = inputs.add256(data);
              break;

            default:
              // FIXME:
              console.log("error");
              break;
          }
        }
      }
      inputs = await inputs.encrypt();

      let userEncryptedMetadata = [];
      for (let index = 0; index < surveyMetadataType.length; index++) {
        userEncryptedMetadata.push(inputs.handles[index + 1]);
      }

      // Create a new entry
      // ["submitEntry(uint256,bytes32,uint256[],bytes)"]
      const transaction = await this.survey
        .connect(signer)
        .submitEntry(surveyId, inputs.handles[0], userEncryptedMetadata, inputs.inputProof);
      await transaction.wait();
    };
  });

  it("should create a new survey", async function () {
    const surveyParam = {
      surveyPrompt: "Are you in favor of privacy?",
      surveyType: SurveyType.POLLING,
      isWhitelisted: false,
      whitelistRootHash: new Uint8Array(32),
      surveyEndTime: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // Current timestamp + 7 days in seconds
      responseThreshold: 100,
      metadataTypes: [],
    };

    const transaction = await this.survey.createSurvey(surveyParam);
    await transaction.wait();

    // Check the survey information at the index 0
    const surveyData = await this.survey.surveyParams(0);

    expect(surveyData[0]).to.be.equals("Are you in favor of privacy?");
    expect(surveyData[2]).to.be.false; // Now whitelist
    expect(surveyData[4]).to.be.equals(Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60);
    expect(surveyData[5]).to.be.equals(100);

    // Check that the user can vote
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.false;
    await this.submitPollingEntry(this.signers.alice, 0, true);
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.true;
  });

  it("should handle polling survey", async function () {
    // FIXME: need to fetch the available signers
    const pollingVotes = [true, true, false, true];
    const voterNames = ACCOUNT_NAMES;

    // FIXME: (v2) add metadata assignement

    const surveyParam = {
      surveyPrompt: "Are you in favor of privacy?",
      surveyType: SurveyType.POLLING,
      isWhitelisted: false,
      whitelistRootHash: new Uint8Array(32),
      surveyEndTime: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // Current timestamp + 7 days in seconds
      responseThreshold: 4, // Example value, replace with actual threshold
      metadataTypes: [], // Example value, replace with actual metadata types
    };

    const transaction = await this.survey.createSurvey(surveyParam);
    await transaction.wait();

    // Do the voting
    for (let index = 0; index < pollingVotes.length; index++) {
      await this.submitPollingEntry(this.signers[voterNames[index]], 0, pollingVotes[index]);
    }

    // Now it is possible to reveal the polling
    await this.survey.revealResults(0);

    // Wait for the Gateway to decypher it
    await awaitAllDecryptionResults();

    // Verify the polling data
    const surveyDataAfterVoting = await this.survey.surveyData(0);

    expect(surveyDataAfterVoting[0]).to.be.equals(pollingVotes.length);
    expect(surveyDataAfterVoting[2]).to.be.equals(pollingVotes.filter(Boolean).length);
  });

  it("should handle polling survey with metadata", async function () {
    const pollingVotes = [true, true, false, true];
    // TODO: TBD
    // age, gender
    const userMetadata = [
      [24, true],
      [53, true],
      [27, false],
      [28, true],
    ];
    const voterNames = ACCOUNT_NAMES;

    // FIXME: (v2) add metadata assignement

    const surveyMetadataTypes = [MetadataType.UINT256, MetadataType.BOOLEAN];

    const surveyParam = {
      surveyPrompt: "Are you in favor of privacy?",
      surveyType: SurveyType.POLLING,
      isWhitelisted: false,
      whitelistRootHash: new Uint8Array(32),
      surveyEndTime: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // Current timestamp + 7 days in seconds
      responseThreshold: 4,
      metadataTypes: surveyMetadataTypes,
    };

    const transaction = await this.survey.createSurvey(surveyParam);
    await transaction.wait();

    // FIXME: Check survey metadata

    // Do the voting
    for (let index = 0; index < pollingVotes.length; index++) {
      await this.submitPollingEntry(
        this.signers[voterNames[index]],
        0,
        pollingVotes[index],
        surveyMetadataTypes,
        userMetadata[index],
      );
    }

    // Now it is possible to reveal the polling
    await this.survey.revealResults(0);

    // Wait for the Gateway to decypher it
    await awaitAllDecryptionResults();

    // Verify the polling data
    const surveyDataAfterVoting = await this.survey.surveyData(0);

    expect(surveyDataAfterVoting[0]).to.be.equals(pollingVotes.length);
    expect(surveyDataAfterVoting[2]).to.be.equals(pollingVotes.filter(Boolean).length);

    // Analyse it
    // Analysts could then view aggregated results, for example, the breakdown of votes from men over 45.

    // LargerThan

    const filters = [
      [
        {
          verifier: 0, // LargerThan
          value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [30]),
        },
      ],
    ];
    await this.survey.createQuery(0, filters);

    // Now try to execute the query
    await this.survey.executeQuery(0);
    await awaitAllDecryptionResults(); // Wait for the gateway

    // TODO: Now read the result
    const queryData = await this.survey.queryData(0);

    console.log(queryData);
    // uint256 selectedCount;
    // uint256 result;
  });
});
