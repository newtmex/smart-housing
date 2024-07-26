// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract HousingSFT is ERC1155, Ownable {
	uint256 public constant HOUSING_PROJECT = 1;
	// FIXME Should this be variable? Based on the needs of the project?
	uint256 public constant MAX_SUPPLY = 1_000_000;
	// The name of this Housing Project SFT.
	// Must be immutable
	string public name;

	struct HousingAttributes {
		uint256 rewardsPerShare;
		address originalOwner;
		uint256 tokenWeight;
	}

	// This is the amount of fungible tokens collected from
	// investors to finance the depvelopment of this housing project
	uint256 public immutable amountRaised;
	// The current amount out of the `MAX_SUPPLY` of tokens minted
	uint256 public totalSupply;
	mapping(uint256 => HousingAttributes) public housingAttributes;

	constructor(
		string memory uri,
		string memory name_,
		uint256 amountRaised_
	) ERC1155(uri) {
		name = name_;
		amountRaised = amountRaised_;

		_mint(msg.sender, HOUSING_PROJECT, 1000000, "");
		housingAttributes[HOUSING_PROJECT] = HousingAttributes({
			rewardsPerShare: 0,
			originalOwner: msg.sender,
			tokenWeight: 0
		});
	}

	/// This is called only by the deployer of this contract (This will be the projects funding contract)
	///
	/// Mints SFT tokens for `depositor` base on the amount of `depositAmt`
	/// @param depositAmt the amount of fungible token deposited
	/// @param depositor the address of the depositor
	function mintSFT(uint256 depositAmt, address depositor) external onlyOwner {
		uint256 totalDeposits = amountRaised;
		uint256 maxShares = MAX_SUPPLY;

		require(totalDeposits > 0, "HousingSFT: No deposits recorded");

		uint256 mintShare = (depositAmt * maxShares) / totalDeposits;
		require(mintShare > 0, "HousingSFT: Computed token shares is invalid");

		totalSupply += mintShare;
		require(totalSupply <= MAX_SUPPLY, "HousingSFT: Max supply exceeded");

		// Send depositor the token
		_mint(depositor, HOUSING_PROJECT, mintShare, bytes(name));
		housingAttributes[HOUSING_PROJECT] = HousingAttributes({
			rewardsPerShare: 0,
			originalOwner: depositor,
			tokenWeight: mintShare
		});
	}
}
