// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../modules/SFT.sol";

struct HousingAttributes {
	uint256 rewardsPerShare;
	address originalOwner;
	uint256 tokenWeight;
}

/// @title Housing SFT
/// @notice This contract represents a semi-fungible token (SFT) for housing projects.
/// @dev This contract will be inherited by the HousingProject contract.
contract HousingSFT is SFT {
	using EnumerableSet for EnumerableSet.UintSet;
	using Address for address;

	struct HousingSFTBalance {
		uint256 nonce;
		uint256 amount;
		HousingAttributes attributes;
	}

	/// @notice Maximum supply of tokens for this housing project.
	uint256 public constant MAX_SUPPLY = 1_000_000;

	/// @notice The amount of fungible tokens collected from investors to finance the development of this housing project.
	uint256 public amountRaised;

	/// @notice The current amount out of the `MAX_SUPPLY` of tokens minted.
	uint256 public totalSupply;

	/// @param name_ Name of the SFT.
	/// @param symbol_ Symbol of the SFT.
	constructor(
		string memory name_,
		string memory symbol_
	) SFT(name_, symbol_) {}

	/// @notice Sets the amount raised for the housing project.
	/// @param amountRaised_ The amount raised during the token sale.
	function setAmountRaised(uint256 amountRaised_) external canMint {
		amountRaised = amountRaised_;
	}

	/// @dev Modifier to ensure only the SFT owner (i.e., the owner of the owner of this contract, which is the ProjectFunding Contract) can mint new tokens.
	modifier canMint() {
		address sftOwner = owner();

		require(
			Ownable(sftOwner).owner() == _msgSender(),
			"not allowed to mint"
		);

		_;
	}

	/// @notice Mints SFT tokens for a depositor based on the amount of deposit.
	/// @param depositAmt The amount of fungible token deposited.
	/// @param depositor The address of the depositor.
	/// @return The ID of the newly minted SFT.
	function mintSFT(
		uint256 depositAmt,
		address depositor
	) external canMint returns (uint256) {
		uint256 maxShares = MAX_SUPPLY;
		require(amountRaised > 0, "HousingSFT: No deposits recorded");

		uint256 mintShare = (depositAmt * maxShares) / amountRaised;
		require(mintShare > 0, "HousingSFT: Computed token shares invalid");

		totalSupply += mintShare;
		require(totalSupply <= MAX_SUPPLY, "HousingSFT: Max supply exceeded");

		bytes memory attributes = abi.encode(
			HousingAttributes({
				rewardsPerShare: 0, // Initial rewards per share
				originalOwner: depositor,
				tokenWeight: mintShare
			})
		);

		return _mint(depositor, mintShare, attributes);
	}

	/// @notice Retrieves the SFT attributes for a given owner and nonce.
	/// @param owner The address to check the balance of.
	/// @param nonce The specific nonce to check.
	/// @return The attributes associated with the specified SFT.
	function getUserSFT(
		address owner,
		uint256 nonce
	) public view returns (HousingAttributes memory) {
		require(
			hasSFT(owner, nonce),
			"HousingSFT: No tokens found for user at nonce"
		);

		return abi.decode(_getRawTokenAttributes(nonce), (HousingAttributes));
	}

	/// @notice Returns the maximum supply of the HousingSFT tokens.
	/// @return The maximum supply of tokens.
	function getMaxSupply() public pure returns (uint256) {
		return MAX_SUPPLY;
	}

	/// @notice Returns the SFT balance of a user including detailed attributes.
	/// @param user The address of the user to check.
	/// @return An array of `HousingSFTBalance` containing the user's balance details.
	function sftBalance(
		address user
	) public view returns (HousingSFTBalance[] memory) {
		SftBalance[] memory _sftBals = _sftBalance(user);
		HousingSFTBalance[] memory balance = new HousingSFTBalance[](
			_sftBals.length
		);

		for (uint256 i; i < _sftBals.length; i++) {
			SftBalance memory _sftBal = _sftBals[i];

			balance[i] = HousingSFTBalance({
				nonce: _sftBal.nonce,
				amount: _sftBal.amount,
				attributes: abi.decode(_sftBal.attributes, (HousingAttributes))
			});
		}

		return balance;
	}

	/// @notice Retrieves the token details including name, symbol, and max supply.
	/// @return A tuple containing the token's name, symbol, and max supply.
	function tokenDetails()
		public
		view
		returns (string memory, string memory, uint256)
	{
		return (name(), symbol(), getMaxSupply());
	}
}
