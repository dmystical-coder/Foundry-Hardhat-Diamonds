// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./helpers/DiamondDeployer.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC721.sol";
import "./mocks/MockERC1155.sol";
import "../contracts/facets/StakingFacet.sol";

contract StakingTest is Test, DiamondDeployer {
    address diamondAddress;
    StakingFacet staking;
    
    MockERC20 mockErc20;
    MockERC721 mockErc721;
    MockERC1155 mockErc1155;
    
    address owner = address(1);
    address alice = address(2);
    address bob = address(3);
    
    uint256 erc721TokenId;
    uint256 erc1155TokenId = 1;
    uint256 erc1155Amount = 10;
    
    function setUp() public {
        // Deploy diamond
        diamondAddress = deployDiamond(owner);
        staking = StakingFacet(diamondAddress);
        
        // Deploy token mocks
        mockErc20 = new MockERC20();
        mockErc721 = new MockERC721();
        mockErc1155 = new MockERC1155();
        
        
        // Fund the diamond with reward tokens
        mockErc20.transfer(diamondAddress, 100000 * 10**18);
        
        // Setup test accounts
        vm.startPrank(owner);
        mockErc20.transfer(alice, 1000 * 10**18);
        mockErc20.transfer(bob, 1000 * 10**18);
        vm.stopPrank();
        
        // Mint NFTs to test accounts
        erc721TokenId = mockErc721.mint(alice);
        mockErc1155.mint(alice, erc1155TokenId, erc1155Amount);
    }
    
    // ERC20 Staking Tests
    function testStakeERC20() public {
        uint256 stakeAmount = 100 * 10**18;
        
        vm.startPrank(alice);
        mockErc20.approve(diamondAddress, stakeAmount);
        staking.stakeERC20(address(mockErc20), stakeAmount);
        vm.stopPrank();
        
        assertEq(staking.getERC20Stake(alice, address(mockErc20)), stakeAmount);
        assertEq(mockErc20.balanceOf(diamondAddress), 100100 * 10**18); // Initial 100k + 100 staked
    }
    
    function testWithdrawERC20() public {
        uint256 stakeAmount = 100 * 10**18;
        
        vm.startPrank(alice);
        mockErc20.approve(diamondAddress, stakeAmount);
        staking.stakeERC20(address(mockErc20), stakeAmount);
        
        // Fast forward past lock duration
        vm.warp(block.timestamp + 1 days + 1);
        
        uint256 balanceBefore = mockErc20.balanceOf(alice);
        staking.withdrawERC20(address(mockErc20), stakeAmount);
        uint256 balanceAfter = mockErc20.balanceOf(alice);
        
        assertEq(balanceAfter - balanceBefore, stakeAmount);
        assertEq(staking.getERC20Stake(alice, address(mockErc20)), 0);
        vm.stopPrank();
    }
    
    function testLockPeriodERC20() public {
        uint256 stakeAmount = 100 * 10**18;
        
        vm.startPrank(alice);
        mockErc20.approve(diamondAddress, stakeAmount);
        staking.stakeERC20(address(mockErc20), stakeAmount);
        
        // Try to withdraw before lock period ends
        vm.expectRevert("Lock period");
        staking.withdrawERC20(address(mockErc20), stakeAmount);
        vm.stopPrank();
    }
    
    // ERC721 Staking Tests
    function testStakeERC721() public {
        vm.startPrank(alice);
        mockErc721.approve(diamondAddress, erc721TokenId);
        staking.stakeERC721(address(mockErc721), erc721TokenId);
        vm.stopPrank();
        
        assertTrue(staking.getERC721Stake(alice, address(mockErc721), erc721TokenId));
        assertEq(mockErc721.ownerOf(erc721TokenId), diamondAddress);
    }
    
    function testWithdrawERC721() public {
        vm.startPrank(alice);
        mockErc721.approve(diamondAddress, erc721TokenId);
        staking.stakeERC721(address(mockErc721), erc721TokenId);
        
        // Fast forward past lock duration
        vm.warp(block.timestamp + 1 days + 1);
        
        staking.withdrawERC721(address(mockErc721), erc721TokenId);
        vm.stopPrank();
        
        assertFalse(staking.getERC721Stake(alice, address(mockErc721), erc721TokenId));
        assertEq(mockErc721.ownerOf(erc721TokenId), alice);
    }
    
    // ERC1155 Staking Tests
    function testStakeERC1155() public {
        vm.startPrank(alice);
        mockErc1155.setApprovalForAll(diamondAddress, true);
        staking.stakeERC1155(address(mockErc1155), erc1155TokenId, erc1155Amount);
        vm.stopPrank();
        
        assertEq(staking.getERC1155Stake(alice, address(mockErc1155), erc1155TokenId), erc1155Amount);
        assertEq(mockErc1155.balanceOf(diamondAddress, erc1155TokenId), erc1155Amount);
    }
    
    function testWithdrawERC1155() public {
        vm.startPrank(alice);
        mockErc1155.setApprovalForAll(diamondAddress, true);
        staking.stakeERC1155(address(mockErc1155), erc1155TokenId, erc1155Amount);
        
        // Fast forward past lock duration
        vm.warp(block.timestamp + 1 days + 1);
        
        uint256 balanceBefore = mockErc1155.balanceOf(alice, erc1155TokenId);
        staking.withdrawERC1155(address(mockErc1155), erc1155TokenId, erc1155Amount);
        uint256 balanceAfter = mockErc1155.balanceOf(alice, erc1155TokenId);
        
        assertEq(balanceAfter - balanceBefore, erc1155Amount);
        assertEq(staking.getERC1155Stake(alice, address(mockErc1155), erc1155TokenId), 0);
        vm.stopPrank();
    }
    
    // Rewards Tests
    function testRewardAccrual() public {
        uint256 stakeAmount = 100 * 10**18;
        
        vm.startPrank(alice);
        mockErc20.approve(diamondAddress, stakeAmount);
        staking.stakeERC20(address(mockErc20), stakeAmount);
        
        // Fast forward some time
        vm.warp(block.timestamp + 1 days);
        
        // Rewards should be non-zero
        uint256 rewards = staking.getPendingRewards(alice);
        assertGt(rewards, 0);
        
        vm.stopPrank();
    }
    
    function testClaimRewards() public {
        uint256 stakeAmount = 100 * 10**18;
        
        vm.startPrank(alice);
        mockErc20.approve(diamondAddress, stakeAmount);
        staking.stakeERC20(address(mockErc20), stakeAmount);
        
        // Fast forward some time
        vm.warp(block.timestamp + 2 days);
        
        uint256 balanceBefore = mockErc20.balanceOf(alice);
        staking.claimRewards();
        uint256 balanceAfter = mockErc20.balanceOf(alice);
        
        assertGt(balanceAfter, balanceBefore);
        
        // Rewards should be reset
        assertEq(staking.getPendingRewards(alice), 0);
        
        vm.stopPrank();
    }
}