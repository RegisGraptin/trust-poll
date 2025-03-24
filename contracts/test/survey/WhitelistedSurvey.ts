import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
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

    // "alice", "bob", "carol", "dave"
    const whitelistedAddresses = [
      [this.signers.alice.address],
      [this.signers.bob.address],
      [this.signers.carol.address],
      [this.signers.dave.address],
    ];

    this.whitelistedTree = StandardMerkleTree.of(whitelistedAddresses, ["address"]);

    // Helper functions
    this.submitPollingEntry = async (
      signer: HardhatEthersSigner,
      surveyId: number,
      entry: boolean,
      userMetadata: [] = [], // Optional - Depends on the survey
    ) => {
      const input = this.fhevm.createEncryptedInput(this.contractAddress, signer.address);
      const inputs = await input.add256(Number(entry)).encrypt();

      // Get the user proof
      let whitelistedProof;
      for (const [i, v] of this.whitelistedTree.entries()) {
        if (v[0] === signer.address) {
          whitelistedProof = this.whitelistedTree.getProof(i);
          break;
        }
      }

      // Create a new entry
      // ["submitEntry(uint256,bytes32,uint256[],bytes,bytes32[])"]
      const transaction = await this.survey
        .connect(signer)
        .submitWhitelistedEntry(surveyId, inputs.handles[0], userMetadata, inputs.inputProof, whitelistedProof);
      await transaction.wait();
    };
  });

  it("should create a new whitelisted survey", async function () {
    const surveyParam = {
      surveyPrompt: "Are you part of the group?",
      surveyType: SurveyType.POLLING,
      isWhitelisted: true,
      whitelistRootHash: this.whitelistedTree.root,
      surveyEndTime: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // +7 days
      responseThreshold: 4,
      metadataTypes: [],
    };

    const transaction = await this.survey.createSurvey(surveyParam);
    await transaction.wait();

    // Get the survey information at the index 0
    const surveyData = await this.survey.surveyParams(0);
    // console.log("surveyData:", surveyData);

    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.false;

    // Create a new entry
    await this.submitPollingEntry(this.signers.alice, 0, true);

    expect(await this.survey.hasVoted(0, this.signers.alice.address)).to.be.true;
  });
});
