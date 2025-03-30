import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { FhevmInstance } from "fhevmjs/node";
import { ethers, network } from "hardhat";

import { Survey } from "../../types";
import { ISurvey, SurveyDataStruct, SurveyParamsStruct } from "../../types/contracts/interfaces/ISurvey";
import { awaitAllDecryptionResults } from "../asyncDecrypt";
import { ACCOUNT_NAMES } from "../constants";
import { createInstance } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deploySurveyFixture } from "./Survey.fixture";

declare module "mocha" {
  export interface Context {
    contractAddress: string;
    survey: Survey;
    fhevm: FhevmInstance;
    submitPollingEntry: (
      signer: HardhatEthersSigner,
      surveyId: number,
      entry: boolean,
      surveyMetadataType: MetadataType[],
      userMetadata: any[],
    ) => Promise<void>;
    revealSurveyResult: (surveyId: number) => Promise<SurveyDataStruct>;
  }
}

enum SurveyType {
  POLLING = 0,
  BENCHMARK = 1,
}

enum MetadataType {
  BOOLEAN = 0,
  UINT256 = 1,
}

const SURVEY_END_TIME = Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60;

const validSurveyParam: SurveyParamsStruct = {
  surveyPrompt: "Are you in favor of privacy?",
  surveyType: SurveyType.POLLING,
  isWhitelisted: false,
  whitelistRootHash: new Uint8Array(32),
  numberOfParticipants: 0, // Optional parameter - need to be defined when whitelisted activated
  surveyEndTime: SURVEY_END_TIME,
  minResponseThreshold: 4,
  metadataTypes: [],
  constraints: [],
};

const invalidSurveyParamsTestCases = [
  {
    name: "empty survey prompt",
    params: { surveyPrompt: "" },
    error: "InvalidSurveyPrompt",
  },
  {
    name: "is whitelisted but no root hash",
    params: { isWhitelisted: true, whitelistRootHash: new Uint8Array(32) },
    error: "InvalidSurveyWhitelist",
  },
  {
    name: "past end time",
    params: { surveyEndTime: Math.floor(Date.now() / 1000) - 1000 },
    error: "InvalidEndTime",
  },
  {
    name: "zero response threshold",
    params: { minResponseThreshold: 0 },
    error: "InvalidResponseThreshold",
  },
  // Add more test cases as needed
];

const analyseScenarioTestCases = [
  {
    name: "People greater than 50 years old",
    params: {
      minResponseThreshold: 4,
      pollingVotes: [true, true, false, true, false, true, true, true, true],
      surveyMetadataTypes: [MetadataType.UINT256, MetadataType.BOOLEAN],
      userMetadata: [
        // [Age, Gender]
        [24, true],
        [27, false],
        [28, true],
        [47, false],
        [48, false],
        [53, true],
        [54, false],
        [55, true],
        [56, true],
      ],
      filters: [
        // Age greater than 50
        [
          {
            verifier: 0, // LargerThan
            value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [50]),
          },
        ],
      ],
      expectToBeValid: true,
      finalResultCount: 4,
      finalResult: 4,
    },
  },
  {
    name: "Invalid analyse - Not enough data points",
    params: {
      minResponseThreshold: 5,
      pollingVotes: [true, true, false, true, false, true, true, true, true],
      surveyMetadataTypes: [MetadataType.UINT256, MetadataType.BOOLEAN],
      userMetadata: [
        // [Age, Gender]
        [24, true],
        [27, false],
        [28, true],
        [47, false],
        [48, false],
        [53, true],
        [54, false],
        [55, true],
        [56, true],
      ],
      filters: [
        // Age greater than 55
        [
          {
            verifier: 0, // LargerThan
            value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [55]),
          },
        ],
      ],
      expectToBeValid: false,
    },
  },
];

