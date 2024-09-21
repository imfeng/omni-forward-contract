// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OmniForwardMarketBase is ERC20 {
    using SafeERC20 for IERC20;

    uint32 constant FLOAT_FACTOR = 1e6;
    uint32 constant YEAR = 365 days;
    struct BorrowOrder {
        uint256 chainId;
        address marketAddress;
        address user;
        address borrowTokenAddress;
        uint256 borrowAmount;
        uint256 interestRateRaw;
        address collateralTokenAddress;
        uint256 collateralTokenAmount;
        uint32 maturityTime;
        uint32 expiredTime;
        uint32 nonce;
        uint32 epoch;
    }

    struct LendOrder {
        uint256 chainId;
        address marketAddress;
        address user;
        address lendTokenAddress;
        uint256 lendAmount;
        uint256 interestRateRaw;
        uint32 maturityTime;
        uint32 expiredTime;
        uint32 nonce;
        uint32 epoch;
    }

    struct Loan {
        uint256 lenderChainId;
        address borrower;
        uint256 borrowAmount;
        uint256 lendAmount;
        uint256 debtAmount;
    }

    // struct OmniDataFromLender {
    //     bool isReceiveLend;
    // }
    // mapping(bytes32 => OmniDataFromLender) public usedNonce;


    event LoanUpdated(address indexed borrower, uint256 lenderChainId, uint256 borrowAmt, uint256 lendAmt, uint256 debtAmt, uint256 interestRate);

    uint8 internal _decimals;
    address public underlying;
    address public collateral;
    uint32 public maturityTime;
    address public priceFeedOracle;
    uint256 public LTV;
    mapping(address => Loan) public loanInfo;

    constructor(
        string memory _name,
        string memory _symbol,
        address _underlying,
        address _collateral,
        uint32 _maturityTime
    ) ERC20(_name, _symbol) {
        underlying = _underlying;
        collateral = _collateral;
        _decimals = ERC20(_collateral).decimals();
        maturityTime = _maturityTime;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // function _getLoanInfo(address borrower) internal view returns (Loan memory) {
    //     return loanInfo[borrower];
    // }

    // function _getLoanHealth(address borrower) internal view returns (uint256) {
    //     Loan memory loan = _getLoanInfo(borrower);
    //     return loan.debtAmount / loan.lendAmount;
    // }

    function _borrowerUpdateLoan(address borrower, uint256 lenderChainId, uint256 borrowAmt, uint256 lendAmt, uint256 debtAmt, uint256 interestRateRaw) internal {
      uint256 prevBorrowAmt = loanInfo[borrower].borrowAmount;
      uint256 prevLendAmt = loanInfo[borrower].lendAmount;
      uint256 prevDebtAmt = loanInfo[borrower].debtAmount;

      loanInfo[borrower].borrowAmount = prevBorrowAmt + borrowAmt;
      loanInfo[borrower].lendAmount = prevLendAmt + lendAmt;
      loanInfo[borrower].debtAmount = prevDebtAmt + debtAmt;

      IERC20(collateral).safeTransferFrom(borrower, address(this), borrowAmt);
      IERC20(underlying).safeTransfer(borrower, lendAmt);
      emit LoanUpdated(borrower, lenderChainId, borrowAmt, lendAmt, debtAmt, interestRateRaw);
    }

    function _lenderMint(address lender, uint256 interestRateRaw, uint256 underlyingAmt) internal {
        uint256 interest = _calculateInterest(interestRateRaw, underlyingAmt, block.timestamp);
        _mint(lender, underlyingAmt + interest);
        IERC20(underlying).safeTransferFrom(lender, address(this), underlyingAmt);
    }

    function _calculateInterest(uint256 interestRateRaw, uint256 amount, uint256 timestamp) internal view returns (uint256) {
      uint256 _days = _daysToMaturity(timestamp);
      uint256 interest = amount * interestRateRaw * _days / YEAR / FLOAT_FACTOR;
      return interest;
    }

    function _daysToMaturity(uint256 timestamp) internal view returns (uint256) {
        if (timestamp > maturityTime) {
            return 0;
        }
        return (maturityTime - timestamp) / 1 days + 1;
    }

}