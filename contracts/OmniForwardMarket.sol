// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

import {AggregatorV3Interface} from "./lib/AggregatorV3Interface.sol";
import { ITokenMessenger } from "./lib/circle-cctp/ITokenMessenger.sol";
import { OmniForwardMarketBase } from "./core/OmniForwardMarketBase.sol";
contract OmniForwardMarket is OmniForwardMarketBase, Ownable, CCIPReceiver {
    using SafeERC20 for IERC20;

    uint256 internal chainId;

    ITokenMessenger public cctpMessenger;

    constructor(
        string memory _name,
        string memory _symbol,
        address _underlying,
        address _collateral,
        uint32 _maturityTime,
        address _router
    ) 
    OmniForwardMarketBase(_name, _symbol, _underlying, _collateral, _maturityTime)
    Ownable(msg.sender)
    CCIPReceiver(_router)
    {
        // cctpMessenger = ITokenMessenger(_cctpMessenger);
        chainId = _getChainID();
    }

    /** general */
    function _getChainID() private view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /** Chainlink CCIP */
    // Custom errors to provide more descriptive revert messages.
    error NoMessageReceived(); // Used when trying to access a message but no messages have been received.
    error IndexOutOfBound(uint256 providedIndex, uint256 maxIndex); // Used when the provided index is out of bounds.
    error MessageIdNotExist(bytes32 messageId); // Used when the provided message ID does not exist.
    error NotEnoughBalance(uint256, uint256);
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, uint256 value); // Used when the withdrawal of Ether fails.

  // Event emitted when a message is sent to another chain.
  event MessageSent(
    bytes32 indexed messageId, // The unique ID of the message.
    uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
    address receiver, // The address of the receiver on the destination chain.
    address borrower, // The borrower's EOA - would map to a depositor on the source chain.
    Client.EVMTokenAmount tokenAmount, // The token amount that was sent.
    uint256 fees // The fees paid for sending the message.
  );

  // Event emitted when a message is received from another chain.
  event MessageReceived(
    bytes32 indexed messageId, // The unique ID of the message.
    uint64 indexed sourceChainSelector, // The chain selector of the source chain.
    address sender, // The address of the sender from the source chain.
    address depositor, // The EOA of the depositor on the source chain
    Client.EVMTokenAmount tokenAmount // The token amount that was received.
  );

  // Struct to hold details of a message.
  struct MessageIn {
    uint64 sourceChainSelector; // The chain selector of the source chain.
    address sender; // The address of the sender.
    address depositor; // The content of the message.
    address token; // received token.
    uint256 amount; // received amount.
  }
  /// handle a received message
  function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
    bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
    uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)
    address sender = abi.decode(any2EvmMessage.sender, (address)); // abi-decoding of the sender address
    address depositor = abi.decode(any2EvmMessage.data, (address)); // abi-decoding of the depositor's address

    // Collect tokens transferred. This increases this contract's balance for that Token.
    Client.EVMTokenAmount[] memory tokenAmounts = any2EvmMessage.destTokenAmounts;
    address token = tokenAmounts[0].token;
    uint256 amount = tokenAmounts[0].amount;

    receivedMessages.push(messageId);
    MessageIn memory detail = MessageIn(sourceChainSelector, sender, depositor, token, amount);
    messageDetail[messageId] = detail;

    emit MessageReceived(messageId, sourceChainSelector, sender, depositor, tokenAmounts[0]);

    // Store depositor data.
    deposits[depositor][token] += amount;
  }

  function borrowUSDC(bytes32 msgId) public returns (uint256) {
    uint256 borrowed = borrowings[msg.sender][address(underlying)];
    require(borrowed == 0, "Caller has already borrowed USDC");

    address transferredToken = messageDetail[msgId].token;
    require(transferredToken != address(0), "Caller has not transferred this token");

    uint256 deposited = deposits[msg.sender][transferredToken];
    uint256 borrowable = (deposited * 70) / 100; // 70% collaterization ratio.

    AggregatorV3Interface priceFeed = AggregatorV3Interface(0xc0F82A46033b8BdBA4Bb0B0e28Bc2006F64355bC);

    (, int256 price, , , ) = priceFeed.latestRoundData();
    uint256 price18decimals = uint256(price * (10 ** 10)); // make USD price 18 decimal places from 8 decimal places.

    uint256 borrowableInUSDC = borrowable * price18decimals;

    // Update state.
    borrowings[msg.sender][address(underlying)] = borrowableInUSDC;

    assert(borrowings[msg.sender][address(underlying)] == borrowableInUSDC);
    return borrowableInUSDC;
  }

  function repayAndSendMessage(uint256 amount, uint64 destinationChain, address receiver, bytes32 msgId) public {
    require(amount >= borrowings[msg.sender][address(underlying)], "Repayment amount is less than amount borrowed");

    // Get the deposit details, so it can be transferred back.
    address transferredToken = messageDetail[msgId].token;
    uint256 deposited = deposits[msg.sender][transferredToken];

    IERC20 underlying = IERC20(this.underlying());
    uint256 mockUSDCBal = underlying.balanceOf(msg.sender);
    require(mockUSDCBal >= amount, "Caller's USDC token balance insufficient for repayment");

    if (underlying.allowance(msg.sender, address(this)) < borrowings[msg.sender][address(underlying)]) {
      revert("Protocol allowance is less than amount borrowed");
    }


    borrowings[msg.sender][address(underlying)] = 0;
    // send transferred token and message back to Sepolia Sender contract
    sendMessage(destinationChain, receiver, transferredToken, deposited);
  }

  function sendMessage(
    uint64 destinationChainSelector,
    address receiver,
    address tokenToTransfer,
    uint256 transferAmount
  ) internal returns (bytes32 messageId) {
    address borrower = msg.sender;

    // Compose the EVMTokenAmountStruct. This struct describes the tokens being transferred using CCIP.
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: tokenToTransfer, amount: transferAmount});
    tokenAmounts[0] = tokenAmount;

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(receiver), // ABI-encoded receiver address
      data: abi.encode(borrower), // ABI-encoded string message
      tokenAmounts: tokenAmounts,
      extraArgs: Client._argsToBytes(
        Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false}) // Additional arguments, setting gas limit and non-strict sequency mode
      ),
      feeToken: address(linkToken) // Setting feeToken to LinkToken address, indicating LINK will be used for fees
    });

    // Initialize a router client instance to interact with cross-chain
    IRouterClient router = IRouterClient(this.getRouter());

    // Get the fee required to send the message
    uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);

    // approve the Router to send LINK tokens on contract's behalf. I will spend the fees in LINK
    linkToken.approve(address(router), fees);

    require(IERC20(tokenToTransfer).approve(address(router), transferAmount), "Failed to approve router");

    // Send the message through the router and store the returned message ID
    messageId = router.ccipSend(destinationChainSelector, evm2AnyMessage);

    // Emit an event with message details
    emit MessageSent(messageId, destinationChainSelector, receiver, borrower, tokenAmount, fees);

    deposits[borrower][tokenToTransfer] -= transferAmount;

    // Return the message ID
    return messageId;
  }

  function getNumberOfReceivedMessages() external view returns (uint256 number) {
    return receivedMessages.length;
  }

  function getReceivedMessageDetails(
    bytes32 messageId
  ) external view returns (uint64, address, address, address token, uint256 amount) {
    MessageIn memory detail = messageDetail[messageId];
    if (detail.sender == address(0)) revert MessageIdNotExist(messageId);
    return (detail.sourceChainSelector, detail.sender, detail.depositor, detail.token, detail.amount);
  }

  function getLastReceivedMessageDetails()
    external
    view
    returns (bytes32 messageId, uint64, address, address, address, uint256)
  {
    // Revert if no messages have been received
    if (receivedMessages.length == 0) revert NoMessageReceived();

    // Fetch the last received message ID
    messageId = receivedMessages[receivedMessages.length - 1];

    // Fetch the details of the last received message
    MessageIn memory detail = messageDetail[messageId];

    return (messageId, detail.sourceChainSelector, detail.sender, detail.depositor, detail.token, detail.amount);
  }

  function isChainSupported(uint64 destChainSelector) external view returns (bool supported) {
    return IRouterClient(this.getRouter()).isChainSupported(destChainSelector);
  }

  /// @notice Fallback function to allow the contract to receive Ether.
  /// @dev This function has no function body, making it a default function for receiving Ether.
  /// It is automatically called when Ether is sent to the contract without any data.
  receive() external payable {}


  // Storage variables.
  bytes32[] public receivedMessages; // Array to keep track of the IDs of received messages.
  mapping(bytes32 => MessageIn) public messageDetail; // Mapping from message ID to MessageIn struct, storing details of each received message.
  mapping(address => mapping(address => uint256)) public deposits; // Depsitor Address => Deposited Token Address ==> amount
  mapping(address => mapping(address => uint256)) public borrowings; // Depsitor Address => Borrowed Token Address ==> amount
    LinkTokenInterface linkToken;



    /** Bond Market */
    
    // @notice lendOrder as maker, borrowOrder as taker
    function omniMatchTakerBorrowOrder(
        LendOrder memory lendOrder,
        BorrowOrder memory borrowOrder
    ) external {
        require(lendOrder.chainId == chainId, 'Chain ID mismatch');
        if (borrowOrder.chainId == chainId) {
            _localMatchTakeBorrowOrder(lendOrder, borrowOrder);
        } else {
            _omniMatchTakeBorrowOrder(lendOrder, borrowOrder);
        }
    }

    function _localMatchTakeBorrowOrder(
        LendOrder memory lendOrder,
        BorrowOrder memory borrowOrder
    ) private {
      _lenderMint(lendOrder.user, lendOrder.interestRateRaw, lendOrder.lendAmount);
      _borrowerUpdateLoan(borrowOrder.user, _getChainID(), borrowOrder.borrowAmount, 0, 0, lendOrder.interestRateRaw);
    }

    
    function _omniMatchTakeBorrowOrder(
        LendOrder memory lendOrder,
        BorrowOrder memory borrowOrder
    ) private {
        require(lendOrder.chainId == chainId, 'Chain ID mismatch');
        require(borrowOrder.chainId != chainId,
         'Chain ID mismatch');

        bytes32 omniTx = keccak256(abi.encode(lendOrder, borrowOrder));
        
    }

    function _receiveCrossBorrowOrder(LendOrder memory lendOrder) private {
        require(lendOrder.chainId == chainId, 'Chain ID mismatch');
    }

    // @notice lendOrder as maker, borrowOrder as taker
    function omniMatchTakerLendOrder(
        LendOrder memory lendOrder,
        BorrowOrder memory borrowOrder
    ) external {
        require(borrowOrder.chainId == chainId, 'Chain ID mismatch');
        if (lendOrder.chainId == chainId) {
            _localMatchTakerLendOrder(lendOrder, borrowOrder);
        } else {
            _crossMatchTakerLendOrder(lendOrder, borrowOrder);
        }
    }

    function _localMatchTakerLendOrder(
        LendOrder memory lendOrder,
        BorrowOrder memory borrowOrder
    ) private {}

    function _crossMatchTakerLendOrder(
        LendOrder memory lendOrder,
        BorrowOrder memory borrowOrder
    ) private {}
}
