use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,  
    start_cheat_caller_address, stop_cheat_caller_address,
};
use reentrancy_attacks::bank_attack::eth_bank::{IBankDispatcher, IBankDispatcherTrait};
use reentrancy_attacks::utils::helpers::{
    deploy_eth, mint_erc20, one_ether,
};

// Helper function to deploy the Bank contract
fn deploy_bank(currency: ContractAddress) -> (ContractAddress, IBankDispatcher) {
    // Declaring the contract class
    let contract_class = declare("Bank").unwrap().contract_class();
    // Creating the data to send to the constructor, first specifying as a default value
    let mut data_to_constructor = Default::default();
    // Pack the data into the constructor
    Serde::serialize(@currency, ref data_to_constructor);
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();
    (address, IBankDispatcher { contract_address: address })
}


#[test]
fn test_reentrancy_1() {
    // Creating the addresses of Alice, Bob, and Attacker
    let alice: ContractAddress = 1.try_into().unwrap();
    let bob: ContractAddress = 2.try_into().unwrap();
    let attacker: ContractAddress = 3.try_into().unwrap();

    // Deploying the ETH and Bank contracts
    let (eth_address, eth_dispatcher) = deploy_eth();
    let (bank_address, bank_dispatcher) = deploy_bank(eth_address);

    // Mint 10 ETH to Alice, 20 ETH to Bob, and 1 ETH to Attacker
    mint_erc20(eth_address, alice, 10 * one_ether());
    mint_erc20(eth_address, bob, 20 * one_ether());
    mint_erc20(eth_address, attacker, one_ether());

    // Approve and deposit 10 ETH from Alice
    start_cheat_caller_address(eth_address, alice);
    eth_dispatcher.approve(bank_address, 10 * one_ether());
    stop_cheat_caller_address(eth_address);
    start_cheat_caller_address(bank_address, alice);
    bank_dispatcher.deposit(10 * one_ether());
    stop_cheat_caller_address(bank_address);

    // Approve and deposit 20 ETH from Bob
    start_cheat_caller_address(eth_address, bob);
    eth_dispatcher.approve(bank_address, 20 * one_ether());
    stop_cheat_caller_address(eth_address);
    start_cheat_caller_address(bank_address, bob);
    bank_dispatcher.deposit(20 * one_ether());
    stop_cheat_caller_address(bank_address);

    // Check that the bank has 30 ETH
    let bank_balance = eth_dispatcher.balance_of(bank_address);
    assert_eq!(bank_balance, 30 * one_ether());

    // Attack Start //
    // TODO: Steal all the ETH from the bank

    // Attack END //

    // Make sure the attack was successful (Attacker has 31 ETH, Bank has 0)
    let attacker_balance = eth_dispatcher.balance_of(attacker);
    let bank_balance = eth_dispatcher.balance_of(bank_address);
    println!("The attacker's balance is: {}", attacker_balance);
    println!("The bank's balance is: {}", bank_balance);
    assert(attacker_balance == 31 * one_ether(), 'Wrong balance of attacker');
    assert(bank_balance == 0, 'Wrong balance of bank');
}

