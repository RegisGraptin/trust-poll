import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { HexString } from "@openzeppelin/merkle-tree/dist/bytes";
import { expect } from "chai";
import { FhevmInstance } from "fhevmjs/node";
import { ethers, network } from "hardhat";

import { Survey } from "../../types";
import { SurveyDataStruct, SurveyParamsStruct } from "../../types/contracts/interfaces/ISurvey";
import { awaitAllDecryptionResults } from "../asyncDecrypt";
import { ACCOUNT_NAMES } from "../constants";
import { createInstance } from "../instance";
import { Signers, getSigners, initSigners } from "../signers";
import { deploySurveyFixture } from "./Survey.fixture";

declare module "mocha" {
  export interface Context {
    contractAddress: string;
    survey: Survey;
    signers: Signers;
    fhevm: FhevmInstance;
    submitPollingEntry: ({
      signer,
      surveyId,
      entry,
      surveyMetadataName,
      surveyMetadataType,
      userMetadata,
      tree,
    }: {
      signer: HardhatEthersSigner;
      surveyId: number;
      entry: boolean;
      surveyMetadataName?: string[];
      surveyMetadataType?: MetadataType[];
      userMetadata?: any[];
      tree?: StandardMerkleTree<string[]>;
    }) => Promise<void>;
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

enum FilterOperator {
  LargerThan = 0,
  SmallerThan = 1,
  EqualTo = 2,
  DifferentTo = 3,
}

const SURVEY_END_TIME = Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60;

const validSurveyParam: SurveyParamsStruct = {
  surveyPrompt: "Are you in favor of privacy?",
  surveyType: SurveyType.POLLING,
  isWhitelisted: false,
  whitelistRootHash: new Uint8Array(32),
  surveyEndTime: SURVEY_END_TIME,
  minResponseThreshold: 4,
  metadataNames: [],
  metadataTypes: [],
  constraints: [],
};

const invalidSurveyParamsTestCases = [
  {
    name: "empty survey prompt",
    params: { surveyPrompt: "" },
    error: "InvalidSurveyParameter",
  },
  {
    name: "is whitelisted but no root hash",
    params: { isWhitelisted: true, whitelistRootHash: new Uint8Array(32) },
    error: "InvalidSurveyParameter",
  },
  {
    name: "past end time",
    params: { surveyEndTime: Math.floor(Date.now() / 1000) - 1000 },
    error: "InvalidSurveyParameter",
  },
  {
    name: "zero response threshold",
    params: { minResponseThreshold: 0 },
    error: "InvalidSurveyParameter",
  },
];

const analyseScenarioTestCases = [
  {
    name: "People greater than 50 years old",
    params: {
      minResponseThreshold: 4,
      pollingVotes: [true, true, false, true, false, true, true, true, true],
      surveyMetadataTypes: [MetadataType.UINT256, MetadataType.BOOLEAN],
      surveyMetadataNames: ["Age", "Gender"],
      userMetadata: [
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
        [],
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
      surveyMetadataNames: ["Age", "Gender"],
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
        [],
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
    this.submitPollingEntry = async ({ signer, surveyId, entry, surveyMetadataType = [], userMetadata = [], tree }) => {
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
              throw TypeError(`Unknonw ${metadataType}`);
          }
        }
      }
      const encryptedInputs = await inputs.encrypt();

      let userEncryptedMetadata = [];
      for (let index = 0; index < surveyMetadataType.length; index++) {
        userEncryptedMetadata.push(encryptedInputs.handles[index + 1]);
      }

      // In the case of a whitelist generate a proof for the user
      if (tree) {
        let whitelistedProof: HexString[] = [];
        for (const [i, v] of tree.entries()) {
          if (v[0] === signer.address) {
            whitelistedProof = tree.getProof(i);
            break;
          }
        }

        // Create a new entry
        const transaction = await this.survey
          .connect(signer)
          .submitWhitelistedEntry(
            surveyId,
            encryptedInputs.handles[0],
            userEncryptedMetadata,
            encryptedInputs.inputProof,
            whitelistedProof,
          );
        await transaction.wait();
      } else {
        // Create a new entry
        // ["submitEntry(uint256,bytes32,uint256[],bytes)"]
        const transaction = await this.survey
          .connect(signer)
          .submitEntry(surveyId, encryptedInputs.handles[0], userEncryptedMetadata, encryptedInputs.inputProof);
        await transaction.wait();
      }
    };

    this.revealSurveyResult = async (surveyId: number): Promise<SurveyDataStruct> => {
      // Fetch the survey end time
      const gatewayDelay = 100n;
      const surveyData = await this.survey.surveyParams(surveyId);
      await time.setNextBlockTimestamp(surveyData.surveyEndTime + gatewayDelay);

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
    await this.submitPollingEntry({ signer: this.signers.alice, surveyId: 0, entry: true });
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.true;
  });

