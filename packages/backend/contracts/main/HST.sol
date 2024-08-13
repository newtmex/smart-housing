// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { TokenPayment } from "../lib/TokenPayments.sol";
import { SFT } from "../modules/SFT.sol";

library NewHousingStakingToken {
	function create() external returns (HousingStakingToken) {
		return new HousingStakingToken();
	}
}

struct HstAttributes {
	TokenPayment[] projectTokens;
	uint256 projectsShareCheckpoint;
	uint256 shtRewardPerShare;
	uint256 shtAmount;
	uint256 stakeWeight;
	uint256 lkDuration;
	uint256[] lkShtNonces;
}

uint256 constant MIN_EPOCHS_LOCK = 180;
uint256 constant MAX_EPOCHS_LOCK = 1080;

contract HousingStakingToken is SFT {
	using SafeMath for uint256;

	struct HSTBalance {
		uint256 nonce;
		uint256 amount;
		HstAttributes attributes;
	}

	event MintHstToken(
		address indexed to,
		uint256 nonce,
		HstAttributes attributes
	);

	constructor() SFT("Housing Staking Token", "HST") {}

	/// @notice Mints a new Housing Staking Token (HST) with specified attributes.
	/// @param projectTokens Array of project tokens associated with the HST.
	/// @param projectsShareCheckpoint The checkpoint for project share calculations.
	/// @param shtRewardPerShare The reward per share of SHT.
	/// @param lkDuration Duration of the lock in epochs.
	/// @param shtAmount Amount of SHT to be associated with the token.
	/// @param lkShtNonces Array of nonces associated with locked SHT.
	/// @param caller Address of the caller requesting the minting.
	/// @return attr The attributes associated with the minted token.
	function mint(
		TokenPayment[] calldata projectTokens,
		uint256 projectsShareCheckpoint,
		uint256 shtRewardPerShare,
		uint256 lkDuration,
		uint256 shtAmount,
		uint256[] memory lkShtNonces,
		address caller
	) external onlyOwner returns (HstAttributes memory attr) {
		// Validate lock duration
		require(
			lkDuration >= MIN_EPOCHS_LOCK && lkDuration <= MAX_EPOCHS_LOCK,
			"Invalid lock duration"
		);

		require(shtAmount > 0 || lkShtNonces.length > 0, "Must send SHT");

		uint256 projectTokenCount = projectTokens.length;
		require(
			projectTokenCount > 0 && projectTokenCount <= 10,
			"Must send approved number of project tokens"
		);

		uint256 stakeWeight = shtAmount.mul(lkDuration);
		attr = HstAttributes({
			projectTokens: projectTokens,
			projectsShareCheckpoint: projectsShareCheckpoint,
			shtRewardPerShare: shtRewardPerShare,
			shtAmount: shtAmount,
			stakeWeight: stakeWeight,
			lkDuration: lkDuration,
			lkShtNonces: lkShtNonces
		});

		// Mint the HST token
		uint256 nonce = _mint(caller, 1, abi.encode(attr), "");

		emit MintHstToken(caller, nonce, attr);
	}

	/// @notice Retrieves the balance of HST tokens for a specified user.
	/// @param user Address of the user whose balance is to be retrieved.
	/// @return balance Array of HSTBalance representing the user's HST holdings.
	function sftBalance(
		address user
	) public view returns (HSTBalance[] memory) {
		SftBalance[] memory _sftBals = _sftBalance(user);
		HSTBalance[] memory balance = new HSTBalance[](_sftBals.length);

		for (uint256 i; i < _sftBals.length; i++) {
			SftBalance memory _sftBal = _sftBals[i];

			balance[i] = HSTBalance({
				nonce: _sftBal.nonce,
				amount: _sftBal.amount,
				attributes: abi.decode(_sftBal.attributes, (HstAttributes))
			});
		}

		return balance;
	}
}
