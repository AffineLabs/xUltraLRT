// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

library XErrors {
    error NotGuardian();
    error NotHarvester();
    error InvalidMsgOrigin();
    error NotUpdatedPrice();
    error InvalidAmount();
    error InvalidReceiver();
    error InvalidSharePrice();
    error InvalidBaseAsset();
    error InvalidDestinationRouter();
    error InvalidPriceFeed();
    error InvalidMsgRecipient();
    error InvalidBridgeRecipient();
    error InvalidBridgeRecipientToken();
    error InvalidBridgeFeeAmount();
    error ExceedsMaxBridgeFee();
    error InvalidBridgePoolAddr();
    error InsufficientBalance();
    error InvalidLockBoxAddr();
    error InvalidPriceFeedAsset();
    error InvalidLRTAsset();
    error InvalidFeeBps();
    error NotMailbox();
    error TokenDepositNotAllowed();
    error InvalidTransferLimit();
    error NotHarvesterOrLockbox();
    error InvalidRouterAddr();
    error InvalidArrayLength();
    error DifferentOwner();
}
