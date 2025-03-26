// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract StakingFacet {
    AppStorage internal s;

    // Events
    event Staked(
        address indexed user,
        address indexed token,
        uint256 amount,
        string tokenType
    );
    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount,
        string tokenType
    );
    event RewardClaimed(address indexed user, uint256 amount);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == s.owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!s.paused, "Contract paused");
        _;
    }

    // Owner functions
    function setRewardRate(uint256 _rate) external onlyOwner {
        s.rewardRate = _rate;
    }

    function setLockDuration(uint256 _duration) external onlyOwner {
        s.lockDuration = _duration;
    }

    function setPaused(bool _paused) external onlyOwner {
        s.paused = _paused;
    }

    // Staking functions
    function stakeERC20(
        address _token,
        uint256 _amount
    ) external whenNotPaused {
        require(_amount > 0, "Amount must be positive");

        // Update rewards
        updateRewards(msg.sender);

        // Transfer tokens
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        // Update state
        s.userStakes[msg.sender].erc20Balances[_token] += _amount;
        s.userStakes[msg.sender].lastStakeTime[_token] = block.timestamp;

        emit Staked(msg.sender, _token, _amount, "ERC20");
    }

    function stakeERC721(
        address _token,
        uint256 _tokenId
    ) external whenNotPaused {
        // Update rewards
        updateRewards(msg.sender);

        // Transfer tokens
        IERC721(_token).transferFrom(msg.sender, address(this), _tokenId);

        // Update state
        s.userStakes[msg.sender].erc721Stakes[_token][_tokenId] = true;
        s.userStakes[msg.sender].lastStakeTime[_token] = block.timestamp;

        emit Staked(msg.sender, _token, _tokenId, "ERC721");
    }

    function stakeERC1155(
        address _token,
        uint256 _tokenId,
        uint256 _amount
    ) external whenNotPaused {
        require(_amount > 0, "Amount must be positive");

        // Update rewards
        updateRewards(msg.sender);

        // Transfer tokens
        IERC1155(_token).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );

        // Update state
        s.userStakes[msg.sender].erc1155Balances[_token][_tokenId] += _amount;
        s.userStakes[msg.sender].lastStakeTime[_token] = block.timestamp;

        emit Staked(msg.sender, _token, _amount, "ERC1155");
    }

    // Withdrawal functions
    function withdrawERC20(
        address _token,
        uint256 _amount
    ) external whenNotPaused {
        require(_amount > 0, "Amount must be positive");
        require(
            s.userStakes[msg.sender].erc20Balances[_token] >= _amount,
            "Insufficient stake"
        );
        require(
            block.timestamp >=
                s.userStakes[msg.sender].lastStakeTime[_token] + s.lockDuration,
            "Lock period"
        );

        // Update rewards
        updateRewards(msg.sender);

        // Update state
        s.userStakes[msg.sender].erc20Balances[_token] -= _amount;

        // Transfer tokens
        IERC20(_token).transfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _token, _amount, "ERC20");
    }

    function withdrawERC721(
        address _token,
        uint256 _tokenId
    ) external whenNotPaused {
        require(
            s.userStakes[msg.sender].erc721Stakes[_token][_tokenId],
            "Not owner"
        );
        require(
            block.timestamp >=
                s.userStakes[msg.sender].lastStakeTime[_token] + s.lockDuration,
            "Lock period"
        );

        // Update rewards
        updateRewards(msg.sender);

        // Update state
        s.userStakes[msg.sender].erc721Stakes[_token][_tokenId] = false;

        // Transfer tokens
        IERC721(_token).transferFrom(address(this), msg.sender, _tokenId);

        emit Withdrawn(msg.sender, _token, _tokenId, "ERC721");
    }

    function withdrawERC1155(
        address _token,
        uint256 _tokenId,
        uint256 _amount
    ) external whenNotPaused {
        require(_amount > 0, "Amount must be positive");
        require(
            s.userStakes[msg.sender].erc1155Balances[_token][_tokenId] >=
                _amount,
            "Insufficient stake"
        );
        require(
            block.timestamp >=
                s.userStakes[msg.sender].lastStakeTime[_token] + s.lockDuration,
            "Lock period"
        );

        // Update rewards
        updateRewards(msg.sender);

        // Update state
        s.userStakes[msg.sender].erc1155Balances[_token][_tokenId] -= _amount;

        // Transfer tokens
        IERC1155(_token).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            ""
        );

        emit Withdrawn(msg.sender, _token, _amount, "ERC1155");
    }

    // Rewards
    function claimRewards() external whenNotPaused {
        updateRewards(msg.sender);

        uint256 rewards = s.pendingRewards[msg.sender];
        require(rewards > 0, "No rewards");

        s.pendingRewards[msg.sender] = 0;

        IERC20(s.rewardToken).transfer(msg.sender, rewards);

        emit RewardClaimed(msg.sender, rewards);
    }

    function updateRewards(address _user) internal {
        // adds a small reward based on time passed

        uint256 timeElapsed = block.timestamp -
            s.userStakes[_user].lastStakeTime[s.rewardToken];
        if (timeElapsed > 0) {
            s.pendingRewards[_user] += (timeElapsed * s.rewardRate) / 86400; // Daily rate
            s.userStakes[_user].lastStakeTime[s.rewardToken] = block.timestamp;
        }
    }

    // View functions
    function getERC20Stake(
        address _user,
        address _token
    ) external view returns (uint256) {
        return s.userStakes[_user].erc20Balances[_token];
    }

    function getERC721Stake(
        address _user,
        address _token,
        uint256 _tokenId
    ) external view returns (bool) {
        return s.userStakes[_user].erc721Stakes[_token][_tokenId];
    }

    function getERC1155Stake(
        address _user,
        address _token,
        uint256 _tokenId
    ) external view returns (uint256) {
        return s.userStakes[_user].erc1155Balances[_token][_tokenId];
    }

    function getPendingRewards(address _user) external view returns (uint256) {
        return s.pendingRewards[_user];
    }
}
