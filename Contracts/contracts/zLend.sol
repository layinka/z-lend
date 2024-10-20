// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./LendingHelper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
import "@redstone-finance/evm-connector/contracts/data-services/MainDemoConsumerBase.sol";
import "./ZK/LTVVerifier.sol";

interface IExtendedERC20 is IERC20 {
    // Additional functions for extended ERC20
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
} 

error NotEnoughBalance();
error ProofVerificationfailed();
error LTVLowerThanMinimum();
error DuplicatePoolToken();
error TokenNotAllowed();

library zLendLibrary{
    struct Token {
        address tokenAddress;
        uint256 minimumLTV; // Loan-to-Collateral Value (LTV) Ratio, Lower is better for platform, higher is better for borrower
        uint256 stableRate;
        uint256 interestRate;
        string name;       
    }
}



interface IzLend{
    
    function usersLTV(address key) external view returns (uint256);
    function getPoolToken(address key) external view returns (zLendLibrary.Token memory);

}

contract zLend is Ownable, ReentrancyGuard, MainDemoConsumerBase  {
    using LendingHelper for address;
    using SafeERC20 for IERC20;

    address[] public lenders;
    address[] public borrowers;

    Verifier public usersLTVVerifier;

    uint public constant DEFAULT_LTV=50;

    // {tokenAddres: {userAddr : amount}}
    mapping(address => mapping(address => uint256)) public tokensLentAmount;
    mapping(address => mapping(address => uint256)) public tokensBorrowedAmount;

    // {noOfTokensLent[1,2,3,4]: {userAddr: tokenAddres}}
    mapping(uint256 => mapping(address => address)) public tokensLent;
    mapping(uint256 => mapping(address => address)) public tokensBorrowed;

    // mapping(address => address) public tokenToPriceFeed;
    mapping(address => uint256) public tokenPriceFeed;
    mapping(address => uint256) public tokenPriceFeedDec;

    mapping(address => uint256) public usersLTV;

    //
    // 0 - Twitter
    // 1 - WalletActive
    // 2-  GitcoinPasport
    // 3 - BaseENS
    mapping(address => mapping(uint256 => bool)) public provenBoosters;

    event Withdraw(
        address sender,
        uint256 amount,
        uint256 tokenToWithdrawInDollars,
        uint256 availableToWithdraw,
        uint256 totalAmountLentInDollars,
        uint256 zLTokenToRemove
    );
    event PayDebt(
        address sender,
        int256 index,
        uint256 tokenAmountBorrowed,
        uint256 totalTokenAmountToCollectFromUser
    );
    event Borrow(
        address sender,
        uint256 amountInDollars,
        uint256 totalAmountAvailableForBorrowInDollars,
        bool userPresent,
        int256 userIndex,
        uint256 currentUserTokenBorrowedAmount
    );
    event Supply(address sender,uint256 currentUserTokenLentAmount);
    
    

    // struct Token {
    //     address tokenAddress;
    //     uint256 minimumLTV; // Loan-to-Collateral Value (LTV) Ratio, Lower is better for platform, higher is better for borrower
    //     uint256 stableRate;
    //     uint256 interestRate;
    //     string name;       
    // }

    //Array of Struct Token [Dai, Weth, Fau, Link]
    zLendLibrary.Token[] public poolTokensList;

    
    mapping(address => zLendLibrary.Token) public poolTokens;
    

    IERC20 public zLToken;

    uint256 public noOfTokensLent = 0;
    uint256 public noOfTokensBorrowed = 0;

    constructor(address _token, Verifier _ltvVerifier) {
        zLToken = IERC20(_token);
        usersLTVVerifier=_ltvVerifier;
    }

    

    // function getEthPrice() public view returns (uint256) {
    //     RedStoneOracleRequest request = RedStoneOracle.createDataRequest(
    //         dataFeed="ETH_USD",
    //         frequency="10m",
    //         format="json"
    //     );
    //     RedStoneOracleResponse response = RedStoneOracle.sendRequest(request);
    //     return response.data.price;
    // }

    // function getPriceFromRedstone(string memory dataFeed) public view returns (uint256) {
    //     RedStoneOracleRequest request = RedStoneOracle.createDataRequest(
    //         dataFeed=dataFeed,
    //         frequency="10m",
    //         format="json"
    //     );
    //     RedStoneOracleResponse response = RedStoneOracle.sendRequest(request);
    //     return response.data.price;
    // }


    function updateUserLTV(
        Verifier.Proof memory proof,
        uint[1] memory inputs,
        uint LTV,
        uint[] memory boosts
    ) public returns (bool) {
        require(usersLTVVerifier.verifyTx(proof, inputs), ProofVerificationfailed());

        // // Here you calculate the LTV and provide the loan
        // uint LTV = calculateLTV(inputs);
        // // Loan logic using LTV, e.g., send funds to userAddress
        // return true;

        usersLTV[msg.sender]=LTV;

        for (uint i = 0; i < boosts.length; i++) {
            provenBoosters[msg.sender][boosts[i]] = true;
        }
        
    }
    

    function addPoolTokens(
        string memory name,
        address tokenAddress,
        uint256 minimumLTV,
        uint256 borrowStableRate,
        uint256 interestRate
    ) external onlyOwner {        

        if (poolTokens[tokenAddress].tokenAddress == address(0)) {
            zLendLibrary.Token memory token = zLendLibrary.Token(tokenAddress, minimumLTV, borrowStableRate,interestRate, name);
            poolTokens[tokenAddress]= token;
            poolTokensList.push(token);
        }else{
            revert DuplicatePoolToken();
        }
    }

    function poolTokensCount() public view returns ( uint){
        return poolTokensList.length;
    }

    

    // function addTokenToPriceFeedMapping(address tokenAddress, address tokenToUsdPriceFeed) external onlyOwner {
    //     tokenToPriceFeed[tokenAddress] = tokenToUsdPriceFeed;
    // }

    function updateTokenPrice(address tokenAddress, uint usdPrice, uint decimal) public onlyOwner  {
        tokenPriceFeed[tokenAddress] = usdPrice;
        tokenPriceFeedDec[tokenAddress] = decimal;
    }

    function getLendersArray() public view returns (address[] memory) {
        return lenders;
    }

    function getBorrowersArray() public view returns (address[] memory) {
        return borrowers;
    }

    function getPoolTokens() public view returns (zLendLibrary.Token[] memory) {
        return poolTokensList;
    }

    function getPoolToken(address token) public view returns (zLendLibrary.Token memory) {
        return poolTokens[token];
    }

    // function getPoolToken(address token) public view returns (zLendLibrary.Token memory) {
    //     return poolTokens[token];
    // }


    function lend(address tokenAddress, uint256 amount) external payable nonReentrant {
        require(isPoolToken(tokenAddress), 'TokenNotAllowed');
        require(amount > 0, 'AmountLT0');

        IERC20 token = IERC20(tokenAddress);

        if(token.balanceOf(msg.sender) < amount){
            revert NotEnoughBalance();
        }

        console.log('sndr: %s, amount: %d , balance: %d', msg.sender, amount, token.balanceOf(msg.sender) );

        
        token.safeTransferFrom(msg.sender, address(this), amount);

        (bool userPresent, int256 userIndex) = msg.sender.isUserPresentIn(lenders);

        if (userPresent) {
            updateUserTokensBorrowedOrLent(tokenAddress,amount,userIndex,"lenders");
        } else {
            lenders.push(msg.sender);
            tokensLentAmount[tokenAddress][msg.sender] = amount;
            tokensLent[noOfTokensLent++][msg.sender] = tokenAddress;
        }

         // Send some tokens to the user equivalent to the token amount lent.
        zLToken.safeTransfer(msg.sender, getAmountInDollars(amount, tokenAddress));

        emit Supply(msg.sender,tokensLentAmount[tokenAddress][msg.sender]);
    }

    
    function borrow(uint256 amount, address tokenAddress) external nonReentrant {
        require(isPoolToken(tokenAddress), TokenNotAllowed());
        require(amount > 0, 'AmountLT0');
        if(usersLTV[msg.sender]==0){
            usersLTV[msg.sender]=DEFAULT_LTV;
        }
        require(usersLTV[msg.sender] >= poolTokens[tokenAddress].minimumLTV, LTVLowerThanMinimum() );

        uint256 totalAmountAvailableForBorrowInDollars = getUserTotalAmountAvailableForBorrowInDollars(msg.sender);
        uint256 amountInDollars = getAmountInDollars(amount, tokenAddress);

        

        require(amountInDollars <= totalAmountAvailableForBorrowInDollars, 'NotEnoughUSD');

        IERC20 token = IERC20(tokenAddress);

        

        require(token.balanceOf(address(this)) >= amount,"Insufficient Token");

        token.safeTransfer(msg.sender, amount);

        //Library function isUserPresentIn
        (bool userPresent, int256 userIndex) = msg.sender.isUserPresentIn(borrowers);

        if (userPresent) {
          updateUserTokensBorrowedOrLent(tokenAddress,amount,userIndex,"borrowers");
        } else {
            borrowers.push(msg.sender);
            tokensBorrowedAmount[tokenAddress][msg.sender] = amount;
            tokensBorrowed[noOfTokensBorrowed++][msg.sender] = tokenAddress;
        }

        emit Borrow(
            msg.sender,
            amountInDollars,
            totalAmountAvailableForBorrowInDollars,
            userPresent,
            userIndex,            
            tokensBorrowedAmount[tokenAddress][msg.sender]
        );
    }

    function payDebt(address tokenAddress, uint256 amount) external nonReentrant {
        require(amount > 0, 'AmountLT0');

        int256 index = msg.sender.indexOf(borrowers);

        
        require(index >= 0, 'IXError');

        uint256 tokenBorrowed = tokensBorrowedAmount[tokenAddress][msg.sender];

        

        require(tokenBorrowed > 0, 'NoBorrowBalance');
        IERC20 token = IERC20(tokenAddress);

        token.safeTransferFrom(msg.sender,address(this),amount + interest(tokenAddress, tokenBorrowed));

        tokensBorrowedAmount[tokenAddress][msg.sender] -= amount;

        // Checking if all total amount borrowed by a user = 0, then remove the user from borrowers list;
        if (getTotalAmountBorrowedInDollars(msg.sender) == 0) {
            borrowers[uint256(index)] = borrowers[borrowers.length - 1];
            borrowers.pop();
        }

        emit PayDebt(
            msg.sender,
            index,
            tokenBorrowed,
            amount + interest(tokenAddress, tokenBorrowed)
            
        );
    }

    function withdraw(address tokenAddress, uint256 amount) external nonReentrant {
        require(amount > 0, 'AmountLT0');

        require(msg.sender.indexOf(lenders) >= 0, 'IXError');

        IERC20 token = IERC20(tokenAddress);

        uint256 tokenToWithdrawInDollars = getAmountInDollars(amount,tokenAddress);
        uint256 availableToWithdraw = getTokenAvailableToWithdraw(msg.sender);

        uint totalTokenSuppliedInContract = getTotalTokenSupplied(tokenAddress);
        uint totalTokenBorrowedInContract = getTotalTokenBorrowed(tokenAddress);

        require(amount <= (totalTokenSuppliedInContract - totalTokenBorrowedInContract), 'AmountDpstdNotEnough');

        

        require(tokenToWithdrawInDollars <= availableToWithdraw, 'availableToWithdrawNotEnough');

        uint256 zLTokenToRemove = getAmountInDollars(amount, tokenAddress);
        uint256 zLTokenBalance = zLToken.balanceOf(msg.sender);

        if (zLTokenToRemove <= zLTokenBalance) {
            zLToken.safeTransferFrom(msg.sender, address(this), zLTokenToRemove);
        } else {
            zLToken.safeTransferFrom(msg.sender, address(this), zLTokenBalance);
        }

        token.safeTransfer(msg.sender, amount);

        tokensLentAmount[tokenAddress][msg.sender] -= amount;

        emit Withdraw(
            msg.sender,
            amount,
            tokenToWithdrawInDollars,
            availableToWithdraw,
            getTotalAmountLentInDollars(msg.sender),
            zLTokenToRemove
        );

        if (getTotalAmountLentInDollars(msg.sender) <= 0) {
            lenders[uint256(msg.sender.indexOf(lenders))] = lenders[lenders.length - 1];
            lenders.pop();
        }
    }

    function getTokenAvailableToWithdraw(address user)public view returns (uint256){

        uint256 totalAmountBorrowedInDollars = getTotalAmountBorrowedInDollars(user);

        uint remainingCollateral = 0;

        if (totalAmountBorrowedInDollars > 0 ){
            remainingCollateral = getRemainingCollateral(user);
        }else{
            remainingCollateral = getTotalAmountLentInDollars(user);
        }

        if (remainingCollateral < totalAmountBorrowedInDollars){return 0;}

        return remainingCollateral - totalAmountBorrowedInDollars;
    }

    function getRemainingCollateral(address user)public view returns (uint256){
           uint256 remainingCollateral = 0;
           for (uint256 i = 0; i < noOfTokensLent; i++)
           {
               address userLentTokenAddressFound = tokensLent[i][user];

               if (userLentTokenAddressFound !=0x0000000000000000000000000000000000000000)
               {
                 uint256 tokenAmountLentInDollars = getAmountInDollars(
                   tokensLentAmount[userLentTokenAddressFound][user],
                   userLentTokenAddressFound);

                 remainingCollateral += (tokenAmountLentInDollars * (usersLTV[user]==0 ? DEFAULT_LTV: usersLTV[user])/100) ;
               }
           }
           return remainingCollateral;
       }

       function getTotalAmountBorrowedInDollars(address user) public view returns (uint256){
           uint256 totalAmountBorrowed = 0;

           for (uint256 i = 0; i < noOfTokensBorrowed; i++) {
               address userBorrowedTokenAddressFound = tokensBorrowed[i][user];

               if (userBorrowedTokenAddressFound != 0x0000000000000000000000000000000000000000)
               {
                  ///tokenAmountBorrowed is tokensBorrowedAmount[userBorrowedTokenAddressFound][user];

                   uint256 tokenAmountBorrowedInDollars = getAmountInDollars(
                       tokensBorrowedAmount[userBorrowedTokenAddressFound][user],
                       userBorrowedTokenAddressFound
                   );

                   totalAmountBorrowed += tokenAmountBorrowedInDollars;
               }
           }
           return totalAmountBorrowed;
       }

       function getTotalAmountLentInDollars(address user) public view returns (uint256){
           uint256 totalAmountLent = 0;
           for (uint256 i = 0; i < noOfTokensLent; i++) {
               if (tokensLent[i][user] !=0x0000000000000000000000000000000000000000)
               {
                   uint256 tokenAmountLent = tokensLentAmount[tokensLent[i][user]][user];

                   uint256 tokenAmountLentInDollars = getAmountInDollars(tokenAmountLent,tokensLent[i][user]);

                   totalAmountLent += tokenAmountLentInDollars;
               }
           }
           return totalAmountLent;
       }

       function interest(address tokenAddress, uint256 tokenBorrowed) public view returns (uint256){
           return (tokenBorrowed * getTokenFrom(tokenAddress).stableRate/100) ;
       }

       function getTokenFrom(address tokenAddress) public view returns (zLendLibrary.Token memory){
           return poolTokens[tokenAddress];           
       }

       function getUserTotalAmountAvailableForBorrowInDollars(address user) public view returns (uint256){
          // uint256 totalAvailableToBorrow = 0;

          uint256 userTotalCollateralToBorrow = 0;
          uint256 userTotalCollateralAlreadyBorrowed = 0;

        //   for (uint256 i = 0; i < lenders.length; i++) {
        //       address currentLender = lenders[i];
        //       if (currentLender == user) {
        //         for (uint256 j = 0; j < tokensForLending.length; j++) {
        //           Token memory currentTokenForLending = tokensForLending[j];
        //           uint256 currentTokenLentAmount = tokensLentAmount[currentTokenForLending.tokenAddress][user];
        //           uint256 currentTokenLentAmountInDollar = getAmountInDollars(
        //               currentTokenLentAmount,
        //               currentTokenForLending.tokenAddress
        //           );
        //           uint256 availableInDollar = (currentTokenLentAmountInDollar * currentTokenForLending.LTV) / 10**18;
        //           userTotalCollateralToBorrow += availableInDollar;
        //         }
        //         break;
        //       }
        //   }

        for (uint256 j = 0; j < poolTokensList.length; j++) {
            zLendLibrary.Token memory currentTokenForLending = poolTokensList[j];
            uint256 currentTokenLentAmount = tokensLentAmount[currentTokenForLending.tokenAddress][user];
            uint256 currentTokenLentAmountInDollar = getAmountInDollars(
                currentTokenLentAmount,
                currentTokenForLending.tokenAddress
            );
            console.log('currentTokenLentAmount: %d, currentTokenLentAmountInDollar: %d ', currentTokenLentAmount, currentTokenLentAmountInDollar);
            uint256 availableInDollar = (currentTokenLentAmountInDollar * (usersLTV[user]==0 ? DEFAULT_LTV: usersLTV[user]) / 100 ) ;
            userTotalCollateralToBorrow += availableInDollar;

            console.log('availableInDollar: %d, currentTokenLentAmountInDollar: %d ', availableInDollar, userTotalCollateralToBorrow);
        }

            
        // if (currentBorrower == user) {
        for (uint256 j = 0; j < poolTokensList.length; j++) {
            zLendLibrary.Token memory currentTokenForBorrowing = poolTokensList[j];
            uint256 currentTokenBorrowedAmount = tokensBorrowedAmount[currentTokenForBorrowing.tokenAddress][user];
            uint256 currentTokenBorrowedAmountInDollar = getAmountInDollars(
                    (currentTokenBorrowedAmount),
                    currentTokenForBorrowing.tokenAddress
                );

            userTotalCollateralAlreadyBorrowed += currentTokenBorrowedAmountInDollar;
        }
                
            // }

        //   for (uint256 i = 0; i < borrowers.length; i++) {
        //       address currentBorrower = borrowers[i];
        //       if (currentBorrower == user) {
        //           for (uint256 j = 0; j < tokensForBorrowing.length; j++) {
        //               Token memory currentTokenForBorrowing = tokensForBorrowing[j];
        //               uint256 currentTokenBorrowedAmount = tokensBorrowedAmount[currentTokenForBorrowing.tokenAddress][user];
        //               uint256 currentTokenBorrowedAmountInDollar = getAmountInDollars(
        //                       (currentTokenBorrowedAmount),
        //                       currentTokenForBorrowing.tokenAddress
        //                   );

        //               userTotalCollateralAlreadyBorrowed += currentTokenBorrowedAmountInDollar;
        //           }
        //           break;
        //       }
        //   }

          return userTotalCollateralToBorrow - userTotalCollateralAlreadyBorrowed;
      }


       function isPoolToken(address tokenAddress) private view returns (bool){
           
           return poolTokens[tokenAddress].tokenAddress != address(0) && poolTokens[tokenAddress].tokenAddress==tokenAddress;
       }

       function isTokenAlreadyInPool(zLendLibrary.Token memory token) private view returns (bool){
           
           return poolTokens[token.tokenAddress].tokenAddress != address(0) && poolTokens[token.tokenAddress].tokenAddress==token.tokenAddress;
       }

       function getAmountInDollars(uint256 amount, address tokenAddress) public view returns (uint256){
          (uint256 dollarPerToken,uint256 decimals) = oneTokenEqualsHowManyDollars(tokenAddress);
          uint256 totalAmountInDollars = (amount * dollarPerToken) / (10**decimals);
          return totalAmountInDollars;
        }

        function getPriceInUSDFromRedstone(address tokenAddress) public view returns (uint256) {
            string memory feedId = IExtendedERC20(tokenAddress).symbol();
            uint256 priceInUSD = getOracleNumericValueFromTxMsg(bytes32(bytes(feedId)));
            return priceInUSD ; // * (10 ** 8);
        }

        function getPriceInUSDFromRedstone(string memory feedId) public view returns (uint256) {
            uint256 priceInUSD = getOracleNumericValueFromTxMsg(bytes32(bytes(feedId)));
            return priceInUSD ; // * (10 ** 8);
        }

      function oneTokenEqualsHowManyDollars(address tokenAddress) public view returns (uint256, uint256){
            uint price = tokenPriceFeed[tokenAddress];

            //if price not set by manual price feed, get from redstone

            if(price<=0){
                price = getPriceInUSDFromRedstone(tokenAddress);
            }

            uint decimal = tokenPriceFeedDec[tokenAddress];
            if(decimal<=0){
                decimal=18;
            }
            
            return (price, decimal);
        }

       function updateUserTokensBorrowedOrLent(
         address tokenAddress,
         uint256 amount,
         int256 userIndex,
         string memory lendersOrBorrowers)
         private {
           if ( keccak256(abi.encodePacked(lendersOrBorrowers)) == keccak256(abi.encodePacked("lenders"))) {
               address currentUser = lenders[uint256(userIndex)];

               if (hasLentOrBorrowedToken(currentUser, tokenAddress, noOfTokensLent,"tokensLent")) {
                   tokensLentAmount[tokenAddress][currentUser] += amount;
               } else {
                   tokensLent[noOfTokensLent++][currentUser] = tokenAddress;
                   tokensLentAmount[tokenAddress][currentUser] = amount;
               }
           } else if (keccak256(abi.encodePacked(lendersOrBorrowers)) == keccak256(abi.encodePacked("borrowers"))) {
               address currentUser = borrowers[uint256(userIndex)];

               if (hasLentOrBorrowedToken(currentUser,tokenAddress,noOfTokensBorrowed,"tokensBorrowed")) {
                   tokensBorrowedAmount[tokenAddress][currentUser] += amount;
               } else {
                   tokensBorrowed[noOfTokensBorrowed++][currentUser] = tokenAddress;
                   tokensBorrowedAmount[tokenAddress][currentUser] = amount;
               }
           }
       }

       function hasLentOrBorrowedToken(
           address currentUser,
           address tokenAddress,
           uint256 noOfTokenslentOrBorrowed,
           string memory _tokensLentOrBorrowed
       ) public view returns (bool) {
           if (noOfTokenslentOrBorrowed > 0) {
               if (keccak256(abi.encodePacked(_tokensLentOrBorrowed)) == keccak256(abi.encodePacked("tokensLent"))) {
                   for (uint256 i = 0; i < noOfTokensLent; i++) {
                       address tokenAddressFound = tokensLent[i][currentUser];
                       if (tokenAddressFound == tokenAddress) {
                           return true;
                       }
                   }
               } else if (keccak256(abi.encodePacked(_tokensLentOrBorrowed)) == keccak256(abi.encodePacked("tokensBorrowed"))) {
                   for (uint256 i = 0; i < noOfTokensBorrowed; i++) {
                       address tokenAddressFound = tokensBorrowed[i][currentUser];
                       if (tokenAddressFound == tokenAddress) {
                           return true;
                       }
                   }
               }
           }
           return false;
       }



       function getTotalTokenSupplied(address tokenAddres) public view returns (uint256){
           uint256 totalTokenSupplied = 0;
           if (lenders.length > 0) {
               for (uint256 i = 0; i < lenders.length; i++) {
                   totalTokenSupplied += tokensLentAmount[tokenAddres][lenders[i]];
               }
           }

           return totalTokenSupplied;
       }

       function getTotalTokenBorrowed(address tokenAddress) public view returns (uint256){
           uint256 totalTokenBorrowed = 0;
           if (borrowers.length > 0) {
               for (uint256 i = 0; i < borrowers.length; i++) {
                   totalTokenBorrowed += tokensBorrowedAmount[tokenAddress][borrowers[i]];
               }
           }
           return totalTokenBorrowed;
       }

}