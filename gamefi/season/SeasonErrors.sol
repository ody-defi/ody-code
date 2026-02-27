// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library SeasonErrors {
    error Unauthorized();
    error InvalidAddress();
    error InvalidId();
    error InvalidState();
    error InvalidAmount();
    error AlreadyExists();
    error NotFound();
    error Expired();
}
