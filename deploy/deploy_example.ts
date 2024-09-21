// import { writeFileSync } from "fs";
// import { upgrades, ethers } from "hardhat";
// import { resolve } from "path";
// import { getMintRequestTypedData } from "../libs/mint";
// import { vault } from "../types";
// import { toUtf8Bytes } from "ethers";
// import assert from 'node:assert';
// import * as dotenv from 'dotenv';
// dotenv.config();
// const now = new Date();
// const outputFile = resolve(__dirname, `../deployed-${now.toISOString()}.json`);
// let MockERC20Address = '';
// const MockERC20Decimals = 6;
// const MockERC20Name = 'USDC';
// const MintRequestSigner: string = process.env.MintRequestSigner as string;
// assert(MintRequestSigner, 'MintRequestSigner is required');
// const ManagerAddress: string = process.env.ManagerAddress as string;
// assert(ManagerAddress, 'ManagerAddress is required');

// const getvaultTokenName = (vaultName: string, d: Date) => {
//   // const d = new Date(maturityTimeString);
//   const YYMMDD = ``;
//   const vaultTokenName = `v${vaultName}-${YYMMDD}`;
//   return vaultTokenName;
// }

// const targets = []

// async function main() {
//   const chainId = await ethers.provider.getNetwork().then(n => n.chainId);
//   const signers = await ethers.getSigners();
//   const deployer = signers[0];
//   console.log({
//     deployerAddress: deployer.address,
//   })

//   if(!MockERC20Address) {
//     const MockERC20Factory = await ethers.getContractFactory("MockERC20");
//     const mockERC20 = await MockERC20Factory.deploy(MockERC20Name, MockERC20Name, MockERC20Decimals);
//     await mockERC20.waitForDeployment();
//     MockERC20Address = await mockERC20.getAddress();
//   }
  

//   const deploys: {
//     vaultProxy: vault;
//     vaultProxyAddress: string,
//     vaultImplementationAddress: string,
//     vaultTokenName: string,
//     vaultName: string,
//     maturityTimeString: string,
//     maxMintCap: bigint,
//   }[] = [];
//   const vaultFactory = await ethers.getContractFactory("vault");
//   for(const target of targets) {
//     const d = new Date(target.maturityTimeString);
//     const vaultTokenName = getvaultTokenName(target.vaultName, d);
//     const vaultProxy = await upgrades.deployProxy(vaultFactory, [deployer.address, vaultTokenName, vaultTokenName], { initializer: "initialize" });
//     await vaultProxy.waitForDeployment();
//     const vaultProxyAddress = await vaultProxy.getAddress();
//     const vaultImplementationAddress = await upgrades.erc1967.getImplementationAddress(vaultProxyAddress);


//     deploys.push({
//       vaultProxy: vaultProxy as unknown as vault,
//       vaultProxyAddress,
//       vaultImplementationAddress,
//       vaultTokenName,
//       ...target,
//     });

//   }

//   for(const deploy of deploys) {
//     // await deploy.vaultProxy.setUnderlyingAsset(MockERC20Address);
//     const pub = await deploy.vaultProxy.publish(
//       MockERC20Address,
//       getSec(deploy.maturityTimeString),
//       deploy.maxMintCap,
//     );
//     await pub.wait();
//     // setDomainSeparator
//     const typedData = getMintRequestTypedData(chainId);
//     await (await deploy.vaultProxy.setDomainSeparator(typedData.domain)).wait();
  
//     // setMintRequestVerifier
//     // await (await deploy.vaultProxy.setMintRequestVerifier(deployer.address)).wait();
//     await (await deploy.vaultProxy.setMintRequestVerifier(MintRequestSigner)).wait();

//     const MANAGER_ROLE = ethers.keccak256(toUtf8Bytes('MANAGER_ROLE'));
//     await (await deploy.vaultProxy.grantRole(MANAGER_ROLE, ManagerAddress)).wait();
//   }

//   const result = {
//     deployer: deployer.address,
//     MockERC20Name,
//     MockERC20Address,
//     MockERC20Decimals,
//     vaults: deploys.map(({
//       vaultProxyAddress,
//       vaultImplementationAddress,
//       vaultTokenName,
//       vaultName,
//       maturityTimeString,
//       maxMintCap,
//     }) => ({
//       vaultProxyAddress,
//       vaultImplementationAddress,
//       vaultTokenName: vaultTokenName,
//       vaultName: vaultName,
//       maturityTimeString,
//       maxMintCap: maxMintCap.toString(),
//     })),
//   };
//   console.log(result);

//   writeFileSync(outputFile, JSON.stringify(result, null, 2));
// }

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });


// function getSec(time: Date | string): number {
//   if(typeof time === 'string') {
//     return getSec(new Date(time));
//   }
//   return Math.floor(time.getTime() / 1000);
// }
