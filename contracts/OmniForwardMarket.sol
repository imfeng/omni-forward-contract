// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { OAppOptionsType3 } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3.sol";
import { IOAppMsgInspector } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";

import { ITokenMessenger } from "./lib/circle-cctp/ITokenMessenger.sol";
import { OmniForwardMarketBase } from "./core/OmniForwardMarketBase.sol";
contract OmniForwardMarket is OmniForwardMarketBase, Ownable, OApp, OAppOptionsType3 {
    using SafeERC20 for IERC20;

    uint256 internal chainId;

    ITokenMessenger public cctpMessenger;

    constructor(
        string memory _name,
        string memory _symbol,
        address _underlying,
        address _collateral,
        uint32 _maturityTime,
        address _cctpMessenger,
        address _lzEndpoint
    ) 
    OmniForwardMarketBase(_name, _symbol, _underlying, _collateral, _maturityTime)
    Ownable(msg.sender) OApp(_lzEndpoint, msg.sender) {
        cctpMessenger = ITokenMessenger(_cctpMessenger);
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

    /** LayerZero */
    /**
     * @notice Sends a message from the source to destination chain.
     * @param _dstEid Destination chain's endpoint ID.
     * @param _message The message to send.
     * @param _options Message execution options (e.g., for sending gas to destination).
     */
    function send(
        uint32 _dstEid,
        string memory _message,
        bytes calldata _options
    ) external payable {
        // Encodes the message before invoking _lzSend.
        // Replace with whatever data you want to send!
        bytes memory _payload = abi.encode(_message);
        _lzSend(
            _dstEid,
            _payload,
            _options,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            msg.sender
        );
    }

    // function peers(uint32 _eid) external view override returns (bytes32 peer) {}

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {}

    /** CCTP */


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
