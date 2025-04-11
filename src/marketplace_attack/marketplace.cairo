use starknet::ContractAddress;

#[starknet::interface]
pub trait IMarketplace<TContractState> {
    fn buy_nft(ref self: TContractState, token_id: u256, amount: u256);
    fn list_nft(ref self: TContractState, token_id: u256, price: u256);
    fn delist_nft(ref self: TContractState, token_id: u256);
    fn get_currency(self: @TContractState) -> ContractAddress;
    fn get_nft_contract(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod Marketplace {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        listed_nfts: Map<u256, ContractAddress>, // NFTs listed for sale, tokenid -> owner
        nft_price: Map<u256, u256>, // Price of the NFTs, tokenid -> price
        currency: IERC20Dispatcher, // Currency used in the marketplace
        nft_contract: IERC721Dispatcher, // NFT contract
    }

    // Set the currency and NFT contract addresses upon deployment
    #[constructor]
    fn constructor(
        ref self: ContractState, 
        currency: ContractAddress, 
        nft_contract: ContractAddress
    ) {
        self.currency.write(IERC20Dispatcher { contract_address: currency });
        self.nft_contract.write(IERC721Dispatcher { contract_address: nft_contract });
    }

    // Public functions
    #[abi(embed_v0)]
    impl IMarketplaceImpl of super::IMarketplace<ContractState> {
        // Get the currency contract address used as payment token in the marketplace
        fn get_currency(self: @ContractState) -> ContractAddress {
            self.currency.read().contract_address
        }

        // Get the NFT contract address used in the marketplace
        fn get_nft_contract(self: @ContractState) -> ContractAddress {
            self.nft_contract.read().contract_address
        }

        // Buy an NFT from the marketplace
        // @param token_id: u256 - id of NFT to buy
        // @param amount: u256 - amount to pay
        fn buy_nft(ref self: ContractState, token_id: u256, amount: u256) {
            // Can't buy NFT's that are not listed for sale
            self._only_listed(token_id);
            let token_owner = self.listed_nfts.read(token_id);

            // Transfer the NFT from contract to caller, 
            // use `safe_transfer_from` to prevent loss of the NFT
            let data = array![];
            self.nft_contract.read().safe_transfer_from(
                get_contract_address(), 
                get_caller_address(), 
                token_id, 
                data.span()
            );

            // Transfer the currency to the owner of the NFT
            let price_for_nft = self.nft_price.read(token_id);
            assert(amount >= price_for_nft, 'Wrong amount sent');

            // Transfer the amount (price) to the owner of the NFT
            self.currency.read().transfer_from(
                get_caller_address(), 
                token_owner, 
                price_for_nft
            );

            // Remove the listing
            self.listed_nfts.write(token_id, 0.try_into().unwrap());
            self.nft_price.write(token_id, 0);
        }

        // List an NFT for sale
        // @param token_id: u256 - id of NFT to list
        // @param price: u256 - price to list the NFT for
        fn list_nft(ref self: ContractState, token_id: u256, price: u256) {
            // Only the owner of the NFT can list it
            let owner = self.nft_contract.read().owner_of(token_id);
            let caller = get_caller_address();
            assert(owner == caller, 'Not owner of NFT');

            // Transfer the NFT to the contract and list it
            self.nft_contract.read().transfer_from(caller, get_contract_address(), token_id);
            self.listed_nfts.write(token_id, caller);
            self.nft_price.write(token_id, price);
        }

        // Delist an NFT
        // @param token_id: u256 - id of NFT to de-list
        fn delist_nft(ref self: ContractState, token_id: u256) {
            // Can't delist NFT's that are not listed for sale
            self._only_listed(token_id);

            // Check if the caller is the one who listed the NFT
            let owner = self.listed_nfts.read(token_id);
            let caller = get_caller_address();
            assert(owner == caller, 'Not owner of NFT');

            // Delist the NFT
            self.listed_nfts.write(token_id, 0.try_into().unwrap());
            self.nft_price.write(token_id, 0);

            // Transfer the NFT back to the owner
            self.nft_contract.read().transfer_from(get_contract_address(), caller, token_id);
        }
    }

    // Private Functions
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        // Check if the NFT is listed
        fn _only_listed(self: @ContractState, token_id: u256) {
            let owner: ContractAddress = self.listed_nfts.read(token_id);
            assert(owner.is_non_zero(), 'NFT is not listed');
        }
    }
}
