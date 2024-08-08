// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import { HousingProject } from "./HousingProject.sol";

library NewHousingProject {
	function create(
		string memory name,
		string memory symbol,
		address smartHousingAddr
	) external returns (HousingProject) {
		return new HousingProject(name, symbol, smartHousingAddr);
	}
}