  invalidSurveyParamsTestCases.forEach(({ name, params, error }) => {
    it(`should reject invalid survey's parameters: ${name}`, async function () {
      const invalidParams = { ...validSurveyParam, ...params };
      await expect(this.survey.createSurvey(invalidParams)).to.be.revertedWithCustomError(this.survey, error);
    });
  });

  it("should create a new whitelisted survey", async function () {
    const whitelistedAddresses = [
      [this.signers.alice.address],
      [this.signers.bob.address],
      [this.signers.carol.address],
      [this.signers.dave.address],
    ];
    const tree = StandardMerkleTree.of(whitelistedAddresses, ["address"]);

    const surveyParams = {
      ...validSurveyParam,
      isWhitelisted: true,
      whitelistRootHash: tree.root,
    };
    const transaction = await this.survey.createSurvey(surveyParams);
    await transaction.wait();

    // Check the survey information at the index 0
    const surveyData = await this.survey.surveyParams(0);

    expect(surveyData.surveyPrompt).to.be.equals("Are you in favor of privacy?");
    expect(surveyData.isWhitelisted).to.be.true;
    expect(surveyData.surveyEndTime).to.be.equals(SURVEY_END_TIME);
    expect(surveyData.minResponseThreshold).to.be.equals(4);

    // Check that the user can vote
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.false;
    await this.submitPollingEntry({ signer: this.signers.alice, surveyId: 0, entry: false, tree: tree });
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.true;

    // Try to vote with and invalid user
    const nonAuthorizeSigner = this.signers.eve;
    const input = this.fhevm.createEncryptedInput(this.contractAddress, nonAuthorizeSigner.address);
    const inputs = await input.add256(Number(0)).encrypt();

    expect(this.survey.connect(this.signers.eve).submitEntry(0, inputs.handles[0], [], inputs.inputProof)).to.be
      .reverted;
    expect(await this.survey.hasVoted(0, nonAuthorizeSigner.address)).to.be.false;
  });

  it("should reveal polling survey with no metadata", async function () {
    const pollingVotes = [true, true, false, true];
    const voterNames = ACCOUNT_NAMES;

    const transaction = await this.survey.createSurvey(validSurveyParam);
    await transaction.wait();

    // Do the voting
    for (let index = 0; index < pollingVotes.length; index++) {
      await this.submitPollingEntry({
        signer: this.signers[voterNames[index]],
        surveyId: 0,
        entry: pollingVotes[index],
      });
    }

    // Reveal the survey and check the expected result
    const surveyDataAfterVoting = await this.revealSurveyResult(0);
    expect(surveyDataAfterVoting.isCompleted).to.be.true;
    expect(surveyDataAfterVoting.isValid).to.be.true;
    expect(surveyDataAfterVoting.currentParticipants).to.be.equals(pollingVotes.length);
    expect(surveyDataAfterVoting.finalResult).to.be.equals(pollingVotes.filter(Boolean).length);
  });

  it("should create a new survey with constraint metadata", async function () {
    const surveyMetadataType = [MetadataType.UINT256, MetadataType.BOOLEAN];
    const surveyParams = {
      ...validSurveyParam,
      metadataNames: ["Age", "Gender"],
      metadataTypes: surveyMetadataType, // [Age, Gender]
      constraints: [
        // Age constraint
        [
          {
            verifier: FilterOperator.LargerThan,
            value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [10]),
          },
          {
            verifier: FilterOperator.SmallerThan,
            value: ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [110]),
          },
        ],
        // Gender constraint
        [],
      ],
    };
    const transaction = await this.survey.createSurvey(surveyParams);
    await transaction.wait();

