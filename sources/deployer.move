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
        symbol: String,
        decimals: u8,
        total_supply: u64,
        icon: String,
        project: String
    ) {        
        // only allowed after the deployer is initialized
        assert!(exists<Config>(@deployer), ERROR_INVALID_ACCOUNT);
        // for some reason this fails because APT isnt upto-date with the CoinLookup
        // assert!(
        //     primary_fungible_store::balance<Metadata>(signer::address_of(deployer), *option::borrow(&coin::paired_metadata<AptosCoin>())) >= borrow_global<Config>(@deployer).fee,
        //     ERROR_INSUFFICIENT_BALANCE
        // );

        let deployer_addr = signer::address_of(deployer);
        let constructor_ref = &object::create_named_object(deployer, *string::bytes(&symbol));
        
        // Create the FA's Metadata with your name, symbol, icon, etc.
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            name,
            symbol,
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

        assert!(primary_fungible_store::balance(deployer_addr, get_metadata(signer::address_of(deployer), symbol)) == total_supply, ERROR_NOT_INITIALIZED);
    }
    #[view]
    public fun get_metadata(adr: address, symbol:String): Object<Metadata> {
        let asset_address = object::create_object_address(&adr, *string::bytes(&symbol));
        object::address_to_object<Metadata>(asset_address)
    }
    // fun collect_fee(deployer: &signer) acquires Config {
    //     let config = borrow_global_mut<Config>(@deployer);
    //     primary_fungible_store::transfer(deployer,object::address_to_object<Metadata>(@aptos_framework),  config.owner, config.fee);
    // }
    #[view]
    public fun get_asset_address(owner_address: address, symbol: String) : address{
        object::create_object_address(&owner_address, *string::bytes(&symbol))
    }
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

    #[test(aptos_framework = @0x1, user = @0x123, deployer = @deployer)]
    fun test_deploy(deployer: &signer, user: signer){
        init(deployer, 1, signer::address_of(deployer));
        generate_asset(
            &user,
            string::utf8(b"HELLO"),
            string::utf8(b"HELL"),
            8,
            69,
            string::utf8(b"www.hello.com/"),
            string::utf8(b"www.hello.com/")
        );
        let asset_address = get_asset_address(signer::address_of(&user), string::utf8(b"HELL"));
        assert!(option::extract(&mut fungible_asset::supply(object::address_to_object<Metadata>(asset_address))) == 69, 1);
    }

    #[test(aptos_framework = @0x1, deployer = @deployer, owner_address = @0x123, from = @0x696, to = @0x789)]
    fun test_transfer(deployer: &signer, owner_address: signer, from: signer, to: signer){
        init(deployer, 1, signer::address_of(deployer));
        generate_asset(
            &owner_address,
            string::utf8(b"HELLO"),
            string::utf8(b"HELL"),
            8,
            69,
            string::utf8(b"www.hello.com/"),
            string::utf8(b"www.hello.com/")
        );
        let asset_address = get_asset_address(signer::address_of(&owner_address), string::utf8(b"HELL"));
        assert!(option::extract(&mut fungible_asset::supply(object::address_to_object<Metadata>(asset_address))) == 69, 1);

        let asset_metadata = get_metadata(signer::address_of(&owner_address), string::utf8(b"HELL"));
        primary_fungible_store::transfer(&owner_address, asset_metadata, signer::address_of(&to), 1);
        
        assert!(primary_fungible_store::balance(signer::address_of(&owner_address), asset_metadata) == 68 && primary_fungible_store::balance(signer::address_of(&to), asset_metadata) == 1, 1);
    
        primary_fungible_store::transfer(&to, asset_metadata, signer::address_of(&from) , 1);
        assert!(primary_fungible_store::balance(signer::address_of(&from), asset_metadata) == 1 && primary_fungible_store::balance(signer::address_of(&to), asset_metadata) == 0, 1);
    }
}
