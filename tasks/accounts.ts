import { Wallet, constants } from "ethers";
import { formatEther, parseEther } from "ethers/lib/utils";
import { AbiCoder, Bytes, formatUnits, parseUnits } from "ethers/lib/utils";
import { ethers, network } from "hardhat";
import { task } from "hardhat/config";

import { deployContract } from "./utils";

task("deploy-socalsale", "Deploy all socal contracts")
  // .addParam("pool", "UniswapV3 Pool")
  // .addParam("governance", "governer address")
  // .addParam("name", "Unipilot LP Token name")
  // .addParam("symbol", "Unipilot LP Token symbol")
  .setAction(async (cliArgs, { ethers, run, network }) => {
    await run("compile");

    const signer = (await ethers.getSigners())[0];
    console.log("Signer");
    console.log("  at", signer.address);
    console.log("  ETH", formatEther(await signer.getBalance()));

    //binance
    // const args = {
    //   ipfs: "www.ipfs.io",
    //   primaryToken: "0x631bC5d604CF283Fc9c6ed9483e60a461ebF6E93",
    //   protocolToken: "0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684",
    //   mdata: "/ipfs/",
    // };

    //rinkeby
    const args = {
      ipfs: "https://socal.mypinata.cloud/ipfs/QmPAzMfWwnFZom3fC2foG6r66bKM6LiysVQ9wYH8H9JhNh",
      primaryToken: "0xc778417e063141139fce010982780140aa0cd5ab",
      protocolToken: "0x47abdff3a3a7c05b3293c35802da39e6010e7a1e",
      mdata: "/",
    };

    console.log("Network");
    console.log("   ", network.name);
    console.log("Task Args");
    console.log(args);

    const socalMystery = await deployContract("SocalSale", await ethers.getContractFactory("SocalSale"), signer, [
      args.ipfs,
      args.primaryToken,
      args.protocolToken,
      args.mdata,
    ]);

    await socalMystery.deployTransaction.wait(5);

    delay(60000);

    await run("verify:verify", {
      address: socalMystery.address, // "0xA4AF9f76a357AccC4E8712A94e4f7b50Ed9e5230",
      constructorArguments: [args.ipfs, args.primaryToken, args.protocolToken, args.mdata],
    });
  });

function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
