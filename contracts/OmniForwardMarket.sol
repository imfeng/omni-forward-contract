// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OmniForwardMarket is ERC20 {
  using SafeERC20 for IERC20;

  uint32 constant INTEREST_RATE_FACTOR = 1e6;

  uint8 internal _decimals;
  address public underlying;
  address public collateral;
  uint32 public maturityTime;

  uint256 internal chainId;

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
    uint256 interestRateRaw;
    uint32 matchedTime;
    uint32 maturityTime;
    uint32 expiredTime;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    address _underlying,
    address _collateral
  ) ERC20(_name, _symbol) {
    underlying = _underlying;
    collateral = _collateral;
    _decimals = IERC20(_collateral).decimals();
    chainId = getChainID();
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function getChainID() private view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }

  // @notice lendOrder as maker, borrowOrder as taker
  function omniMatchTakerBorrowOrder(LendOrder memory lendOrder, BorrowOrder memory borrowOrder) external {
    require(lendOrder.chainId == chainId, "Chain ID mismatch");
    if (borrowOrder.chainId == chainId) {
      _localMatchTakerBorrowOrder(lendOrder, borrowOrder);
    } else {
      _crossMatchTakerBorrowOrder(lendOrder, borrowOrder);
    }
  }

  function _localMatchTakerBorrowOrder(LendOrder memory lendOrder, BorrowOrder memory borrowOrder) private {}

  function _crossMatchTakerBorrowOrder(LendOrder memory lendOrder, BorrowOrder memory borrowOrder) private {
    require(lendOrder.chainId == chainId, "Chain ID mismatch");
    require(borrowOrder.chainId != chainId, "Chain ID mismatch");
  }

  function _receiveCrossBorrowOrder(LendOrder memory lendOrder) private {
    require(lendOrder.chainId == chainId, "Chain ID mismatch");
  }

  // @notice lendOrder as maker, borrowOrder as taker
  function omniMatchTakerLendOrder(LendOrder memory lendOrder, BorrowOrder memory borrowOrder) external {
    require(borrowOrder.chainId == chainId, "Chain ID mismatch");
    if (lendOrder.chainId == chainId) {
      _localMatchTakerLendOrder(lendOrder, borrowOrder);
    } else {
      _crossMatchTakerLendOrder(lendOrder, borrowOrder);
    }
  }

  function _localMatchTakerLendOrder(LendOrder memory lendOrder, BorrowOrder memory borrowOrder) private {}

  function _crossMatchTakerLendOrder(LendOrder memory lendOrder, BorrowOrder memory borrowOrder) private {}

  //
}
