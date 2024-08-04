// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../modules/SFT.sol";

struct HousingAttributes {
	uint256 rewardsPerShare;
	address originalOwner;
	uint256 tokenWeight;
}

/// @title Housing SFT
/// @notice This contract represents a semi-fungible token (SFT) for housing projects.
/// @dev This abstract contract will be inherited by the HousingProject contract.
abstract contract HousingSFT is Ownable, SFT {
	using EnumerableSet for EnumerableSet.UintSet;

	// FIXME this value should be unique to each contract, should depend on
	// the total amount expected to raise as it determines the amount of SFTs to
	// be minted for investors
	uint256 public constant MAX_SUPPLY = 1_000_000;

	/// @notice The name of this Housing Project SFT.
	string public name;

	/// @notice The amount of fungible tokens collected from investors to finance the development of this housing project.
	uint256 public amountRaised;

	/// @notice The current amount out of the `MAX_SUPPLY` of tokens minted.
	uint256 public totalSupply;

	/// @notice Mints SFT tokens for a depositor based on the amount of deposit.
	/// @param depositAmt The amount of fungible token deposited.
	/// @param depositor The address of the depositor.
	function mintSFT(
		uint256 depositAmt,
		address depositor
	) external onlyOwner returns (uint256) {
		uint256 totalDeposits = amountRaised;
		uint256 maxShares = MAX_SUPPLY;

		require(totalDeposits > 0, "HousingSFT: No deposits recorded");

		uint256 mintShare = (depositAmt * maxShares) / totalDeposits;
		require(mintShare > 0, "HousingSFT: Computed token shares is invalid");

		totalSupply += mintShare;
		require(totalSupply <= MAX_SUPPLY, "HousingSFT: Max supply exceeded");

		bytes memory attributes = abi.encode(
			HousingAttributes({
				rewardsPerShare: 0, // Should be 0 since they have never claimed any rent rewards
				originalOwner: depositor,
				tokenWeight: mintShare
			})
		);

		return _mint(depositor, mintShare, attributes, "");
	}

	/// @notice Checks if an address owns this HousingSFT and returns the attributes.
	/// @param owner The address to check the balance of.
	/// @return `HousingAttributes` if the owner has a positive balance of the token, panics otherwise.
	function getUserSFT(
		address owner,
		uint256 nonce
	) public view returns (HousingAttributes memory) {
		require(
			hasSFT(owner, nonce),
			"HouisingSFT: No tokens found for user at nonce"
		);

		return abi.decode(getRawTokenAttributes(nonce), (HousingAttributes));
	}

	function getMaxSupply() public pure returns (uint256) {
		return MAX_SUPPLY;
	}
}
