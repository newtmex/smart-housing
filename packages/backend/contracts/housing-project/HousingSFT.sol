// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct HousingAttributes {
	uint256 rewardsPerShare;
	address originalOwner;
	uint256 tokenWeight;
}

/// @title Housing SFT
/// @notice This contract represents a semi-fungible token (SFT) for housing projects.
/// @dev This abstract contract will be inherited by the HousingProject contract.
abstract contract HousingSFT is ERC1155, Ownable {
	uint256 public constant HOUSING_PROJECT = 1;
	// FIXME this value should be unique to each contract, should depend on
	// the total amount expected to raise as it determines the amount of SFTs to
	// be minted for investors
	uint256 public constant MAX_SUPPLY = 1_000_000;

	/// @notice The name of this Housing Project SFT.
	string public name;

	/// @notice The amount of fungible tokens collected from investors to finance the development of this housing project.
	uint256 public immutable amountRaised;

	/// @notice The current amount out of the `MAX_SUPPLY` of tokens minted.
	uint256 public totalSupply;

	/// @notice Mapping from address to housing attributes.
	mapping(address => HousingAttributes) public housingAttributes;

	/// @notice Initializes the HousingSFT contract.
	/// @param uri The base URI for the token.
	/// @param name_ The name of the housing project.
	/// @param amountRaised_ The amount raised from investors for the housing project.
	constructor(
		string memory uri,
		string memory name_,
		uint256 amountRaised_
	) ERC1155(uri) {
		name = name_;
		amountRaised = amountRaised_;
	}

	/// @notice Mints SFT tokens for a depositor based on the amount of deposit.
	/// @param depositAmt The amount of fungible token deposited.
	/// @param depositor The address of the depositor.
	function mintSFT(uint256 depositAmt, address depositor) external onlyOwner {
		uint256 totalDeposits = amountRaised;
		uint256 maxShares = MAX_SUPPLY;

		require(totalDeposits > 0, "HousingSFT: No deposits recorded");

		uint256 mintShare = (depositAmt * maxShares) / totalDeposits;
		require(mintShare > 0, "HousingSFT: Computed token shares is invalid");

		totalSupply += mintShare;
		require(totalSupply <= MAX_SUPPLY, "HousingSFT: Max supply exceeded");

		_mint(depositor, HOUSING_PROJECT, mintShare, bytes(name));
		housingAttributes[depositor] = HousingAttributes({
			rewardsPerShare: 0, // Should be 0 since they have never claimed any rent rewards
			originalOwner: depositor,
			tokenWeight: mintShare
		});
	}

	/// @notice Checks if an address owns this HousingSFT and returns the attributes.
	/// @param owner The address to check the balance of.
	/// @return `HousingAttributes` if the owner has a positive balance of the token, panics otherwise.
	function getUserSFT(
		address owner
	) public view returns (HousingAttributes memory) {
		uint256 balance = balanceOf(owner, HOUSING_PROJECT);
		require(balance > 0, "HouisingSFT: No tokens found for user");

		return housingAttributes[owner];
	}
}
