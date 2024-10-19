import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumberish } from "ethers";
import { ERC20__factory, Token, ZLend } from "../typechain-types";
import { erc20 } from "../typechain-types/@openzeppelin/contracts/token";

describe("zLend", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployZLendFixture() {
    

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Verifier = await ethers.getContractFactory("Verifier");
    const verifier = await Verifier.deploy( {  });

    const ZLendToken = await ethers.getContractFactory("zLendToken");
    const zLendToken = await ZLendToken.deploy('ZLend', 'ZLD', {  });

    

    console.log('ZXXX L: ', zLendToken.address,verifier.address);

    const ZLendContract = await ethers.getContractFactory("zLend");
    const zLend = await ZLendContract.deploy(zLendToken.address,verifier.address, {  });

    await zLendToken.transfer(zLend.address, ethers.utils.parseEther('100000000'));

    const Token1 = await ethers.getContractFactory("Token");
    const USDT_TOKEN = await Token1.deploy('USDT', 'USDT', {  });

    const Token2 = await ethers.getContractFactory("Token");
    const WETH_TOKEN = await Token2.deploy('WETH', 'WETH', {  });

    await setupTokenOnZLend(zLend, {
        name: 'USDT',
        
        LTV: 55, // Loan-to-Value (LTV) Ratio, Lower is better
        interest_rate: 1, // interest paid to depositors
        borrow_stable_rate: 2, // interest paid by borrowers
        toUsd: 0.9921,
        decimal: 18
    }, USDT_TOKEN.address)

    await setupTokenOnZLend(zLend, {
        name: 'WETH',
        
        LTV: 60, // Loan-to-Value (LTV) Ratio, Lower is better
        interest_rate: 10, // interest paid to depositors
        borrow_stable_rate: 20, // interest paid by borrowers
        toUsd: 2667,
        decimal: 18
    }, WETH_TOKEN.address)


    const MicroLoan = await ethers.getContractFactory("zLendMicroLoan");
    const zLendMicroLoan = await MicroLoan.deploy(zLend.address, zLendToken.address, {  });
    


    return { zLend, zLendToken, verifier, owner, otherAccount, USDT_TOKEN, WETH_TOKEN, zLendMicroLoan };
  }

  describe("Deployment", function () {
    it("Should get the right borrowable", async function () {
      const { verifier, zLend, zLendToken, USDT_TOKEN,WETH_TOKEN, owner } = await loadFixture(deployZLendFixture);
        
      console.log('DPIn32: ', zLendToken.address,verifier.address, owner.address)

        let txApprovReceipt = await (await USDT_TOKEN.approve(zLend.address, ethers.utils.parseEther('10000'))).wait();
        console.log('USDT balance : ', await USDT_TOKEN.balanceOf( owner.address), ethers.utils.formatUnits(await USDT_TOKEN.balanceOf( owner.address)))
        
        
        console.log('allowance: ',await USDT_TOKEN.allowance(owner.address, zLend.address))

        let tx = await zLend.lend(USDT_TOKEN.address, ethers.utils.parseEther('100'))
        await tx.wait();

        const tokens = await zLend.getPoolTokens();
    
        const list = []
        for (let i = 0; i < tokens.length; i++){
            const currentToken = tokens[i]

            const newToken = await normalizeToken( zLend as any,currentToken, owner.address);

            list.push(newToken)
        }
        console.log(list)
        // expect(vAddr).not.to.equal(undefined);
    });

    it("Should allow requesting microLoan", async function () {
        const { verifier, zLend, zLendToken, USDT_TOKEN,WETH_TOKEN, owner, zLendMicroLoan } = await loadFixture(deployZLendFixture);


          
        console.log('Mircoloan: ', zLendMicroLoan.address,verifier.address, owner.address)
  
        let txReqLoan = await (await zLendMicroLoan.requestLoan(USDT_TOKEN.address, ethers.utils.parseEther('10000'), '90')).wait();
        console.log('txReqLoan Reeipt : ', txReqLoan.status)

        txReqLoan = await (await zLendMicroLoan.requestLoan(USDT_TOKEN.address, ethers.utils.parseEther('100000'), '90')).wait();
        console.log('txReqLoan Reeipt : ', txReqLoan.status)

        txReqLoan = await (await zLendMicroLoan.requestLoan(USDT_TOKEN.address, ethers.utils.parseEther('1000'), '90')).wait();
        console.log('txReqLoan Reeipt : ', txReqLoan.status)

        console.log('count: ', await zLendMicroLoan.loanRequestCounter())
        
        let requests = await zLendMicroLoan.getLoanRequests(0,3);
        console.log('requests : ', requests.length)

        console.log('requests : ', requests.map((m: any)=>m.id))

        requests = await zLendMicroLoan.getLoanRequests(0,await zLendMicroLoan.loanRequestCounter());
        console.log('requests full : ', requests.length)

        console.log('requests full : ', requests.map((m: any)=>m.id))
          
          // expect(vAddr).not.to.equal(undefined);
      });

    
  });

 
});



