script {
    use deployer::deployer;

    fun init(deployer: &signer, fee: u64, owner: address) {//change the fee accordingly
        deployer::init(deployer, fee, owner);
    }

    
}

script {
    use deployer::deployer;

    fun update_fee(deployer: &signer, new_fee: u64) {
        deployer::update_fee(deployer, new_fee);
    }
}

script {
    use deployer::deployer;

    fun update_owner(deployer: &signer, new_owner: address) {
        deployer::update_owner(deployer, new_owner);
    }
}