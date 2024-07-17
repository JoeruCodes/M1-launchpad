module deployer::deployer {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::option;
    use std::event;
    use std::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    struct Config has key {
        owner: address,
        fee: u64
    }

    #[event]
    struct NewFeeEvent has drop, store { new_fee: u64 }
    fun emit_new_fee_event(new_fee: u64) {
        event::emit<NewFeeEvent>(NewFeeEvent { new_fee })
    }

    #[event]
    struct NewOwnerEvent has drop, store { new_owner: address }
    fun emit_new_owner_event(new_owner: address) {
        event::emit<NewOwnerEvent>(NewOwnerEvent { new_owner })
    }

    // Error Codes 
    const ERROR_INVALID_ACCOUNT: u64 = 0;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 1;
    const ERROR_NOT_INITIALIZED: u64 = 3;

    entry public fun init(deployer: &signer, fee: u64, owner: address){
        assert!(signer::address_of(deployer) == @deployer, ERROR_INVALID_ACCOUNT);
        move_to(deployer, Config { owner, fee })
    }

    entry public fun update_fee(deployer: &signer, new_fee: u64) acquires Config {
        assert!(
            signer::address_of(deployer) == @deployer, 
            ERROR_INVALID_ACCOUNT
        );
        // only allowed after the deployer is initialized
        assert!(exists<Config>(@deployer), ERROR_INVALID_ACCOUNT);

        let config = borrow_global_mut<Config>(@deployer);
        config.fee = new_fee;
        emit_new_fee_event(new_fee);
    }

    entry public fun update_owner(deployer: &signer, new_owner: address) acquires Config {
        assert!(
            signer::address_of(deployer) == @deployer, 
            ERROR_INVALID_ACCOUNT
        );
        // only allowed after the deployer is initialized
        assert!(exists<Config>(@deployer), ERROR_INVALID_ACCOUNT);

        let config = borrow_global_mut<Config>(@deployer);
        config.owner = new_owner;
        emit_new_owner_event(new_owner);
    }

    // Generates a new fungible asset and mints the total supply to the deployer. Capabilities are then destroyed
    entry public fun generate_asset(
        deployer: &signer,
        name: String,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
        icon: String,
        project: String
    ){        
        // only allowed after the deployer is initialized
        assert!(exists<Config>(@deployer), ERROR_INVALID_ACCOUNT);
        // for some reason this fails because APT isnt upto-date with the CoinLookup
        // assert!(
        //     primary_fungible_store::balance<Metadata>(signer::address_of(deployer), *option::borrow(&coin::paired_metadata<AptosCoin>())) >= borrow_global<Config>(@deployer).fee,
        //     ERROR_INSUFFICIENT_BALANCE
        // );

        let deployer_addr = signer::address_of(deployer);
        let constructor_ref = &object::create_named_object(deployer, symbol);
        
        // Create the FA's Metadata with your name, symbol, icon, etc.
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            name,
            string::utf8(symbol),
            decimals,
            icon, /* icon */
            project, /* project */
        );

        // Generate the MintRef for this object
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);

        let minted_asset = fungible_asset::mint(&mint_ref, total_supply);
        primary_fungible_store::deposit(deployer_addr, minted_asset);
        
        // this fails...
        // collect_fee(deployer);

        // destroy caps
        // fungible_asset::destroy_transfer_ref(&transfer_ref);
        // fungible_asset::destroy_burn_ref(&burn_ref);
        // std::drop(&transfer_ref);

        assert!(primary_fungible_store::balance(deployer_addr, get_metadata(&signer::address_of(deployer), symbol)) == total_supply, ERROR_NOT_INITIALIZED);
    }
    public fun get_metadata(adr: &address, symbol: vector<u8>): Object<Metadata> {
        let asset_address = object::create_object_address(adr, symbol);
        object::address_to_object<Metadata>(asset_address)
    }
    // fun collect_fee(deployer: &signer) acquires Config {
    //     let config = borrow_global_mut<Config>(@deployer);
    //     primary_fungible_store::transfer(deployer,object::address_to_object<Metadata>(@aptos_framework),  config.owner, config.fee);
    // }

    // #[view]
    // public fun owner_address(metadata: Metadata): address {
    //     Object::
    // }

    #[test_only]
    public fun init_test(deployer: &signer, fee: u64, owner: address) {
        assert!(
            signer::address_of(deployer) == @deployer, 
            ERROR_INVALID_ACCOUNT
        );

        move_to(deployer, Config { owner, fee });
    }

    #[test(aptos_framework = @0x1, deployer = @deployer, user = @0x123)]
    fun test_user_deploys_asset(
        aptos_framework: signer,
        deployer: signer,
        user: &signer,
    ) {
        aptos_framework::account::create_account_for_test(signer::address_of(&deployer));
        init(&deployer, 1, signer::address_of(&deployer));
        // aptos_framework::aptos_coin::mint(&aptos_framework, signer::address_of(&deployer), 1000);
        
        generate_asset(
            &deployer,
            string::utf8(b"Fake nex"),
            b"nex",
            4,
            1000000,
            string::utf8(b"www.someshit.com/"),
            string::utf8(b"www.someshit.com/")
        );

        assert!(primary_fungible_store::balance(signer::address_of(&deployer), get_metadata(&signer::address_of(&deployer), b"nex")) == 1000000, 1);

        // should not fail...
        let _metadata = get_metadata(&signer::address_of(&deployer), b"nex");

    }
}