async function setupTokenOnZLend(zLend: any, tokenDetails: any, tokenAddress: string) {
    // const tAddr = token.address;
    
    // console.log('Adding token ',  token.name, ' with address ', tAddr, ' and feed address ',  token.feed_address)
    // const tx = await zLend.updateTokenPrice(tAddr, ethers.utils.parseUnits(token.toUsd.toFixed(2), 0));
    const tx = await zLend.updateTokenPrice(tokenAddress, ethers.utils.parseUnits((tokenDetails.toUsd ?? 0).toString(), tokenDetails.decimal), tokenDetails.decimal?.toFixed(0));
    //const tx = await zLend.updateTokenPrice(tAddr, 0, token.decimal.toFixed(0) );
    await tx.wait();

    const tx2 = await zLend.addPoolTokens(tokenDetails.name, tokenAddress, tokenDetails.LTV , tokenDetails.borrow_stable_rate, tokenDetails.interest_rate);
    await tx2.wait();

    // const tx3 = await zLend.addTokensForBorrowing(token.name, tokenAddress, token.LTV, token.borrow_stable_rate, token.interest_rate);
    // await tx3.wait();
  }


  
const normalizeToken = async ( zContract: ZLend, currentToken: any, account: any) => {
    const fromWei = (amount: BigNumberish) => {
      
      try{
        return ethers.utils.formatUnits(amount, 18);
      }catch{
        console.error('error from wei ', amount)
        return '0';
      }
    };
    
    
  
    const tokenInst = await ethers.getContractAt('Token',currentToken.tokenAddress);
    if(!tokenInst){
      return undefined;
    }
  
    let decimals =  18
    try{
      decimals = await tokenInst.decimals();
    }catch(err){
  
    }
  
    const symbol = await tokenInst.symbol();
    const contract = zContract;
    // const contract = WrapperBuilder.wrap(zContract).usingDataService(
    //   {
    //     dataServiceId: "redstone-main-demo",
    //     uniqueSignersCount: 1,
    //     dataFeeds: [symbol],
    //   },
    // );
    
  
    const walletBalance = await tokenInst.balanceOf(account);
    
    const totalSuppliedInContract = await contract.getTotalTokenSupplied(currentToken.tokenAddress);
    const totalBorrowedInContract = await contract.getTotalTokenBorrowed(currentToken.tokenAddress);
    
    
    let utilizationRate =ethers.constants.Zero;
    if(  !totalSuppliedInContract.isZero()){
      utilizationRate = totalBorrowedInContract.mul(100).div(totalSuppliedInContract);
  
    }
    
    const userTokenBorrowedAmount = await contract.tokensBorrowedAmount(currentToken.tokenAddress, account);
    
    const userTokenLentAmount = await contract.tokensLentAmount(currentToken.tokenAddress, account);
    
    const userTotalAmountAvailableToWithdrawInDollars = await contract.getTokenAvailableToWithdraw(account);
    
    const userTotalAmountAvailableForBorrowInDollars = await contract.getUserTotalAmountAvailableForBorrowInDollars(account);
    
    const walletBalanceInDollars = await contract.getAmountInDollars(walletBalance, currentToken.tokenAddress);
    
    const totalSuppliedInContractInDollars = await contract.getAmountInDollars(totalSuppliedInContract, currentToken.tokenAddress);
    
    const totalBorrowedInContractInDollars = await contract.getAmountInDollars(totalBorrowedInContract, currentToken.tokenAddress);
    
    const userTokenBorrowedAmountInDollars = await contract.getAmountInDollars(userTokenBorrowedAmount, currentToken.tokenAddress);
    
    const userTokenLentAmountInDollars = await contract.getAmountInDollars(userTokenLentAmount, currentToken.tokenAddress);
    
    const availableAmountInContract = totalSuppliedInContract.sub(totalBorrowedInContract).toString();
    
    const availableAmountInContractInDollars = await contract.getAmountInDollars(availableAmountInContract, currentToken.tokenAddress);
    
    const result = await contract.oneTokenEqualsHowManyDollars(currentToken.tokenAddress);
    
    const price = result[0];
    const decimal = +ethers.utils.formatUnits(result[1], 0);
  
    // console.log("currentToken:", currentToken)
    // const oneTokenToDollar = ethers.utils.parseUnits(`${price}`, 18).div((10 ** decimal).toString() ).toString();
    // const oneTokenToDollar = BigNumber.from(`${price}`).div(10 ** decimal).toString();
  
    const oneTokenToDollar =(parseFloat(`${price}`)/(10 ** decimal)).toString();
    
    return {
      name: currentToken.name,
      // image: tokenImages[currentToken.name],
      tokenAddress: currentToken.tokenAddress,
      userTotalAmountAvailableToWithdrawInDollars: fromWei(userTotalAmountAvailableToWithdrawInDollars),
      userTotalAmountAvailableForBorrowInDollars: fromWei(userTotalAmountAvailableForBorrowInDollars),
      walletBalance: {
        amount: fromWei(walletBalance),
        inDollars: fromWei(walletBalanceInDollars),
      },
      totalSuppliedInContract: {
        amount: fromWei(totalSuppliedInContract),
        inDollars: fromWei(totalSuppliedInContractInDollars),
      },
      totalBorrowedInContract: {
        amount: fromWei(totalBorrowedInContract),
        inDollars: fromWei(totalBorrowedInContractInDollars),
      },
      availableAmountInContract: {
        amount: fromWei(availableAmountInContract),
        inDollars: fromWei(availableAmountInContractInDollars),
      },
      userTokenBorrowedAmount: {
        amount: fromWei(userTokenBorrowedAmount),
        inDollars: fromWei(userTokenBorrowedAmountInDollars),
      },
      userTokenLentAmount: {
        amount: fromWei(userTokenLentAmount),
        inDollars: fromWei(userTokenLentAmountInDollars),
      },
      LTV: currentToken.minimumLTV.toNumber(),
      borrowAPYRate: currentToken.stableRate.toNumber(),
      utilizationRate: utilizationRate,
      oneTokenToDollar,
      decimals
    }
  }