import { ethers } from "hardhat";
import { tokenDetails} from "./token-details";
import hre from 'hardhat'



async function main() {
  
  // const networkName = hre.network.name;
  let chainId = hre.network.config.chainId!;
	console.log('chainId:  ', chainId );
  if(!chainId) chainId = 31337;
  
  let faucetArtifact = await ethers.getContractFactory("Faucet");
  
  const [owner] = await ethers.getSigners();
  console.log('Deployer :  ', owner.address );
  const faucet  = await faucetArtifact.deploy( {
    gasPrice: '40000000000',
    gasLimit: '30000000'
  });
  await faucet.deployed();
  console.log('Faucet Deployed at  ', faucet.address );

}





// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});




