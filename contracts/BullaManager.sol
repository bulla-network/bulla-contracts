//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BullaGroup.sol";

struct FeeInfo {
    address payable collectionAddress;
    uint32 feeBasisPoints;
    uint32 bullaThreshold; //# of BULLA tokens held to get fee reduction
    uint32 reducedFeeBasisPoints; //reduced fee for BULLA token holders
}

contract BullaManager {
    bytes32 public immutable description;
    FeeInfo public feeInfo;
    IERC20 public bullaToken;
    address public owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "restricted to contract owner");
        _;
    }

    event NewBullaGroup(
        address indexed bullaManager,
        address indexed bullaGroup,
        address owner,
        string description,
        bytes32 groupType,
        bool requireMembership,
        uint256 blocktime
    );
    event FeeChanged(
        address indexed bullaManager,
        uint256 prevFee,
        uint256 newFee,
        uint256 blocktime
    );
    event CollectorChanged(
        address indexed bullaManager,
        address prevCollector,
        address newCollector,
        uint256 blocktime
    );
    event OwnerChanged(
        address indexed bullaManager,
        address prevOwner,
        address newOwner,
        uint256 blocktime
    );
    event BullaTokenChanged(
        address indexed bullaManager,
        address prevBullaToken,
        address newBullaToken,
        uint256 blocktime
    );
    event FeeThresholdChanged(
        address indexed bullaManager,
        uint256 prevFeeThreshold,
        uint256 newFeeThreshold,
        uint256 blocktime
    );
    event ReducedFeeChanged(
        address indexed bullaManager,
        uint256 prevFee,
        uint256 newFee,
        uint256 blocktime
    );

    constructor(
        bytes32 _description,
        address payable _collectionAddress,
        uint32 _feeBasisPoints
    ) {
        owner = msg.sender;
        feeInfo.collectionAddress = _collectionAddress;
        description = _description;
        feeInfo.feeBasisPoints = _feeBasisPoints;

        emit FeeChanged(address(this), 0, _feeBasisPoints, block.timestamp);
        emit CollectorChanged(
            address(this),
            address(0),
            _collectionAddress,
            block.timestamp
        );
        emit OwnerChanged(
            address(this),
            address(0),
            msg.sender,
            block.timestamp
        );
    }

    function createBullaGroup(
        string calldata _description,
        bytes32 groupType,
        bool requireMembership
    ) external {
        BullaGroup newGroup =
            new BullaGroup(
                address(this),
                msg.sender,
                groupType,
                requireMembership
            );
        emit NewBullaGroup(
            address(this),
            address(newGroup),
            msg.sender,
            _description,
            groupType,
            requireMembership,
            block.timestamp
        );
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit OwnerChanged(address(this), owner, _owner, block.timestamp);
    }

    function setFee(uint32 _feeBasisPoints) external onlyOwner {
        uint32 oldFee = feeInfo.feeBasisPoints;
        feeInfo.feeBasisPoints = _feeBasisPoints;
        emit FeeChanged(
            address(this),
            oldFee,
            feeInfo.feeBasisPoints,
            block.timestamp
        );
    }

    function setCollectionAddress(address payable _collectionAddress)
        external
        onlyOwner
    {
        feeInfo.collectionAddress = _collectionAddress;
        emit CollectorChanged(
            address(this),
            feeInfo.collectionAddress,
            _collectionAddress,
            block.timestamp
        );
    }

    //Set threshold of BULLA tokens owned that are required to receive reduced fee
    function setbullaThreshold(uint32 _threshold) external onlyOwner {
        feeInfo.bullaThreshold = _threshold;
        emit FeeThresholdChanged(
            address(this),
            feeInfo.bullaThreshold,
            _threshold,
            block.timestamp
        );
    }

    //reduced fee if threshold of BULLA tokens owned is met
    function setReducedFee(uint32 reducedFeeBasisPoints) external onlyOwner {
        uint32 oldFee = feeInfo.reducedFeeBasisPoints;
        feeInfo.reducedFeeBasisPoints = reducedFeeBasisPoints;
        emit FeeChanged(
            address(this),
            oldFee,
            feeInfo.feeBasisPoints,
            block.timestamp
        );
    }

    //set the contract address of BULLA ERC20 token
    function setBullaTokenAddress(address payable _bullaTokenAddress)
        external
        onlyOwner
    {
        bullaToken = IERC20(_bullaTokenAddress);
        emit BullaTokenChanged(
            address(this),
            address(bullaToken),
            _bullaTokenAddress,
            block.timestamp
        );
    }

    //get the amount of BULLA tokens held by a given address
    function getBullaBalance(address _holder) external view returns (uint256) {
        uint256 balance =
            address(bullaToken) == address(0)
                ? 0
                : bullaToken.balanceOf(_holder);
        return balance;
    }

   
}
