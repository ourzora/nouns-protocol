// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title ProtocolRewards
/// @notice Manager of deposits & withdrawals for protocol rewards
contract MockProtocolRewards {
    /// @notice An account's balance
    mapping(address => uint256) public balanceOf;

    /// @notice An account's nonce for gasless withdraws
    mapping(address => uint256) public nonces;

    /// @notice The total amount of ETH held in the contract
    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    function deposit(
        address to,
        bytes4,
        string calldata
    ) external payable {
        balanceOf[to] += msg.value;
    }

    function depositBatch(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bytes4[] calldata,
        string calldata
    ) external payable {
        uint256 numRecipients = recipients.length;

        uint256 expectedTotalValue;

        for (uint256 i; i < numRecipients; ) {
            expectedTotalValue += amounts[i];

            unchecked {
                ++i;
            }
        }

        address currentRecipient;
        uint256 currentAmount;

        for (uint256 i; i < numRecipients; ) {
            currentRecipient = recipients[i];
            currentAmount = amounts[i];

            balanceOf[currentRecipient] += currentAmount;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Withdraw protocol rewards
    /// @param to Withdraws from msg.sender to this address
    /// @param amount Amount to withdraw (0 for total balance)
    function withdraw(address to, uint256 amount) external {
        address owner = msg.sender;

        if (amount == 0) {
            amount = balanceOf[owner];
        }

        balanceOf[owner] -= amount;

        (bool success, ) = to.call{ value: amount }("");

        require(success);
    }
}
