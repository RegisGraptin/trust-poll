import { ethers } from "hardhat";

import type { MyConfidentialERC20 } from "../../types";
import { getSigners } from "../signers";

export async function deploySurveyFixture(): Promise<MyConfidentialERC20> {
  const signers = await getSigners();

  const contractFactory = await ethers.getContractFactory("Survey");
  const contract = await contractFactory.connect(signers.alice).deploy();
  await contract.waitForDeployment();

  return contract;
}
