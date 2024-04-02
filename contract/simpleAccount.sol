// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;


import "../core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract SimpleAccount is BaseAccount {
    using ECDSA for bytes32;

    uint96 private _nonce;
    address public owner;

    function nonce() public view virtual override returns (uint256) {
        return _nonce;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    IEntryPoint private _entryPoint;

    event EntryPointChanged(address indexed oldEntryPoint, address indexed newEntryPoint);

    receive() external payable {}

    constructor(IEntryPoint anEntryPoint, address anOwner) {
        _entryPoint = anEntryPoint;
        owner = anOwner;
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        require(msg.sender == owner || msg.sender == address(this), "only owner");
    }

    function transfer(address payable dest, uint256 amount) external onlyOwner {
        dest.transfer(amount);
    }

    function exec(address dest, uint256 value, bytes calldata func) external onlyOwner {
        _call(dest, value, func);
    }

    function execBatch(address[] calldata dest, bytes[] calldata func) external onlyOwner {
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    function _updateEntryPoint(address newEntryPoint) internal override {
        emit EntryPointChanged(address(_entryPoint), newEntryPoint);
        _entryPoint = IEntryPoint(payable(newEntryPoint));
    }

    function _requireFromAdmin() internal view override {
        _onlyOwner();
    }

    function _requireFromEntryPoint() internal override view {
        require(msg.sender == address(entryPoint()), "account: not from EntryPoint");
    }

    // called by entryPoint, only after validateUserOp succeeded.
    function execFromEntryPoint(address dest, uint256 value, bytes calldata func) external {
        _requireFromEntryPoint();
        _call(dest, value, func);
    }

    /// implement template method of BaseAccount
    function _validateAndUpdateNonce(UserOperation calldata userOp) internal override {
        require(_nonce++ == userOp.nonce, "account: invalid nonce");
    }

    /// implement template method of BaseAccount
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash, address)
    internal override virtual returns (uint256 deadline) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        require(owner == hash.recover(userOp.signature) || tx.origin == address(0), "account: wrong signature");
        return 0;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value : value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    function addDeposit() public payable {

        (bool req,) = address(entryPoint()).call{value : msg.value}("");
        require(req);
    }

    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }
}