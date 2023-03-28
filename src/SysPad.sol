// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TierSystem.sol";
import "@openzeppelin/security/Pausable.sol";

import "./SysPadSale.sol";

contract SysPad is TierSystem, Pausable {
    // Percentage of platform fee
    uint256 public platformFee;

    // Address of platform fee. Platform fee will be transfer to it
    address public platformFeeAddress;

    // Array of created Sale Address
    address[] public allSales;

    address public usdc;

    address public usdt;

    // Mapping from token to array of sale address.
    mapping(address => address[]) public getSalesByToken;

    event SaleCreated(address token, address sale, uint256 saleId);
    event PlatformFeeChanged(uint256 fee);
    event PlatformFeeAddressChanged(address newFeeAddress);

    constructor(
        uint256 _platformFee,
        address _feeAddress,
        IStakingRewards _stakingRewards,
        address _usdc,
        address _usdt
    ) TierSystem(_stakingRewards) {
        require(_feeAddress != address(0), "SysPad:: ZERO_ADDRESS");
        require(_platformFee < 100, "SysPad:: OVERFLOW_FEE");
        platformFee = _platformFee;
        platformFeeAddress = _feeAddress;
        usdc = _usdc;
        usdt = _usdt;

        emit PlatformFeeChanged(_platformFee);
        emit PlatformFeeAddressChanged(_feeAddress);
    }

    /**
     * @notice Get the number of all created sales
     * @return length Return number of created sales
     */
    function allSalesLength() external view returns (uint256 length) {
        length = allSales.length;
    }

    /**
     * @notice Retrieve number of sales created for specific token
     * @param _token Address of token want to query
     * @return length Return number of created sale
     */
    function getSalesLengthByToken(
        address _token
    ) public view returns (uint256 length) {
        length = getSalesByToken[_token].length;
    }

    /**
     * @notice Owner can set the platform fee
     * @dev Sale will call function for distribute platform fee
     * @param _fee new fee percentage number
     */
    function setPlatformFee(uint256 _fee) external onlyOwner {
        require(_fee >= 0 && _fee < 100, "SysPad::OVERFLOW_FEE");
        platformFee = _fee;

        emit PlatformFeeChanged(_fee);
    }

    /**
     * @notice Owner can set the platform fee address
     * @dev Distribution will be transfer to this address
     * @param _feeAddress new fee percentage number
     */
    function setPlatformFeeAddress(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0), "SysPad::ZERO_ADDRESS");
        platformFeeAddress = _feeAddress;

        emit PlatformFeeAddressChanged(_feeAddress);
    }

    /**
     * @notice Register SysPad Sale for tokens
     * @dev To register, you MUST have an ERC20 token address
     * @param _token address of ERC20 token to sale
     * @param _duration Number of  SysPad Sale duration time in seconds (ex: 1 day = 86400 seconds)
     * @param _openTime Number of SysPad Sale start time in seconds
     * @param _releaseTime Timestamp when starts the claim distribution period
     * @param _saleAmountUsd Amount of token to be raised in usd (1e6).
     * @param _saleAmountToken Amount of token to be raised in token (1eDecimals).
     * @param _fundingWallet Address of wallet to receive the funds
     */
    function registerSale(
        address _token,
        uint256 _duration,
        uint256 _openTime,
        uint256 _releaseTime,
        uint256 _releaseDuration,
        uint256 _saleAmountUsd,
        uint256 _saleAmountToken,
        address _fundingWallet
    ) external onlyOwner whenNotPaused returns (address sale) {
        require(_token != address(0), "SysPad::ZERO_ADDRESS");
        require(_duration != 0, "SysPad::ZERO_DURATION");
        require(_releaseDuration != 0, "SysPad::ZERO_RELEASE_DURATION");
        require(_openTime >= block.timestamp, "SysPad::INVALID_OPEN_TIME");
        require(_saleAmountUsd > 0, "SysPad::INVALID_RAISE_AMOUNT");
        require(
            _openTime + _duration <= _releaseTime,
            "SysPad::INVALID_RELEASE_START_TIME"
        );
        require(_saleAmountToken > 0, "SysPad::INVALID_RAISE_AMOUNT_TOKEN");
        require(_fundingWallet != address(0), "SysPad::ZERO_ADDRESS");

        sale = address(
            new SysPadSale(
                IERC20(_token),
                _duration,
                _openTime,
                _releaseTime,
                _releaseDuration,
                _saleAmountUsd,
                _saleAmountToken,
                _fundingWallet
            )
        );
        getSalesByToken[_token].push(address(sale));
        allSales.push(address(sale));
        emit SaleCreated(address(_token), address(sale), allSales.length - 1);
    }

    /**
     * @dev Called by the owner to pause, triggers stopped state
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyOwner {
        _unpause();
    }
}
