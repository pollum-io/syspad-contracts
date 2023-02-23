// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IStakingRewards.sol";
import "@openzeppelin/access/Ownable.sol";

abstract contract TierSystem is Ownable {
    IStakingRewards public stakingRewards;

    uint256 public tier4 = 50000 * 1e18;
    uint256 public tier3 = 10000 * 1e18;
    uint256 public tier2 = 1500 * 1e18;
    uint256 public tier1 = 350 * 1e18;

    mapping(address => bool) whitelist;
    event AddedToWhitelist(address indexed account);
    event AddedToWhitelistInBatch(address[] indexed accounts);
    event RemovedFromWhitelist(address indexed account);
    event RemovedFromWhitelistInBatch(address[] indexed accounts);
    event StakingRewardsAddressChanged(IStakingRewards stakingRewards);

    constructor(IStakingRewards _stakingRewards) {
        stakingRewards = _stakingRewards;
    }

    function setStakingRewardsContract(
        IStakingRewards _stakingRewards
    ) public onlyOwner {
        stakingRewards = _stakingRewards;
        emit StakingRewardsAddressChanged(stakingRewards);
    }

    function setTiers(
        uint256 _tier4,
        uint256 _tier3,
        uint256 _tier2,
        uint256 _tier1
    ) external onlyOwner {
        tier4 = _tier4;
        tier3 = _tier3;
        tier2 = _tier2;
        tier1 = _tier1;
    }

    function addToWhitelist(address _address) external onlyOwner {
        require(_address != address(0), "TierSystem::invalid wallet");
        whitelist[_address] = true;
        emit AddedToWhitelist(_address);
    }

    function addToWhitelistBatch(
        address[] memory _addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
        }
        emit AddedToWhitelistInBatch(_addresses);
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        require(_address != address(0), "TierSystem::invalid wallet");
        whitelist[_address] = false;
        emit RemovedFromWhitelist(_address);
    }

    function removeFromWhitelistBatch(
        address[] memory _addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = false;
        }
        emit RemovedFromWhitelistInBatch(_addresses);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    function getTier(address _address) external view returns (uint256) {
        require(isWhitelisted(_address), "TierSystem:: not whitelisted");

        uint256 balance = stakingRewards.balanceOf(_address);

        if (balance >= tier4) {
            return 4;
        } else if (balance >= tier3) {
            return 3;
        } else if (balance >= tier2) {
            return 2;
        } else if (balance >= tier1) {
            return 1;
        } else {
            return 0;
        }
    }

    function getTierAt(
        address _address,
        uint256 _timepoint
    ) external view returns (uint256) {
        require(isWhitelisted(_address), "TierSystem:: not whitelisted");
        uint256 balance = stakingRewards.balanceOfAt(_address, _timepoint);
        if (balance >= tier4) {
            return 4;
        } else if (balance >= tier3) {
            return 3;
        } else if (balance >= tier2) {
            return 2;
        } else if (balance >= tier1) {
            return 1;
        } else {
            return 0;
        }
    }
}
