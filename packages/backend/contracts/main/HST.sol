// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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
	uint256 lkShtNonce;
}

contract HousingStakingToken is SFT {
	using SafeMath for uint256;

	uint256 public constant MIN_EPOCHS_LOCK = 180;
	uint256 public constant MAX_EPOCHS_LOCK = 1080;

	event MintHstToken(
		address indexed to,
		uint256 nonce,
		HstAttributes attributes
	);

	constructor() SFT("Housing Staking Token", "HST") {}

	function mint(
		TokenPayment[] calldata projectTokens,
		uint256 projectsShareCheckpoint,
		uint256 shtRewardPerShare,
		uint256 lkDuration,
		uint256 shtAmount,
		uint256 lkShtNonce
	) external onlyOwner returns (HstAttributes memory attr) {
		address caller = msg.sender;

		// Validate lock duration
		require(
			lkDuration >= MIN_EPOCHS_LOCK && lkDuration <= MAX_EPOCHS_LOCK,
			"Invalid lock duration"
		);

		require(shtAmount > 0 || lkShtNonce > 0, "Must send SHT");
		uint256 projectTokenCount = projectTokens.length;
		require(
			projectTokenCount > 0 && projectTokenCount <= 10,
			"Must send project tokens of approved number"
		);

		uint256 stakeWeight = shtAmount.mul(lkDuration);
		attr = HstAttributes({
			projectTokens: projectTokens,
			projectsShareCheckpoint: projectsShareCheckpoint,
			shtRewardPerShare: shtRewardPerShare,
			shtAmount: shtAmount,
			stakeWeight: stakeWeight,
			lkDuration: lkDuration,
			lkShtNonce: lkShtNonce
		});

		// Mint the HST token
		uint256 nonce = _mint(caller, 1, abi.encode(attr), "");

		emit MintHstToken(caller, nonce, attr);
	}

	function setTokenAttributes(
		uint256 nonce,
		HstAttributes memory attr
	) external onlyOwner {
		_setTokenAttributes(nonce, abi.encode(attr));
	}
}
