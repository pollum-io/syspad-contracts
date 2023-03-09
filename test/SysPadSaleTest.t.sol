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
    MockERC20 public saleToken;
    SysPadSale public sysPadSale;
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
        saleToken = new MockERC20("Sale Token", "STKN");

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
        stakingToken.mint(user1, 1000 ether);
        vm.prank(user1);
        stakingToken.approve(address(stakingRewards), 1000 ether);
        vm.prank(user1);
        stakingRewards.stake(1000 ether);

        // Mint some staking tokens for the user
        stakingToken.mint(owner, 10000 ether);

        stakingToken.approve(address(stakingRewards), 10000 ether);

        // Notify the contract of the reward amount and duration
        stakingRewards.notifyRewardAmount(10000 ether, 100 days);

        sysPad.addToWhitelist(user1);
        vm.warp(1 days);
        uint256 duration = 15 days;
        uint256 openingTime = block.timestamp + 1;
        uint256 releaseTime = openingTime + duration;
        uint256 releaseDuration = 5 days;
        uint256 saleAmountUsd = 50000 * 1e6;
        uint256 saleAmountToken = 100000 ether;
        address fundingWallet = user2;

        sysPadSale = SysPadSale(
            sysPad.registerSale(
                address(saleToken),
                duration,
                openingTime,
                releaseTime,
                releaseDuration,
                saleAmountUsd,
                saleAmountToken,
                fundingWallet
            )
        );
    }

    function testBuyToken() public {
        // first load sale
        saleToken.mint(owner, 100000 ether);
        saleToken.approve(address(sysPadSale), 100000 ether);
        sysPadSale.loadSale();
        // check load Sale
        assertEq(
            sysPadSale.token().balanceOf(address(sysPadSale)),
            100000 ether
        );

        vm.warp(block.timestamp + 1 days);

        uint256 maxAmount = sysPadSale.maxBuyAmountUsd(user1);
        uint256 buyable = sysPadSale.getBuyableTokens(user1);
        assertEq(maxAmount, 200 * 1e6);
        usdc.mint(user1, maxAmount);

        // buy token
        vm.startPrank(user1);
        usdc.approve(address(sysPadSale), maxAmount);
        sysPadSale.buyToken(IERC20(usdc), maxAmount);

        // check balance
        assertEq(usdc.balanceOf(user1), 0);
        assertEq(sysPadSale.getClaimableTokens(user1), buyable);
        assertEq(sysPadSale.usdRaised(), maxAmount);
        assertEq(sysPadSale.tokenSold(), buyable);
    }

    function testFailBuyTokenInvalidToken() public {
        // first load sale
        saleToken.mint(owner, 100000 ether);
        saleToken.approve(address(sysPadSale), 100000 ether);
        sysPadSale.loadSale();

        vm.warp(block.timestamp + 1 days);
        stakingToken.mint(user1, 1e7);
        vm.startPrank(user1);
        // stakingToken.approve(address(sysPadSale), 1e7);
        sysPadSale.buyToken(IERC20(stakingToken), 1e7);
        // vm.expectRevert(bytes("SysPadSale::INVALID_TOKEN"));
    }

    function testFailBuyTokenInvalidAmount() public {
        // first load sale
        saleToken.mint(owner, 100000 ether);
        saleToken.approve(address(sysPadSale), 100000 ether);
        sysPadSale.loadSale();

        vm.warp(block.timestamp + 1 days);
        usdc.mint(user1, 1e5);

        vm.startPrank(user1);
        usdc.approve(address(sysPadSale), 1e5);
        sysPadSale.buyToken(IERC20(usdc), 1e5);
        vm.expectRevert(bytes("SysPadSale::INVALID_AMOUNT"));
    }

    function testFailLoadSaleAlreadyLoaded() public {
        saleToken.mint(owner, 2 * 100000 ether);
        saleToken.approve(address(sysPadSale), 2 * 100000 ether);
        sysPadSale.loadSale();

        sysPadSale.loadSale();
        vm.expectRevert(bytes("SysPadSale::LOAD_ALREADY_VERIFIED"));
    }

    function testFailLoadSaleAlreadyStarted() public {
        saleToken.mint(owner, 100000 ether);
        saleToken.approve(address(sysPadSale), 100000 ether);
        vm.warp(block.timestamp + 1 days);
        sysPadSale.loadSale();
        vm.expectRevert(bytes("SysPadSale::LOAD_ALREADY_STARTED"));
    }

    function testFailLoadSaleNotEnoughToken() public {
        saleToken.mint(owner, 100 ether);
        saleToken.approve(address(sysPadSale), 100 ether);
        sysPadSale.loadSale();
        vm.expectRevert(bytes("SysPadSale::NOT_ENOUGH_TOKENS"));
    }

    function testSoldOut() public {
        for (uint256 i = 0; i < 250; i++) {
            stakingToken.mint(address(uint160(2000 + i)), 1000 ether);
            sysPad.addToWhitelist(address(uint160(2000 + i)));
            vm.prank(address(uint160(2000 + i)));
            stakingToken.approve(address(stakingRewards), 1000 ether);
            vm.prank(address(uint160(2000 + i)));
            stakingRewards.stake(1000 ether);
        }
        vm.warp(block.timestamp + 1 days);

        // first load sale
        sysPadSale.setSchedule(
            block.timestamp + 1,
            15 days,
            block.timestamp + 1 + 15 days,
            5 days
        );
        saleToken.mint(owner, 100000 ether);
        saleToken.approve(address(sysPadSale), 100000 ether);
        sysPadSale.loadSale();

        vm.warp(block.timestamp + 2);

        for (uint256 i = 0; i < 250; i++) {
            uint256 maxAmount = sysPadSale.maxBuyAmountUsd(
                address(uint160(2000 + i))
            );
            usdc.mint(address(uint160(2000 + i)), maxAmount);
            // check mint
            assertEq(usdc.balanceOf(address(uint160(2000 + i))), maxAmount);

            // buy token
            vm.prank(address(uint160(2000 + i)));
            usdc.approve(address(sysPadSale), maxAmount);
            vm.prank(address(uint160(2000 + i)));
            sysPadSale.buyToken(IERC20(usdc), maxAmount);

            // check balance
            assertEq(usdc.balanceOf(address(uint160(2000 + i))), 0);
            uint256 tokenAmount = sysPadSale.calculateTokenAmount(maxAmount);
            assertEq(
                sysPadSale.getClaimableTokens(address(uint160(2000 + i))),
                tokenAmount
            );
            assertEq(sysPadSale.usdRaised(), maxAmount * (i + 1));
            assertEq(sysPadSale.tokenSold(), tokenAmount * (i + 1));
            assertEq(
                sysPadSale.getAvailableTokens(),
                100000 ether - (tokenAmount * (i + 1))
            );
        }

        vm.warp(block.timestamp + 15 days - 1);
        for (uint i = 0; i < 250; i++) {
            // start claim
            uint256 totalToClaim = sysPadSale.getBoughtTokens(
                address(uint160(2000 + i))
            );

            uint256 claimable = sysPadSale.getAvailableTokensToClaim(
                address(uint160(2000 + i))
            );

            vm.prank(address(uint160(2000 + i)));
            sysPadSale.claimTokens();

            //check claim
            assertEq(
                saleToken.balanceOf(address(uint160(2000 + i))),
                (10 * totalToClaim) / 100
            );
            assertEq((10 * totalToClaim) / 100, claimable);
        }

        vm.warp(block.timestamp + 1 days);
        for (uint i = 0; i < 250; i++) {
            // start claim
            uint256 totalToClaim = sysPadSale.getBoughtTokens(
                address(uint160(2000 + i))
            );
            uint256 claimable = sysPadSale.getAvailableTokensToClaim(
                address(uint160(2000 + i))
            );

            vm.prank(address(uint160(2000 + i)));
            sysPadSale.claimTokens();

            //check claim
            assertEq(claimable, (((90 * totalToClaim) / 100) * 20) / 100);
            assertEq(
                saleToken.balanceOf(address(uint160(2000 + i))),
                (10 * totalToClaim) /
                    100 +
                    (((90 * totalToClaim) / 100) * 20) /
                    100
            );
        }
        vm.warp(block.timestamp + 4 days);
        for (uint i = 0; i < 250; i++) {
            // start claim
            uint256 totalToClaim = sysPadSale.getBoughtTokens(
                address(uint160(2000 + i))
            );
            uint256 claimable = sysPadSale.getAvailableTokensToClaim(
                address(uint160(2000 + i))
            );

            vm.prank(address(uint160(2000 + i)));
            sysPadSale.claimTokens();

            //check claim
            assertEq(claimable, (((90 * totalToClaim) / 100) * 80) / 100);
            assertEq(
                saleToken.balanceOf(address(uint160(2000 + i))),
                totalToClaim
            );
        }

        assertEq(sysPadSale.getAvailableTokens(), 0);
        assertEq(sysPadSale.tokenClaimed(), sysPadSale.saleAmountToken());
    }
}
