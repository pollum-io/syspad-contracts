// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISysPad.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/security/Pausable.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/math/Math.sol";

contract SysPadSale is Pausable, Ownable {
    using SafeERC20 for IERC20;

    // -----------------------------------------
    // STATE VARIABLES
    // -----------------------------------------

    // Token being sold
    IERC20 public token;

    // Address of factory contract
    ISysPad public factory;

    // Address where funds are collected
    address public fundingWallet;

    // Timestamp when token started to sell
    uint256 public openTime;

    // Timestamp when token stopped to sell
    uint256 public closeTime;

    // Timestamp when starts the claim distribution period
    uint256 public releaseTime;

    // Timestamp when ends the claim distribution period
    uint256 public releaseEndTime;

    // Amount of token raised in wei
    uint256 public usdRaised;

    // Amount of tokens sold
    uint256 public tokenSold;

    // Amount of tokens claimed
    uint256 public tokenClaimed;

    // Amount of tokens to sold out
    uint256 public saleAmountToken;

    // Amount of token to be raised in usd (1e6)
    uint256 public saleAmountUsd;

    bool public isLoaded;
    // Max amout of dollars of each tier
    uint256 public maxBuyTier4 = 2500 * 1e6;
    uint256 public maxBuyTier3 = 1000 * 1e6;
    uint256 public maxBuyTier2 = 500 * 1e6;
    uint256 public maxBuyTier1 = 200 * 1e6;

    // User struct to store user operations
    struct UserControl {
        uint256 tokensBought;
        uint256 tokensClaimed;
    }

    // Token sold mapping to delivery
    mapping(address => UserControl) private userTokensMapping;

    // -----------------------------------------
    // EVENTS
    // -----------------------------------------

    event CampaignCreated(
        address token,
        uint256 openTime,
        uint256 closeTime,
        uint256 releaseTime,
        uint256 releaseEndTime,
        uint256 usdConversionRate,
        uint256 saleAmount
    );
    event TokenPurchase(
        address indexed purchaser,
        uint256 usdAmount,
        IERC20 token
    );
    event SaleLoaded(uint256 amount);
    event RefundRemainingTokensToOwner(address wallet, uint256 amount);
    event TokenClaimed(address wallet, uint256 amount);
    event UsdConversionRateChanged(uint256 rate);
    event FundingWalletChanged(address wallet);
    event ScheduleChanged(
        uint256 openTime,
        uint256 closeTime,
        uint256 releaseTime
    );

    // -----------------------------------------
    // CONSTRUCTOR
    // -----------------------------------------
    /**
     * @param _token address of ERC20 token being sold.
     * @param _duration Number of SysPad Sale duration time.
     * @param _openTime Timestamp of when SysPad Sale starts.
     * @param _releaseTime Timestamp of when SysPadd Slae claim period starts.
     * @param _saleAmountUsd Amount of token to be raised in usd (1e6).
     * @param _saleAmountToken Amount of token to be raised in token (1eDecimals).
     * @param _fundingWallet Address where collected funds will be forwarded to.
     */
    constructor(
        IERC20 _token,
        uint256 _duration,
        uint256 _openTime,
        uint256 _releaseTime,
        uint256 _releaseDuration,
        uint256 _saleAmountUsd,
        uint256 _saleAmountToken,
        address _fundingWallet
    ) {
        factory = ISysPad(_msgSender());
        token = _token;
        openTime = _openTime;
        closeTime = _openTime + _duration;
        releaseTime = _releaseTime;
        releaseEndTime = _releaseTime + _releaseDuration;
        saleAmountUsd = _saleAmountUsd;
        saleAmountToken = _saleAmountToken;
        fundingWallet = _fundingWallet;

        emit CampaignCreated(
            address(token),
            openTime,
            closeTime,
            releaseTime,
            releaseEndTime,
            saleAmountUsd,
            saleAmountToken
        );
    }

    // -----------------------------------------
    // VIEWS
    // -----------------------------------------

    /**
     * @notice Returns the Buyable tokens of an address
     * @return buyableTokens Returns amount of tokens the user can buy
     * @param _address Address to find the amount of tokens
     */
    function getBuyableTokens(
        address _address
    ) public view returns (uint256 buyableTokens) {
        buyableTokens =
            calculateTokenAmount(maxBuyAmountUsd(_address)) -
            userTokensMapping[_address].tokensBought;
    }

    /**
     * @notice calculate the conversion rate of the token
     * @return tokenAmount Returns the amount of tokens
     * @param usdcAmount Amount of usd to calculate the amount of tokens
     */
    function calculateTokenAmount(
        uint256 usdcAmount
    ) public view returns (uint256 tokenAmount) {
        tokenAmount = (usdcAmount * saleAmountToken) / saleAmountUsd;
    }

    /**
     * @notice Returns the available tokens of Campaign
     * @return availableTokens Returns amount of tokens available to buy in the Campaign
     */
    function getAvailableTokens()
        public
        view
        returns (uint256 availableTokens)
    {
        availableTokens = saleAmountToken - tokenSold;
    }

    /**
     * @notice Returns the Total Claimable tokens of an address
     * @return claimableTokens Returns amount of tokens the user can calaim
     * @param _address Address to find the amount of tokens
     */
    function getClaimableTokens(
        address _address
    ) external view returns (uint256 claimableTokens) {
        UserControl memory user = userTokensMapping[_address];
        claimableTokens = user.tokensBought - user.tokensClaimed;
    }

    /**
     * @notice Returns the Bought tokens of an address
     * @return boughtTokens Returns amount of tokens the user bought
     * @param _address Address to find the amount of tokens
     */
    function getBoughtTokens(
        address _address
    ) external view returns (uint256 boughtTokens) {
        boughtTokens = userTokensMapping[_address].tokensBought;
    }

    /**
     * @notice Returns the Available tokens to claim of an address
     * @return availableTokens Returns amount of tokens the user can calain at this moment
     * @param _address Address to find the amount of tokens
     */
    function getAvailableTokensToClaim(
        address _address
    ) public view returns (uint256 availableTokens) {
        if (!isClaimable()) {
            availableTokens = 0;
        } else {
            UserControl memory userInfo = userTokensMapping[_address];

            uint256 lastTimeReleaseApplicable = block.timestamp < releaseEndTime
                ? block.timestamp
                : releaseEndTime;

            uint256 timeElapsed = lastTimeReleaseApplicable - releaseTime;

            availableTokens =
                (((userInfo.tokensBought * 10) / 100) +
                    ((90 * userInfo.tokensBought * timeElapsed) /
                        100 /
                        (releaseEndTime - releaseTime))) -
                userInfo.tokensClaimed;
        }
    }

    /**
     * @notice Return true if campaign has ended and is eneable to claim
     * @dev User cannot claim tokens when isClaimable == false
     * @return claimable true if the release time < now.
     */
    function isClaimable() public view returns (bool claimable) {
        claimable = block.timestamp >= releaseTime && isLoaded;
    }

    /**
     * @notice Return true if campaign is open
     * @dev User can purchase / trade tokens when isOpen == true
     * @return open true if the Sale is open.
     */
    function isOpen() public view returns (bool open) {
        open =
            (block.timestamp <= closeTime) &&
            (block.timestamp >= openTime) &&
            isLoaded;
    }

    // -----------------------------------------
    // MUTATIVE FUNCTIONS
    // -----------------------------------------

    /**
     * @notice User can buy token by this function when available.
     * @dev low level token purchase ***DO NOT OVERRIDE***
     */
    function buyToken(IERC20 _token, uint256 _amount) public whenNotPaused {
        require(
            address(_token) == factory.usdc() ||
                address(_token) == factory.usdt(),
            "SysPadSale::INVALID_TOKEN"
        );
        require(!factory.paused(), "SysPadSale::PAUSED");
        require(_amount > 1e6, "SysPadSale::INVALID_AMOUNT");
        require(isLoaded, "SysPadSale::NOT_LOADED");
        require(isOpen(), "SysPadSale::PURCHASE_NOT_ALLOWED");

        // calculate token amount to be sold
        uint256 _tokenAmount = calculateTokenAmount(_amount);

        require(
            _tokenAmount <= getBuyableTokens(_msgSender()),
            "SysPadSale::MAX_BUY_AMOUNT_EXEDED"
        );
        require(
            getAvailableTokens() >= _tokenAmount,
            "SysPadSale::NOT_ENOUGH_AVAILABLE_TOKENS"
        );

        _token.safeTransferFrom(_msgSender(), address(this), _amount);

        usdRaised += _amount;
        tokenSold += _tokenAmount;
        userTokensMapping[_msgSender()].tokensBought += _tokenAmount;

        uint256 platformFee = (_amount * factory.platformFee()) / 100;

        _token.safeTransfer(factory.platformFeeAddress(), platformFee);

        _token.safeTransfer(fundingWallet, _amount - platformFee);

        emit TokenPurchase(_msgSender(), _amount, _token);
    }

    function claimTokens() public whenNotPaused {
        require(!factory.paused(), "SysPadSale::PAUSED");
        require(isClaimable(), "SysPadSale::SALE_NOT_ENDED");
        uint256 _tokenAmount = getAvailableTokensToClaim(_msgSender());
        require(_tokenAmount > 0, "SysPadSale::EMPTY_BALANCE");

        token.safeTransfer(_msgSender(), _tokenAmount);

        tokenClaimed += _tokenAmount;
        userTokensMapping[_msgSender()].tokensClaimed += _tokenAmount;

        emit TokenClaimed(_msgSender(), _tokenAmount);
    }

    /**
     * @notice Check the amount of tokens is bigger than saleAmount and enable to buy
     */
    function loadSale() external onlyOwner {
        require(!isLoaded, "SysPadSale::LOAD_ALREADY_VERIFIED");
        require(
            block.timestamp < openTime,
            "SysPadSale::CAMPAIGN_ALREADY_STARTED"
        );
        require(
            token.balanceOf(_msgSender()) >= saleAmountToken &&
                token.allowance(_msgSender(), address(this)) >= saleAmountToken,
            "SysPadSale::NOT_ENOUGH_TOKENS"
        );

        token.safeTransferFrom(_msgSender(), address(this), saleAmountToken);
        isLoaded = true;
        emit SaleLoaded(saleAmountToken);
    }

    /**
     * @notice Owner can receive their remaining tokens when sale Ended
     * @dev  Can refund remainning token if the sale ended
     * @param _wallet Address wallet who receive the remainning tokens when sale end
     */
    function refundRemainingTokensToOwner(address _wallet) external onlyOwner {
        require(isClaimable(), "SysPadSale::SALE_NOT_ENDED");
        uint256 remainingTokens = getAvailableTokens();
        require(remainingTokens > 0, "SysPadSale::EMPTY_BALANCE");
        token.safeTransfer(_wallet, remainingTokens);
        emit RefundRemainingTokensToOwner(_wallet, remainingTokens);
    }

    /**
     * @notice Owner can set the conversion rate.
     * @param _newAmount New amount of usd to be raised
     */
    function setSaleAmountUsd(uint256 _newAmount) external onlyOwner {
        require(saleAmountUsd != _newAmount, "SysPadSale::RATE_INVALID");
        require(!isClaimable(), "SysPadSale::SALE_ENDED");

        saleAmountUsd = _newAmount;
        emit UsdConversionRateChanged(_newAmount);
    }

    /**
     * @notice Owner can set the fundingWallet where funds are collected
     * @param _address Address of funding wallets. Sold tokens in eth will transfer to this address
     */
    function setFundingWallet(address _address) external onlyOwner {
        require(_address != address(0), "SysPadSale::ZERO_ADDRESS");
        require(!isClaimable(), "SysPadSale::SALE_ENDED");
        require(
            fundingWallet != _address,
            "SysPadSale::FUNDING_WALLET_INVALID"
        );
        fundingWallet = _address;
        emit FundingWalletChanged(_address);
    }

    /**
     * @notice Owner can set the close time (time in seconds). User can buy before close time.
     * @param _openTime Value in uint256 determine when we allow user to buy tokens.
     * @param _duration Value in uint256 determine the duration of user can buy tokens.
     * @param _releaseTime Value in uint256 determine when starts the claim period.
     */
    function setSchedule(
        uint256 _openTime,
        uint256 _duration,
        uint256 _releaseTime,
        uint256 _releaseDuration
    ) external onlyOwner {
        require(_openTime >= block.timestamp, "SysPadSale::INVALID_OPEN_TIME");
        require(
            _openTime + _duration <= _releaseTime,
            "SysPadSale::INVALID_RELEASE_TIME"
        );
        require(!isClaimable(), "SysPadSale::SALE_ENDED");

        openTime = _openTime;
        closeTime = _openTime + _duration;
        releaseTime = _releaseTime;
        releaseEndTime = _releaseTime + _releaseDuration;
        emit ScheduleChanged(_openTime, _duration, _releaseTime);
    }

    /**
     * @dev Returns the address of the Factory owner.
     */
    function owner() public view override returns (address) {
        return factory.owner();
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

    function maxBuyAmountUsd(address _address) public view returns (uint256) {
        uint256 tier = factory.getTierAt(_address, openTime);
        if (tier == 4) {
            return maxBuyTier4;
        } else if (tier == 3) {
            return maxBuyTier3;
        } else if (tier == 2) {
            return maxBuyTier2;
        } else if (tier == 1) {
            return maxBuyTier1;
        } else {
            return 0;
        }
    }

    function setMaxBuyTiers(
        uint256 _maxBuyTier4,
        uint256 _maxBuyTier3,
        uint256 _maxBuyTier2,
        uint256 _maxBuyTier1
    ) external onlyOwner {
        maxBuyTier4 = _maxBuyTier4;
        maxBuyTier3 = _maxBuyTier3;
        maxBuyTier2 = _maxBuyTier2;
        maxBuyTier1 = _maxBuyTier1;
    }
}
