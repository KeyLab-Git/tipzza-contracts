// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TipzzaRouter
 * @dev Secure P2P tipping protocol with automated fee distribution.
 * Designed for Tipzza: Direct magic, zero middlemen.
 */
contract TipzzaRouter {
    address public owner;
    address public feeRecipient;
    uint256 public platformFeeBps = 300; // 3% fee (in Basis Points)

    event TipSent(
        address indexed from,
        address indexed to,
        uint256 totalAmount,
        uint256 creatorAmount,
        uint256 feeAmount,
        string message
    );

    constructor(address _feeRecipient) {
        owner = msg.sender;
        feeRecipient = _feeRecipient;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    /**
     * @dev Updates the fee recipient address.
     */
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid address");
        feeRecipient = _newRecipient;
    }

    /**
     * @dev Updates the platform fee.
     * @param _newFeeBps Fee in basis points (e.g., 300 = 3%).
     */
    function setPlatformFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 1000, "Fee too high (max 10%)");
        platformFeeBps = _newFeeBps;
    }

    /**
     * @dev Routes a native token tip (MATIC on Polygon, ETH on Base).
     * @param _creator The address of the creator receiving the tip.
     * @param _message A small thank you message for the on-chain event.
     */
    function sendTip(address payable _creator, string calldata _message) external payable {
        require(msg.value > 0, "Tip must be greater than zero");
        require(_creator != address(0), "Invalid creator address");

        uint256 feeAmount = (msg.value * platformFeeBps) / 10000;
        uint256 creatorAmount = msg.value - feeAmount;

        // 1. Send Creator Share
        (bool creatorSuccess, ) = _creator.call{value: creatorAmount}("");
        require(creatorSuccess, "Transfer to creator failed");

        // 2. Send Platform Fee
        (bool feeSuccess, ) = payable(feeRecipient).call{value: feeAmount}("");
        require(feeSuccess, "Transfer to fee recipient failed");

        emit TipSent(
            msg.sender,
            _creator,
            msg.value,
            creatorAmount,
            feeAmount,
            _message
        );
    }

    /**
     * @dev Fallback to prevent stuck funds.
     */
    receive() external payable {
        revert("Use sendTip() to support creators");
    }
}
