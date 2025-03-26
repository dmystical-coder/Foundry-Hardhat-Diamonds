// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";

contract DiamondInit {
    AppStorage internal s;

    function init(address _owner, address _rewardToken) external {
        s.owner = _owner;
        s.rewardToken = _rewardToken;
        s.rewardRate = 1e18; // 1 token per day
        s.lockDuration = 1 days;
    }
}