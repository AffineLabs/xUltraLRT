// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import {IXERC20} from "../interfaces/IXERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IXERC20Lockbox {
    /**
     * @notice Emitted when tokens are deposited into the lockbox
     *
     * @param _sender The address of the user who deposited
     * @param _amount The amount of tokens deposited
     */
    event Deposit(address _sender, uint256 _amount);

    /**
     * @notice Emitted when tokens are withdrawn from the lockbox
     *
     * @param _sender The address of the user who withdrew
     * @param _amount The amount of tokens withdrawn
     */
    event Withdraw(address _sender, uint256 _amount);

    /**
     * @notice Reverts when a user tries to deposit native tokens on a non-native lockbox
     */
    error IXERC20Lockbox_NotNative();

    /**
     * @notice Reverts when a user tries to deposit non-native tokens on a native lockbox
     */
    error IXERC20Lockbox_Native();

    /**
     * @notice Reverts when a user tries to withdraw and the call fails
     */
    error IXERC20Lockbox_WithdrawFailed();

    /**
     * @notice Reverts when a user tries to call redeemByXERC20 on a non-XERC20 contract
     */
    error IXERC20Lockbox_NotXERC20();

    /**
     * @notice Reverts when a user tries to call redeemByXERC20 on non-XERC20 contract with non-matching lockbox contract
     */
    error IXERC20Lockbox_NotLockbox();

    /**
     * @notice Deposit ERC20 tokens into the lockbox
     *
     * @param _amount The amount of tokens to deposit
     */
    function deposit(uint256 _amount) external;

    /**
     * @notice Deposit ERC20 tokens into the lockbox, and send the XERC20 to a user
     *
     * @param _user The user to send the XERC20 to
     * @param _amount The amount of tokens to deposit
     */
    function depositTo(address _user, uint256 _amount) external;

    /**
     * @notice Deposit the native asset into the lockbox, and send the XERC20 to a user
     *
     * @param _user The user to send the XERC20 to
     */
    function depositNativeTo(address _user) external payable;

    /**
     * @notice Withdraw ERC20 tokens from the lockbox
     *
     * @param _amount The amount of tokens to withdraw
     */
    function withdraw(uint256 _amount) external;

    /**
     * @notice Withdraw ERC20 tokens from the lockbox
     *
     * @param _user The user to withdraw to
     * @param _amount The amount of tokens to withdraw
     */
    function withdrawTo(address _user, uint256 _amount) external;

    /**
     * @notice Redeem ERC20 tokens by the XERC20 contract
     *
     * @param _to The address to send the tokens to
     * @param _amount The amount of tokens to redeem
     */
    function redeemByXERC20(address _to, uint256 _amount) external;

    function ERC20() external view returns (IERC20);
    function XERC20() external view returns (IXERC20);
}