describe("Survey", function () {
  // We are using snapshot allowing us to reset the environment from executing test
  let snapshotId: string;

  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const contract = await deploySurveyFixture();
    this.contractAddress = await contract.getAddress();
    this.survey = contract;
    this.fhevm = await createInstance();

    /// Submit entry for polling survey
    this.submitPollingEntry = async (
      signer: HardhatEthersSigner,
      surveyId: number,
      entry: boolean,
      surveyMetadataType: MetadataType[] = [], // Optional - Depends on the survey
      userMetadata: any[] = [],
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
      const encryptedInputs = await inputs.encrypt();

      let userEncryptedMetadata = [];
      for (let index = 0; index < surveyMetadataType.length; index++) {
        userEncryptedMetadata.push(encryptedInputs.handles[index + 1]);
      }

      // Create a new entry
      // ["submitEntry(uint256,bytes32,uint256[],bytes)"]
      const transaction = await this.survey
        .connect(signer)
        .submitEntry(surveyId, encryptedInputs.handles[0], userEncryptedMetadata, encryptedInputs.inputProof);
      await transaction.wait();
    };

    this.revealSurveyResult = async (surveyId: number): Promise<SurveyDataStruct> => {
      // Fetch the survey end time
      const surveyData = await this.survey.surveyParams(surveyId);
      await time.setNextBlockTimestamp(surveyData.surveyEndTime);

      // Reveal the votes
      await this.survey.revealResults(surveyId);

      // Wait for the gateway execution
      await awaitAllDecryptionResults();

      // Return the survey data updated
      return await this.survey.surveyData(surveyId);
    };

    // Create a snashot of the state
    snapshotId = await network.provider.send("evm_snapshot");
  });

  afterEach(async () => {
    // Revert to snapshot after each test
    await network.provider.send("evm_revert", [snapshotId]);
  });

  it("should create a new survey", async function () {
    const transaction = await this.survey.createSurvey(validSurveyParam);
    await transaction.wait();

    // Check the survey information at the index 0
    const surveyData = await this.survey.surveyParams(0);

    expect(surveyData.surveyPrompt).to.be.equals("Are you in favor of privacy?");
    expect(surveyData.isWhitelisted).to.be.false;
    expect(surveyData.surveyEndTime).to.be.equals(SURVEY_END_TIME);
    expect(surveyData.minResponseThreshold).to.be.equals(4);

    // Check that the user can vote
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.false;
    await this.submitPollingEntry(this.signers.alice, 0, true);
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.true;
  });

  invalidSurveyParamsTestCases.forEach(({ name, params, error }) => {
    it(`should reject invalid survey's parameters: ${name}`, async function () {
      const invalidParams = { ...validSurveyParam, ...params };
      await expect(this.survey.createSurvey(invalidParams)).to.be.revertedWithCustomError(this.survey, error);
    });
  });

  it("should reveal polling survey with no metadata", async function () {
    const pollingVotes = [true, true, false, true];
    const voterNames = ACCOUNT_NAMES;

    const transaction = await this.survey.createSurvey(validSurveyParam);
    await transaction.wait();

    // Do the voting
    for (let index = 0; index < pollingVotes.length; index++) {
      await this.submitPollingEntry(this.signers[voterNames[index]], 0, pollingVotes[index]);
    }

    // Reveal the survey and check the expected result
    const surveyDataAfterVoting = await this.revealSurveyResult(0);
    expect(surveyDataAfterVoting.isCompleted).to.be.true;
    expect(surveyDataAfterVoting.isInvalid).to.be.false;
    expect(surveyDataAfterVoting.currentParticipants).to.be.equals(pollingVotes.length);
    expect(surveyDataAfterVoting.finalResult).to.be.equals(pollingVotes.filter(Boolean).length);
  });

  analyseScenarioTestCases.forEach(({ name, params }) => {
    it(`should handle analyse on: ${name}`, async function () {
      const voterNames = ACCOUNT_NAMES;
      const pollingVotes = params.pollingVotes;
      const surveyMetadataTypes = params.surveyMetadataTypes;
      const userMetadata = params.userMetadata;

      const surveyParam = {
        ...validSurveyParam,
        minResponseThreshold: params.minResponseThreshold,
        metadataTypes: surveyMetadataTypes,
      };

      const transaction = await this.survey.createSurvey(surveyParam);
      await transaction.wait();

      /// Voting part
      for (let index = 0; index < pollingVotes.length; index++) {
        await this.submitPollingEntry(
          this.signers[voterNames[index]],
          0,
          pollingVotes[index],
          surveyMetadataTypes,
          userMetadata[index],
        );
      }

      const surveyDataAfterVoting = await this.revealSurveyResult(0);
      expect(surveyDataAfterVoting.isCompleted).to.be.true;
      expect(surveyDataAfterVoting.isInvalid).to.be.false;
      expect(surveyDataAfterVoting.currentParticipants).to.be.equals(pollingVotes.length);
      expect(surveyDataAfterVoting.finalResult).to.be.equals(pollingVotes.filter(Boolean).length);

      // TODO: automate in case more users?
      // Create and execute the query
      await this.survey.createQuery(0, params.filters);
      await this.survey["executeQuery(uint256)"](0);
      await awaitAllDecryptionResults(); // Wait for the gateway

      // Read the result
      const queryData = await this.survey.queryData(0);
      expect(queryData.isCompleted).to.be.true;
      if (params.expectToBeValid) {
        expect(queryData.isInvalid).to.be.false;
        expect(queryData.finalSelectedCount).to.be.equals(4);
        expect(queryData.finalResult).to.be.equals(4);
      } else {
        expect(queryData.isInvalid).to.be.true;
      }
    });
  });
});
