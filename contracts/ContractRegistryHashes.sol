// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

abstract contract ContractRegistryHashes {

    error OnlyRouter();
    error OnlyTreasury();
    error OnlyRealmGuardian();
    error OnlyStakingManager();
    error OnlyStakingManagerOrTokenCollector();
    error OnlyRewardDistributor();
    error OnlyCoinMaster();
    error OnlyTokenCollector();

    error METFINotWithdrawable();

    error InvalidContractAddress();

    bytes32 constant internal MFI_HASH = 0xab12ee3d83a34822ca77656b4007d61405e0029c8476890a3303aabb7a0a3d26; // keccak256(abi.encodePacked('mfi'))
    bytes32 constant internal METFI_HASH = 0xc30505a9c296d74a341270378602ace8341352e684fc4f8fbf4bf9aa16ddffca; // keccak256(abi.encodePacked('metfi'))

    bytes32 constant internal ROUTER_HASH = 0x5f6d4e9bb70c9d2aa50e18560b4cdd1b23b30d62b60873d5f23b103e5d7d0185;// keccak256(abi.encodePacked('router'))
    bytes32 constant internal TREASURY_HASH = 0xcbd818ad4dd6f1ff9338c2bb62480241424dd9a65f9f3284101a01cd099ad8ac; // keccak256(abi.encodePacked('treasury'))
    bytes32 constant internal METFI_VAULT_HASH = 0xacb5ae4bf471c8110adaac4702c4177629bf32af63ad6f68f546ac2fcd039e77; // keccak256(abi.encodePacked('metfi_vault'))
    bytes32 constant internal USER_CONFIG_HASH = 0x5e1885a4b18649f87409858a77d00e281ce6dd4507e43dc706a2d703d71aeb71; // keccak256(abi.encodePacked('user_config'))
    bytes32 constant internal ACCOUNT_TOKEN_HASH = 0xc5d51c4d622df5dca71195c62129359a2e761a24b2789b5a40667736c682f30f; // keccak256(abi.encodePacked('account_token'))
    bytes32 constant internal PLATFORM_VIEW_HASH = 0xd58c1d29f4951cf40818a252966d0f0711896e43c86ba803ffa9841180d7bca1; // keccak256(abi.encodePacked('platform_view'))
    bytes32 constant internal UNSTAKED_NFTS_HASH = 0x2d006620d1c948b883dc3097193eb76c239d12828bb85beea39994af1ecefb65; // keccak256(abi.encodePacked('unstaked_nfts'))
    bytes32 constant internal STAKING_MANAGER_HASH = 0x9518d9bd94df3303f323b9a5b2289cf4e06524a698aef176fcc9590318226540; // keccak256(abi.encodePacked('staking_manager'))
    bytes32 constant internal TOKEN_COLLECTOR_HASH = 0x66c4b93ccf2bde8d7ba39826420a87af960e88acb070c754e53aba0b8e51c02c; // keccak256(abi.encodePacked('token_collector'))
    bytes32 constant internal BURN_CONTROLLER_HASH = 0xa4636fb16cea2aa5153c9be70618a6afb5cefe7a593eeee2cfab523b8c195a73;  // keccak256(abi.encodePacked('burn_controller'))
    bytes32 constant internal REWARD_CONVERTER_HASH = 0xb7e5e8f89e319d42882d379ecafd17e93606cf39a2079af36730958267667728; // keccak256(abi.encodePacked('reward_converter'))
    bytes32 constant internal METFI_STAKING_POOL_HASH = 0x3d9cfbe20d3d50006bd02e057e662d569da593b764b8b8f923d3d313f2422b10;// keccak256(abi.encodePacked('metfi_staking_pool'))
    bytes32 constant internal REWARD_DISTRIBUTOR_HASH = 0x8d3e9afdbbce76f0b889c4bff442796e82871c8eccf3c648a01e55e080d66a49; // keccak256(abi.encodePacked('reward_distributor'))
    bytes32 constant internal PRIMARY_STABLECOIN_HASH = 0x0876039741972003251072838c80c5b1e815c7b3ed2e3b01411c485fec477ecc; // keccak256(abi.encodePacked('primary_stablecoin'))
    bytes32 constant internal ACTION_FUNCTIONS_HASH = 0x0970951b7db2cc0a769d9e3cb477e212250909cab0d2468854bafd755326bb7b; // keccak256(abi.encodePacked('action_functions'))
    bytes32 constant internal NFT_TRANSFER_PROXY_HASH = 0xbd165d9953042246fb908ee4e3ee644fbe1e3fe22c7d6830d417bdcece5d273b; // keccak256(abi.encodePacked('nft_transfer_proxy'))
    bytes32 constant internal STAR_ACHIEVERS_HASH = 0x22a6d61b8441b8b48421128668229a04c572ac6018e721043359db05f33c151b; // keccak256(abi.encodePacked('star_achievers'))

    bytes32 constant internal LENDING_HASH = 0x16573015d5a4b6fc6913a13e8c047a772cc654c00c338536ccaa33e7fe263be9; // keccak256(abi.encodePacked('lending'))
    bytes32 constant internal LENDING_VIEW_HASH = 0xc74a7251498f700c757f7d9bedf70846e0808d0cfd266d18ff796d603e58ef42; // keccak256(abi.encodePacked('lending_view'))
    bytes32 constant internal LOAN_LIMITER_HASH = 0x840de5598c4c00225a8bc33abacc176aa8dc32e156f7069560dd186d8c08e83e; // keccak256(abi.encodePacked('loan_limiter'))
    bytes32 constant internal LENDING_AUCTION_HASH = 0x315a584ec231dc4ba7bfc5a8f8efed9f1d7f61fe4c54746decfc19ddd199a7c8; // keccak256(abi.encodePacked('lending_auction'))
    bytes32 constant internal LENDING_CHECKER_HASH = 0xd0beb74e409a61d00092877bb21f2e1b99afa0fb5b69fded573ce9d20f6426ee; // keccak256(abi.encodePacked('lending_checker'))
    bytes32 constant internal LENDING_CALCULATOR_HASH = 0xc8f991caa4a50f2a548f7cb4ae682c6276c4479baa4474b270262f1cf7ef0d13; // keccak256(abi.encodePacked('lending_calculator'))
    bytes32 constant internal LENDING_EXTENSION_CONTROLLER_HASH = 0x575b99354279563b4b104af43b2bd3663850df86e34a2a754269a4a55a0c1afd; // keccak256(abi.encodePacked('lending_extension_controller'))

    bytes32 constant internal PANCAKE_ROUTER_HASH = 0xd8ed703341074e5699af5f26d9f38498fb901a7519f08174cfb1baf7b5ecbff9; // keccak256(abi.encodePacked('pancake_router'))
    bytes32 constant internal COMMUNITY_MANAGER_PAYOUT_CONTROLLER_HASH = 0x8e4bf4954dca9b537539c95d84bafae4fccf02da2ae09493581b7e530f914a17; // keccak256(abi.encodePacked('community_manager_payout_controller'))

}
