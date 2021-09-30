//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBullaManager.sol";

error NotContractOwner(address _sender);

contract BullaManager is IBullaManager {
    bytes32 public immutable description;
    FeeInfo public feeInfo;
    IERC20 public bullaToken;
    address public owner;

    modifier onlyOwner() {
        if (owner != msg.sender) revert NotContractOwner(msg.sender);
        _;
    }

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

    function setOwner(address _owner) external override onlyOwner {
        owner = _owner;
        emit OwnerChanged(address(this), owner, _owner, block.timestamp);
    }

    function setFee(uint32 _feeBasisPoints) external override onlyOwner {
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
        override
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
    function setbullaThreshold(uint32 _threshold) external override onlyOwner {
        feeInfo.bullaTokenThreshold = _threshold;
        emit FeeThresholdChanged(
            address(this),
            feeInfo.bullaTokenThreshold,
            _threshold,
            block.timestamp
        );
    }

    //reduced fee if threshold of BULLA tokens owned is met
    function setReducedFee(uint32 reducedFeeBasisPoints)
        external
        override
        onlyOwner
    {
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
        override
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
    function getBullaBalance(address _holder)
        public
        view
        override
        returns (uint256)
    {
        uint256 balance = address(bullaToken) == address(0)
            ? 0
            : bullaToken.balanceOf(_holder);
        return balance;
    }

    function getFeeInfo(address _holder)
        public
        view
        override
        returns (uint32, address)
    {
        uint256 bullaTokenBalance = getBullaBalance(_holder);
        uint32 fee = feeInfo.bullaTokenThreshold > 0 &&
            bullaTokenBalance >= feeInfo.bullaTokenThreshold
            ? feeInfo.reducedFeeBasisPoints
            : feeInfo.feeBasisPoints;

        return (fee, feeInfo.collectionAddress);
    }

    function getTransactionFee(address _holder, uint paymentAmount) external view override returns(address sendFeesTo, uint transactionFee){
        (uint32 fee, address collectionAddress ) = getFeeInfo(_holder);
        sendFeesTo = collectionAddress;
        transactionFee = fee > 0 ? (paymentAmount * fee) / 10000 : 0;
    }
}
