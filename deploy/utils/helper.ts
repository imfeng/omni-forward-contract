import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers } from "hardhat";

export async function deployMock(signer: HardhatEthersSigner, tokenName: string, decimals: number) {
  const MockTokenFactory = await ethers.getContractFactory("MockERC20");
  // const MockVTokenFactory = await ethers.getContractFactory("MockVToken");

  const tokenContract = await MockTokenFactory.deploy(tokenName, tokenName, decimals);
  // const vTokenContract = await MockVTokenFactory.deploy(`Venus ${tokenName}`, `v${tokenName}`);

  await Promise.all([
    tokenContract.waitForDeployment(),
    // vTokenContract.waitForDeployment()
  ]);

  const testTokenAddress = await tokenContract.getAddress();
  // const testVTokenAddress = await vTokenContract.getAddress();
  
  // await vTokenContract.setUnderlying(testTokenAddress);
  // await tokenContract.setVToken(testVTokenAddress);

  return {
    tokenName,
    decimals,
    tokenContract,
    // vTokenContract,
    testTokenAddress,
    // testVTokenAddress,
  };
}