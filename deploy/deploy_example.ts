import { writeFileSync } from "fs";
import { ethers } from "hardhat";
import { resolve } from "path";

import * as dotenv from 'dotenv';
dotenv.config();
const now = new Date();
const outputFile = resolve(__dirname, `../deployed-${now.toISOString()}.json`);

async function main() {
  const chainId = await ethers.provider.getNetwork().then(n => n.chainId);
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  console.log({
    deployerAddress: deployer.address,
    chainId,
  })

  const erc20Factory = await ethers.getContractFactory("MockERC20")
  const usdcContract = await erc20Factory.deploy("USDC", "USDC", 6)
  await usdcContract.deploymentTransaction()!.wait(1)
  const usdcAddress = await usdcContract.getAddress();
  await usdcContract.mint(deployer.address, 1000n * 10n ** 6n);

  const eurcContract = await erc20Factory.deploy("eurc", "eurc", 6)
  await eurcContract.deploymentTransaction()!.wait(1)
  const eurcAddress = await eurcContract.getAddress();
  await eurcContract.mint(deployer.address, 2000n * 10n ** 6n);

// ARB 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165
// BASE 
  const senderFactory = await ethers.getContractFactory("OmniForwardMarket")
  const senderContract = await senderFactory.deploy(
    "bU-12DEC24",
    "bU-12DEC24",
    usdcAddress,
    eurcAddress,
    172800000,
    usdcAddress
  )
  await senderContract.deploymentTransaction()!.wait(1)
  const contractAddress = await senderContract.getAddress();


  const result = {
    deployer: deployer.address,
    contractAddress,
    usdcAddress,
    eurcAddress,
  };
  console.log(result);

  writeFileSync(outputFile, JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


function getSec(time: Date | string): number {
  if(typeof time === 'string') {
    return getSec(new Date(time));
  }
  return Math.floor(time.getTime() / 1000);
}
