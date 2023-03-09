// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/SysPad.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "../src/StakingRewards.sol";
import "../src/SysPadSale.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) payable ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}

contract Stable is ERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) payable ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract SysPadTest is Test {
    Stable public usdc;
    Stable public usdt;
    MockERC20 public stakingToken;

    SysPad public sysPad;
    StakingRewards public stakingRewards;

    address public owner;

    address user1 = address(1);
    address user2 = address(2);
    address feeReceiver = address(3);

    function setUp() public {
        owner = address(this);
        usdc = new Stable("USDC", "USDC");
        usdt = new Stable("USDT", "USDT");

        stakingToken = new MockERC20("Staking Token", "STK");

        stakingRewards = new StakingRewards(
            address(stakingToken), // reward token
            address(stakingToken) // staking token
        );

        sysPad = new SysPad(
            5, // platform fee
            feeReceiver, // platform fee address
            IStakingRewards(address(stakingRewards)), // staking rewards
            address(usdc), // usdc
            address(usdt) // usdt
        );

        // Mint some staking tokens for the user
        stakingToken.mint(user1, 1001 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewards), 1001 ether);
        vm.prank(user1);
        stakingRewards.stake(1001 ether);

        // Mint some staking tokens for the user
        stakingToken.mint(owner, 10000 ether);

        stakingToken.approve(address(stakingRewards), 10000 ether);

        // Notify the contract of the reward amount and duration
        stakingRewards.notifyRewardAmount(10000 ether, 100 days);

        sysPad.addToWhitelist(user1);
    }

    function testCreateSale() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = 15 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        address sysPadSale = sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );

        assertEq(sysPad.allSales(0), sysPadSale);
        assertEq(sysPad.getSalesByToken(address(token), 0), sysPadSale);
        assertEq(sysPad.allSalesLength(), 1);
        assertEq(sysPad.getSalesLengthByToken(address(token)), 1);
    }

    function testFailNotOwner() public {
        vm.startPrank(user2);
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = 15 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
    }

    function testFailPaused() public {
        sysPad.pause();
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = 15 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("Pausable: paused"));
    }

    function testFailTokenZeroAddress() public {
        uint256 duration = 15 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(0),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("SysPad::ZERO_ADDRESS"));
    }

    function testFailInvalidDuration() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = 0;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("SysPad::ZERO_DURATION"));
    }

    function testFailInvalidRelease() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = block.timestamp + 1 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 0;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("SysPad::ZERO_RELEASE_DURATION"));
    }

    function testFailInvalidOpenTime() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = block.timestamp + 1 days;
        uint256 openingTime = 0;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("SysPad::INVALID_OPEN_TIME"));
    }

    function testFailInvalidUSDRate() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = block.timestamp + 1 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 0;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("SysPad::INVALID_RAISE_AMOUNT"));
    }

    function testFailInvalidReleaseStartTime() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = block.timestamp + 1 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration - 5;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("INVALID_RELEASE_START_TIME"));
    }

    function testFailInvalidRaiseAmount() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = block.timestamp + 1 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 0;
        address fundingWallet = user2;

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("SysPad::INVALID_RAISE_AMOUNT_TOKEN"));
    }

    function testFailInvalidWallet() public {
        MockERC20 token = new MockERC20("Sale Token", "STKN");
        uint256 duration = block.timestamp + 1 days;
        uint256 openingTime = block.timestamp + 1 days;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50 * 1e6;
        uint256 saleAmountToken = 100 ether;
        address fundingWallet = address(0);

        sysPad.registerSale(
            address(token),
            duration,
            openingTime,
            releaseTime,
            releaseDuration,
            saleAmountUsd,
            saleAmountToken,
            fundingWallet
        );
        vm.expectRevert(bytes("SysPad::ZERO_ADDRESS"));
    }

    function testUserTier() public {
        uint256 tier = sysPad.getTier(user1);
        assertEq(tier, 1);
    }

    function testUserTierAt() public {
        uint256 tier = sysPad.getTierAt(user1, 0);
        assertEq(tier, 0);
    }
}
