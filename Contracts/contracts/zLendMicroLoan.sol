// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IzLend} from "./zLend.sol";
import "hardhat/console.sol";

error LTVTooLow();
error LoanAlreadyFunded();
error NotaDAOMember();
error VotingPeriodEnded();
error LoanAlreadyApproved();
error VoteStillInProgress();
error LoanRequestNotApproved();
error AlreadyVoted();
error BorrowerNotAllowedToVote();

contract zLendMicroLoan is Ownable {
    using SafeERC20 for IERC20;

    struct LoanRequest {
        uint id;
        address borrower;
        IERC20 currency;
        uint256 amount;
        uint duration;
        string loanReason;
        uint256 totalDueBack;
        uint256 amountFunded;
        uint256 amountRepaid;
        uint256 creditScore;
        uint256 interestRate;

        uint256 votesFor;
        uint256 votesAgainst;
        bool isApproved;
        uint256 voteDeadline;
        bool voteApprovalTreated;

        bool isFunded;
        bool isRepaid;
        address lender;

    }

    uint public loanRequestCounter;
    mapping(uint => LoanRequest)  public loanRequests;//LoanRequest[]
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderFundedLoans;

    mapping(uint => mapping(address => bool))  public voted;//LoanRequest[]

    event LoanRequested(uint256 indexed loanId,IERC20 currency, address indexed borrower, uint256 amount,uint duration, uint256 creditScore);
    event LoanFunded(uint256 indexed loanId, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount, bool loanLiquidated);
    event Voted(uint256 requestId, address indexed voter, bool voteFor, uint votePower);
    event LoanApproved(uint256 requestId);
    event LoanRejected(uint256 requestId);

    IzLend zLend;

    uint256 public VOTE_DURATION = 10 minutes; // 3 days
    IERC20 public DAO_TOKEN;
    

    modifier onlyDAOMember() {
        require(DAO_TOKEN.balanceOf(msg.sender) > 0, NotaDAOMember());
        _;
    }

    constructor(IzLend _zLend, IERC20 daoToken) {
        zLend = _zLend;
        DAO_TOKEN=daoToken;        
        
    }



    function setVoteDuration(uint newDuration) public onlyOwner {
        VOTE_DURATION=newDuration;
    }

    

    function requestLoan(IERC20 currency, uint256 _amount , uint256 duration, string memory loanReason) external {
        // console.log('Starting request loan , %d', loanRequestCounter);
        // console.log('Pool token %s ', zLend.getPoolToken(address(currency)).tokenAddress);
        // //temporrary turn off
        // // require(zLend.usersLTV(msg.sender)>=50, LTVTooLow());

        

        // console.log('continue request loan , %d', loanRequestCounter);

        uint rate = zLend.getPoolToken(address(currency)).interestRate;

        // console.log('Starting request loan 2');

        uint interestDue = rate * _amount / 100;
        uint creditScore = zLend.usersLTV(msg.sender);
        console.log('Starting request loan 3. %d %d %d',interestDue, rate, _amount);
        loanRequests[loanRequestCounter]= LoanRequest({
            id:loanRequestCounter, 
            borrower: msg.sender,
            currency: currency,
            loanReason: loanReason,
            amount: _amount,
            amountFunded: 0,
            amountRepaid: 0,
            creditScore: creditScore,
            isFunded: false,
            isRepaid: false,
            lender: address(0),
            interestRate: rate,
            totalDueBack: interestDue + _amount,
            duration: duration,
            votesFor: 0,
            votesAgainst: 0, 
            voteApprovalTreated: false,           
            isApproved: false,
            voteDeadline: block.timestamp + VOTE_DURATION
        });
        
        
        borrowerLoans[msg.sender].push(loanRequestCounter);

        emit LoanRequested(loanRequestCounter, currency, msg.sender, _amount,duration, creditScore);

        loanRequestCounter++;
    }

    
    function fundLoan(uint256 requestId) external onlyDAOMember {
        LoanRequest storage request = loanRequests[requestId];
        require(!request.isFunded, LoanAlreadyFunded());
        // require(_amount == loan.amount, "Incorrect funding amount");
        if(!request.voteApprovalTreated){
            if(block.timestamp > request.voteDeadline){
                request.isApproved = request.votesFor > request.votesAgainst;//tie means dont fund
                if(request.isApproved){
                    emit LoanApproved(requestId);
                }else{
                    emit LoanRejected(requestId);
                }
                request.voteApprovalTreated=true;
            }else{
                revert VoteStillInProgress();
            }
        }
        

        require(request.isApproved, LoanRequestNotApproved());

        request.amountFunded = request.amount;
        request.lender = msg.sender;
        request.isFunded = true;

        lenderFundedLoans[msg.sender].push(requestId);

        // Transfer tokens from lender to this contract
        request.currency.safeTransferFrom(msg.sender, address(this), request.amount);

        emit LoanFunded(requestId, msg.sender, request.amount);
    }

    function repayLoan(uint256 _loanId, uint256 _amount) external {
        LoanRequest storage loan = loanRequests[_loanId];
        require(loan.borrower == msg.sender, "Only borrower can repay");
        require(loan.isFunded, "Loan not funded");
        require(!loan.isRepaid, "Loan already repaid");

        IERC20 token = loan.currency;
        
        
        loan.amountRepaid += _amount;

        if (loan.amountRepaid >= loan.totalDueBack) {
            loan.isRepaid = true;

            // // Transfer total amount (principal + interest) to lender
            // token.safeTransfer(loan.lender, loan.totalDueBack);
        } 
        // else {
        //     // Transfer onlrepaid portion to lender
        //     require(token.transfer(loan.lender, _amount), "Partial repayment failed");
        // }

        token.safeTransfer(loan.lender, _amount);

        emit LoanRepaid(_loanId, _amount, loan.amountRepaid >= loan.totalDueBack);
    }

    function getLoanRequests(uint start, uint size) external view returns (LoanRequest[] memory requests) {
        LoanRequest[] memory requests2 = new LoanRequest[](size);
        for (uint i = start + size - 1; i >= start ; i--) {
            if(i>loanRequestCounter || loanRequestCounter==0 ) continue;
            // console.log('getting i %d, i-start %d', i, i-start);
            //requests[i-start]=(loanRequests[i]);
            requests2[start + size - 1 - i]= (loanRequests[i]);
            // console.log('DONE getting i %d, i-start %d', i, i-start);
            if(i==0) break;
        }
        return requests2;

        


        
    }

    function getBorrowerLoans(address _borrower) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderLoans(address _lender) external view returns (uint256[] memory) {
        return lenderFundedLoans[_lender];
    }

    function getVotingPower(address voter) public view returns (uint256){
        return DAO_TOKEN.balanceOf(voter)/ (10 ** 18);
    }

    
    
    function voteOnLoanRequest(uint256 requestId, bool voteFor) external onlyDAOMember {
        LoanRequest storage request = loanRequests[requestId];
        require(block.timestamp <= request.voteDeadline, VotingPeriodEnded());
        require(!request.isApproved, LoanAlreadyApproved());
        require(!voted[requestId][msg.sender], AlreadyVoted());

        require(request.borrower!= msg.sender, BorrowerNotAllowedToVote());

        uint votePower = getVotingPower(msg.sender);
        if (voteFor) {
            request.votesFor += votePower;
        } else {
            request.votesAgainst += votePower;
        }

        voted[requestId][msg.sender]=true;

        emit Voted(requestId, msg.sender, voteFor, votePower);
    }
}
