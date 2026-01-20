// CIRCUIT: SustainabilityCheck.circom
// PURPOSE:
//   Proves that a product satisfies sustainability constraints
//   without revealing sensitive internal data.
//   All checks must pass for `is_valid` to be 1.

pragma circom 2.0.0;
include "../circuits/circomlib/circuits/comparators.circom"; // for LessThan, GreaterEqThan
include "../circuits/circomlib/circuits/poseidon.circom"; // for Poseidon hash

template SustainabilityCheck() {
    // === PRIVATE INPUTS === 
    signal input co2_emission_g;
    signal input energy_type;
    signal input production_ts;
    signal input product_id;
    signal input product_secret;

    // === PRIVATE PARAMETERS (constraints) === 
    signal input max_co2_limit_g;
    signal input allowed_type_1;
    signal input allowed_type_2;
    signal input min_production_ts;

    // === PUBLIC OUTPUTS === 
    signal output is_valid;
    signal output out_product_hash;

    // === CHECK 1: CO2 < max_co2_limit_g === 
    component co2_cmp = LessThan(32);
    co2_cmp.in[0] <== co2_emission_g;
    co2_cmp.in[1] <== max_co2_limit_g;

    // === CHECK 2: energy_type is allowed === 
    component is_eq_type1 = IsEqual();
    component is_eq_type2 = IsEqual();
    is_eq_type1.in[0] <== energy_type;
    is_eq_type1.in[1] <== allowed_type_1;

    is_eq_type2.in[0] <== energy_type;
    is_eq_type2.in[1] <== allowed_type_2;

    signal type_allowed;
    type_allowed <== is_eq_type1.out + is_eq_type2.out;

    component is_type_valid = GreaterEqThan(2);
    is_type_valid.in[0] <== type_allowed;
    is_type_valid.in[1] <== 1;

    // === CHECK 3: production_ts >= min_production_ts === 
    component ts_cmp = GreaterEqThan(64);
    ts_cmp.in[0] <== production_ts;
    ts_cmp.in[1] <== min_production_ts;

    // === Combine all === 
    signal tmp_and;
    tmp_and <== co2_cmp.out * is_type_valid.out;

    signal passed_all;
    passed_all <== tmp_and * ts_cmp.out;

    // === Poseidon hash over product attributes ===
    component poseidonHasher = Poseidon(5);
    poseidonHasher.inputs[0] <== product_id;
    poseidonHasher.inputs[1] <== co2_emission_g;
    poseidonHasher.inputs[2] <== energy_type;
    poseidonHasher.inputs[3] <== production_ts;
    poseidonHasher.inputs[4] <== product_secret;

    is_valid <== passed_all;
    out_product_hash <== poseidonHasher.out;
}

component main = SustainabilityCheck();
