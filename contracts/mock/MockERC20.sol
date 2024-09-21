pragma solidity ^0.8.20;
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
  uint8 internal decimals_ = 8;

  constructor(string memory name_, string memory symbol_, uint8 decimals__) ERC20(name_, symbol_) Ownable(msg.sender) {
    decimals_ = decimals__;
  }

  function decimals() public view override returns (uint8) {
    return decimals_;
  }

  function mint(address receiver, uint mintAmount) external returns (uint) {
    require(msg.sender == owner(), "MockERC20: only vToken or owner can mint");
    _mint(receiver, mintAmount);
    return mintAmount;
  }
}
