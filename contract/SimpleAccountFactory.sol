// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./simpleAccount.sol";

/// @title A Factory Contract for Creating SimpleAccount Instances
/// @notice This contract allows users to create and manage instances of SimpleAccount
/// @dev Uses OpenZeppelin's Create2 and ERC1967Proxy for deterministic address generation and proxy functionality
contract SimpleAccountFactory {
    SimpleAccount public immutable accountImplementation;

    mapping(address => uint) private balance;

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new SimpleAccount(_entryPoint);
    }
    function createAccount(
        address owner,
        uint256 salt
    ) public returns (SimpleAccount ret) {
        address addr = getTheAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return SimpleAccount(payable(addr));
        }
        ret = SimpleAccount(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(SimpleAccount.initialize, (owner))
                )
            )
        );
    }

    function getTheAddress(
        address owner,
        uint256 salt
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(accountImplementation),
                            abi.encodeCall(SimpleAccount.initialize, (owner))
                        )
                    )
                )
            );
    }

    function fundWallet(address account) public payable {
        balance[account] += msg.value;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balance[account];
    }
}
