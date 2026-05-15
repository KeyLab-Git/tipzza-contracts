// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TipzzaCampaigns
 * @dev Multi-token NFT contract where every single Pizza Slice is a unique ID.
 * This version uses a Pull-Payment (Withdrawal) pattern for maximum reliability.
 */
contract TipzzaCampaigns is ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;

    struct Campaign {
        address payable creator;
        uint256 pricePerSlice;
        uint256 maxSlices;
        uint256 slicesSold;
        bool isActive;
        string baseMetadataURI; 
    }

    // Global counters
    uint256 public nextSliceId = 1;
    uint256 public nextCampaignId = 1;

    // Mappings
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => uint256) public sliceToCampaign; 
    mapping(uint256 => uint256) public sliceNumber;    
    
    // Tracking earnings for the withdrawal pattern
    mapping(address => uint256) public pendingWithdrawals;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 maxSlices);
    event SlicePurchased(uint256 indexed campaignId, uint256 indexed sliceId, address indexed buyer, uint256 number);
    event Withdrawal(address indexed creator, uint256 amount);

    constructor() ERC1155("") Ownable(msg.sender) {}

    /**
     * @dev Admin creates a campaign.
     */
    function createCampaign(
        address payable _creator,
        uint256 _pricePerSlice,
        uint256 _maxSlices,
        string memory _metadataURI
    ) external onlyOwner {
        require(_creator != address(0), "Invalid creator address");
        require(_maxSlices > 0, "Max slices must be > 0");
        require(bytes(_metadataURI).length > 0, "Invalid metadata URI");

        uint256 campaignId = nextCampaignId++;
        
        campaigns[campaignId] = Campaign({
            creator: _creator,
            pricePerSlice: _pricePerSlice,
            maxSlices: _maxSlices,
            slicesSold: 0,
            isActive: true,
            baseMetadataURI: _metadataURI
        });

        emit CampaignCreated(campaignId, _creator, _maxSlices);
    }

    /**
     * @dev Fans buy a slice. 
     * Funds are held in the contract and credited to the creator for withdrawal.
     */
    function buySlice(uint256 _campaignId) external payable nonReentrant {
        Campaign storage camp = campaigns[_campaignId];
        
        require(camp.isActive, "Pizza is all gone!");
        require(camp.slicesSold < camp.maxSlices, "Sold out!");
        require(msg.value >= camp.pricePerSlice, "Insufficient payment");

        camp.slicesSold++;
        uint256 currentNumber = camp.slicesSold;
        uint256 sliceId = nextSliceId++;
        
        sliceToCampaign[sliceId] = _campaignId;
        sliceNumber[sliceId] = currentNumber;

        if (camp.slicesSold == camp.maxSlices) {
            camp.isActive = false;
        }

        // Credit the creator's balance
        pendingWithdrawals[camp.creator] += msg.value;

        // Mint the unique NFT
        _mint(msg.sender, sliceId, 1, "");

        emit SlicePurchased(_campaignId, sliceId, msg.sender, currentNumber);
    }

    /**
     * @dev Allows creators to claim their accumulated pizza money.
     */
    function withdrawEarnings() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No earnings to withdraw");

        // Reset balance BEFORE sending to prevent reentrancy (Safety First)
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev View function to check how much you can withdraw.
     */
    function getBalance(address _creator) external view returns (uint256) {
        return pendingWithdrawals[_creator];
    }

    function uri(uint256 _tokenId) public view override returns (string memory) {
        uint256 campaignId = sliceToCampaign[_tokenId];
        uint256 number = sliceNumber[_tokenId];
        
        return string(abi.encodePacked(
            campaigns[campaignId].baseMetadataURI, 
            "/", 
            number.toString()
        ));
    }
}