    // Check the survey information at the index 0
    const surveyData = await this.survey.surveyParams(0);

    expect(surveyData.surveyPrompt).to.be.equals("Are you in favor of privacy?");
    expect(surveyData.isWhitelisted).to.be.false;
    expect(surveyData.surveyEndTime).to.be.equals(SURVEY_END_TIME);
    expect(surveyData.minResponseThreshold).to.be.equals(4);

    expect(surveyData.constraints.length).to.be.equals(2);
    expect(surveyData.constraints[0].length).to.be.equals(2);
    expect(surveyData.constraints[1].length).to.be.equals(0);

    let largerConstraint = surveyData.constraints[0][0];
    expect(largerConstraint[0]).to.be.equals(FilterOperator.LargerThan);
    expect(ethers.AbiCoder.defaultAbiCoder().decode(["uint256"], largerConstraint[1])[0]).to.be.equals(10n);

    let smallerConstraint = surveyData.constraints[0][1];
    expect(smallerConstraint[0]).to.be.equals(FilterOperator.SmallerThan);
    expect(ethers.AbiCoder.defaultAbiCoder().decode(["uint256"], smallerConstraint[1])[0]).to.be.equals(110n);

    // Add a valid entry
    await this.submitPollingEntry({
      signer: this.signers.alice,
      surveyId: 0,
      entry: true,
      surveyMetadataType: surveyMetadataType,
      userMetadata: [50, true],
    });

    // Add an invalid one
    await this.submitPollingEntry({
      signer: this.signers.bob,
      surveyId: 0,
      entry: true,
      surveyMetadataType: surveyMetadataType,
      userMetadata: [10000, true], // Invalid age entry
    });
    await awaitAllDecryptionResults();

    // Both user should have voted
    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.true;
    expect(await this.survey.hasVoted(0, this.signers.bob.address)).to.be.true;

    // Verify the vote validity
    expect((await this.survey.voteData(0, 0)).isValid).to.be.true; // Alice
    expect((await this.survey.voteData(0, 1)).isValid).to.be.false; // Bob
  });

  analyseScenarioTestCases.forEach(({ name, params }) => {
    it(`should handle analyse on: ${name}`, async function () {
      const voterNames = ACCOUNT_NAMES;
      const pollingVotes = params.pollingVotes;
      const surveyMetadataNames = params.surveyMetadataNames;
      const surveyMetadataTypes = params.surveyMetadataTypes;
      const userMetadata = params.userMetadata;

      const surveyParam = {
        ...validSurveyParam,
        minResponseThreshold: params.minResponseThreshold,
        metadataNames: surveyMetadataNames,
        metadataTypes: surveyMetadataTypes,
      };

      const transaction = await this.survey.createSurvey(surveyParam);
      await transaction.wait();

      /// Voting part
      for (let index = 0; index < pollingVotes.length; index++) {
        await this.submitPollingEntry({
          signer: this.signers[voterNames[index]],
          surveyId: 0,
          entry: pollingVotes[index],
          surveyMetadataType: surveyMetadataTypes,
          userMetadata: userMetadata[index],
        });
      }

      const surveyDataAfterVoting = await this.revealSurveyResult(0);
      expect(surveyDataAfterVoting.isCompleted).to.be.true;
      expect(surveyDataAfterVoting.isValid).to.be.true;
      expect(surveyDataAfterVoting.currentParticipants).to.be.equals(pollingVotes.length);
      expect(surveyDataAfterVoting.finalResult).to.be.equals(pollingVotes.filter(Boolean).length);

      // Create and execute the query
      await this.survey.createQuery(0, params.filters);
      await this.survey["executeQuery(uint256)"](0);
      await awaitAllDecryptionResults();

      // Read the result
      const queryData = await this.survey.queryData(0);
      expect(queryData.isCompleted).to.be.true;
      if (params.expectToBeValid) {
        expect(queryData.isValid).to.be.true;
        expect(queryData.finalSelectedCount).to.be.equals(4);
        expect(queryData.finalResult).to.be.equals(4);
      } else {
        expect(queryData.isValid).to.be.false;
      }
    });
  });
});
