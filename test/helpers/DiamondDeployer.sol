// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/Diamond.sol";
import "../../contracts/facets/StakingFacet.sol";
import "../../contracts/facets/DiamondCutFacet.sol";
import "../../contracts/facets/OwnershipFacet.sol";
import "../../contracts/upgradeInitializers/DiamondInit.sol";
import "../../contracts/interfaces/IDiamondCut.sol";

contract DiamondDeployer is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    OwnershipFacet ownershipFacet;
    StakingFacet stakingFacet;
    DiamondInit diamondInit;

    // For facet selectors
    function getSelectors(
        address _facetAddress
    ) internal view returns (bytes4[] memory) {
        (bool success, bytes memory data) = _facetAddress.staticcall(
            abi.encodeWithSignature("getSelectors()")
        );
        require(success, "DiamondDeployer: Failed to get selectors");
        return abi.decode(data, (bytes4[]));
    }

    function deployDiamond(address owner) internal returns (address) {
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        ownershipFacet = new OwnershipFacet();
        stakingFacet = new StakingFacet();

        // Deploy Diamond
        diamond = new Diamond(owner, address(diamondCutFacet));

        // Deploy DiamondInit
        diamondInit = new DiamondInit();

        // Get function selectors for each facet
        bytes4[] memory diamondCutSelectors = new bytes4[](1);
        diamondCutSelectors[0] = diamondCutFacet.diamondCut.selector;

        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = ownershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = ownershipFacet.owner.selector;

        // Simplifying for brevity - would need to list all StakingFacet selectors
        bytes4[] memory stakingSelectors = new bytes4[](14);
        stakingSelectors[0] = stakingFacet.stakeERC20.selector;
        stakingSelectors[1] = stakingFacet.stakeERC721.selector;
        stakingSelectors[2] = stakingFacet.stakeERC1155.selector;
        stakingSelectors[3] = stakingFacet.withdrawERC20.selector;
        stakingSelectors[4] = stakingFacet.withdrawERC721.selector;
        stakingSelectors[5] = stakingFacet.withdrawERC1155.selector;
        stakingSelectors[6] = stakingFacet.claimRewards.selector;
        stakingSelectors[7] = stakingFacet.getERC20Stake.selector;
        stakingSelectors[8] = stakingFacet.getERC721Stake.selector;
        stakingSelectors[9] = stakingFacet.getERC1155Stake.selector;
        stakingSelectors[10] = stakingFacet.getPendingRewards.selector;
        stakingSelectors[11] = stakingFacet.setRewardRate.selector;
        stakingSelectors[12] = stakingFacet.setLockDuration.selector;
        stakingSelectors[13] = stakingFacet.setPaused.selector;

        // Create facet cut array
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: diamondCutSelectors
        });

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(stakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stakingSelectors
        });

        // Initialize diamond
        bytes memory initCalldata = abi.encodeWithSelector(
            diamondInit.init.selector,
            owner,
            address(0) // Will set rewardToken later
        );

        // Make diamondCut call
        IDiamondCut(address(diamond)).diamondCut(
            cuts,
            address(diamondInit),
            initCalldata
        );

        return address(diamond);
    }
}
