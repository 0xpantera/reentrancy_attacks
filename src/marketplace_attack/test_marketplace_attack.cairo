use openzeppelin_token::erc721::interface::{IERC721DispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20DispatcherTrait};
use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,  
    start_cheat_caller_address, stop_cheat_caller_address
};
use reentrancy_attacks::utils::helpers;

use reentrancy_attacks::marketplace_attack::butch_cassidy::{
    IButchCassidyDispatcher, IButchCassidyDispatcherTrait,
};

// The Marketplace Dispatcher Interface
use reentrancy_attacks::marketplace_attack::marketplace::{
    IMarketplaceDispatcher, IMarketplaceDispatcherTrait
};

// Deploy the marketplace contract, return the address and the dispatcher
fn deploy_marketplace(eth_address: ContractAddress, nft_address: ContractAddress) 
    -> (ContractAddress, IMarketplaceDispatcher) {
    // Declaring the contract class
    let contract_class = declare("Marketplace").unwrap().contract_class();
    // Creating the data to send to the constructor, first specifying as a default value
    let mut data_to_constructor = Default::default();
    // Pack the data into the constructor
    Serde::serialize(@eth_address, ref data_to_constructor);
    Serde::serialize(@nft_address, ref data_to_constructor);
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();
    return (address, IMarketplaceDispatcher { contract_address: address });
}

// Deploy the marketplace contract, return the address and the dispatcher
fn deploy_butch(
    market_address: ContractAddress, 
    nft_address: ContractAddress,
    attacker: ContractAddress
) -> (ContractAddress, IButchCassidyDispatcher) 
{
    // Declaring the contract class
    let contract_class = declare("ButchCassidy").unwrap().contract_class();
    // Creating the data to send to the constructor, first specifying as a default value
    let mut data_to_constructor = Default::default();
    // Pack the data into the constructor
    Serde::serialize(@market_address, ref data_to_constructor);
    Serde::serialize(@nft_address, ref data_to_constructor);
    Serde::serialize(@attacker, ref data_to_constructor);
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();
    return (address, IButchCassidyDispatcher { contract_address: address });
}

#[test]
fn test_marketplace_attack() {
    // Creating users addresses
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    let attacker: ContractAddress = 'attacker'.try_into().unwrap();

    // Deploying the contracts
    let (eth_address, eth_dispatcher) = helpers::deploy_eth();
    let (nft_address, nft_dispatcher) = helpers::deploy_nft();
    let (marketplace_address, marketplace_dispatcher) = deploy_marketplace(eth_address, nft_address);

    // Sanity checks
    assert(marketplace_dispatcher.get_currency() == eth_address, 'Wrong eth address');
    assert(marketplace_dispatcher.get_nft_contract() == nft_address, 'Wrong nft address');

    // Mint 3 NFTs to Alice
    helpers::mint_nft(nft_address, alice, 1);
    helpers::mint_nft(nft_address, alice, 2);
    helpers::mint_nft(nft_address, alice, 3);
    // Give 1 ETH to the attacker
    helpers::mint_erc20(eth_address, attacker, helpers::one_ether());

    // Some Sanity checks
    assert(nft_dispatcher.owner_of(1) == alice, 'Alice should own tokenId 1');
    assert(nft_dispatcher.owner_of(2) == alice, 'Alice should own tokenId 2');
    assert(nft_dispatcher.owner_of(3) == alice, 'Alice should own tokenId 3');
    assert(eth_dispatcher.balance_of(attacker) == helpers::one_ether(), 'Wrong attacker balance');

    // List NFTs START //
    // Approve the marketplace to transfer the NFTs
    start_cheat_caller_address(nft_address, alice);
    nft_dispatcher.approve(marketplace_address, 1);
    nft_dispatcher.approve(marketplace_address, 2);
    nft_dispatcher.approve(marketplace_address, 3);
    stop_cheat_caller_address(nft_address);
    // List the NFTs with the price of 1 ETH
    start_cheat_caller_address(marketplace_address, alice);
    marketplace_dispatcher.list_nft(1, helpers::one_ether());
    marketplace_dispatcher.list_nft(2, helpers::one_ether());
    marketplace_dispatcher.list_nft(3, helpers::one_ether());
    stop_cheat_caller_address(marketplace_address);
    // List NFTs END //

    // Check that the NFTs are listed
    assert(nft_dispatcher.owner_of(1) == marketplace_address, 'Wrong owner NFT');
    assert(nft_dispatcher.owner_of(2) == marketplace_address, 'Wrong owner NFT');
    assert(nft_dispatcher.owner_of(3) == marketplace_address, 'Wrong owner NFT');

    // ATTACK START //
    // Obtain all NFTs from the Marketplace

    let (
        _butch_address, 
        butch_dispatcher
    ) = deploy_butch(marketplace_address, nft_address, attacker);

    println!("About to rob the marketplace");
    butch_dispatcher.give_me_all(array![1,2,3]);
    println!("Robbery successful in theory");
   
    // ATTACK END //

    // Attacker should have all NFTs and should pay nothing for them
    assert(nft_dispatcher.owner_of(1) == attacker, 'Attacker should own tokenId 1');
    assert(nft_dispatcher.owner_of(2) == attacker, 'Attacker should own tokenId 2');
    assert(nft_dispatcher.owner_of(3) == attacker, 'Attacker should own tokenId 3');
    assert(eth_dispatcher.balance_of(attacker) == helpers::one_ether(), 'Attacker should have 1 ETH');
}

