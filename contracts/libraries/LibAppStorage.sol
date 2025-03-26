// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Define minimal structs
struct StakeInfo {
    mapping(address => uint256) erc20Balances;
    mapping(address => mapping(uint256 => bool)) erc721Stakes;
    mapping(address => mapping(uint256 => uint256)) erc1155Balances;
    mapping(address => uint256) lastStakeTime;
}

struct AppStorage {
    // Token configuration
    address rewardToken;
    uint256 rewardRate;
    uint256 lockDuration;
    
    // User stakes
    mapping(address => StakeInfo) userStakes;
    
    // Reward tracking
    mapping(address => uint256) pendingRewards;
    
    // System parameters
    address owner;
    bool paused;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}