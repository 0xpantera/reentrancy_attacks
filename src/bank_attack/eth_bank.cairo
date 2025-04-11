// Library imports
use starknet::ContractAddress;

// Definition of interface of Bank
#[starknet::interface]
pub trait IBank<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, receiver: ContractAddress, amount: u256);
    fn get_balance(self: @TContractState) -> u256;
}

// Definition of callback interface
#[starknet::interface]
trait ICustomer<TContractState> {
    fn send_to_different_customer(ref self: TContractState) -> bool;
}

#[starknet::contract]
mod Bank {
    // Library imports
    use starknet::{get_contract_address, get_caller_address, ContractAddress};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{ICustomerDispatcher, ICustomerDispatcherTrait};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
    
    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>, // Balances of the accounts
        currency: IERC20Dispatcher, // The token to be used as currency
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, currency: ContractAddress) {
        self.currency.write(IERC20Dispatcher { contract_address: currency });
    }

    // Implementation of the IBank interface
    #[abi(embed_v0)]
    impl IBankImpl of super::IBank<ContractState> {
        // Deposit function to deposit currency token from caller to the bank
        fn deposit(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let balance = self.balances.read(caller);
            // Add the amount to the balance of the caller
            self.balances.write(caller, balance + amount);
            // Transfer the currency from the caller to the bank
            self.currency.read().transfer_from(caller, get_contract_address(), amount);
        }

        // Withdraw function to withdraw currency token from the bank to the receiver
        fn withdraw(ref self: ContractState, receiver: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let balance = self.balances.read(caller);
            // Check if the caller has enough balance
            assert(balance >= amount, 'Not enough balance');

            // Callback to customer contract to check if the caller want to send money to different user
            if receiver != caller {
                let customer_dispatcher = ICustomerDispatcher { contract_address: caller };
                // @audit-issue Not following the CEI pattern, making an external call to the caller
                // Expecting `true`` from the callback
                assert(customer_dispatcher.send_to_different_customer(), 'Wrong receiver');
            }

            // Transfer the currency from the bank to the receiver
            self.currency.read().transfer(receiver, amount);
            // Decrease the balance of the caller
            // @audit-issue Reentrancy vulnerability, we change the state after 2 external calls
            self.balances.write(caller, balance - amount);
        }

        // Get the balance of the caller to find out how much currency token the caller has deposited
        fn get_balance(self: @ContractState) -> u256 {
            return self.balances.read(get_caller_address());
        }
    }
}
