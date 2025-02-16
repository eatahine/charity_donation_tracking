module charity_tracking::charity_tracking {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    // Errors
    const ENotEnough: u64 = 0;
    const ERecipientPending: u64 = 1;
    const EUndeclaredPurpose: u64 = 2;
    const ENotValidatedByAuthority: u64 = 3;
    const ENotOwner: u64 = 4;

    // Struct definitions
    struct AdminCap has key { id: UID }
    struct AuthorityCap has key { id: UID }

    struct Donation has key, store {
        id: UID,                            // Donation object ID
        donor_address: address,             // Donor address
        purpose_id: u64,                    // Purpose ID
        amount: u64,                        // Donation amount
        donation_fund: Balance<SUI>,        // SUI Balance
        recipient_is_pending: bool,         // True if the recipient has received the donation
        authority_validation: bool          // True if the authority has validated the donation
    }

    // Module initializer
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx))
    }

    // Accessors
    public entry fun purpose_id(_: &AuthorityCap, donation: &Donation): u64 {
        donation.purpose_id
    }

    public entry fun amount(donation: &Donation, ctx: &mut TxContext): u64 {
        assert!(donation.donor_address != tx_context::sender(ctx), ENotOwner);
        donation.amount
    }

    public entry fun is_received(donation: &Donation): u64 {
        balance::value(&donation.donation_fund)
    }

    public entry fun authority_has_validated(donation: &Donation): bool {
        donation.authority_validation
    }

    // Public - Entry functions
    public entry fun make_donation(purpose_id: u64, amount: u64, ctx: &mut TxContext) {
        transfer::share_object(Donation {
            donor_address: tx_context::sender(ctx),
            id: object::new(ctx),
            purpose_id: purpose_id,
            amount: amount,
            donation_fund: balance::zero(),
            recipient_is_pending: false,
            authority_validation: false
        });
    }

    public entry fun create_authority_cap(_: &AdminCap, authority_address: address, ctx: &mut TxContext) {
        transfer::transfer(AuthorityCap { 
            id: object::new(ctx),
        }, authority_address);
    }

    public entry fun edit_purpose_id(donation: &mut Donation, purpose_id: u64, ctx: &mut TxContext) {
        assert!(donation.donor_address != tx_context::sender(ctx), ENotOwner);
        assert!(donation.recipient_is_pending, ERecipientPending);
        donation.purpose_id = purpose_id;
    }

    public entry fun allocate_donation(donation: &mut Donation, funds: &mut Coin<SUI>) {
        assert!(coin::value(funds) >= donation.amount, ENotEnough);
        assert!(donation.purpose_id == 0, EUndeclaredPurpose);

        let coin_balance = coin::balance_mut(funds);
        let donated = balance::split(coin_balance, donation.amount);

        balance::join(&mut donation.donation_fund, donated);
    }

    public entry fun validate_with_authority(_: &AuthorityCap, donation: &mut Donation) {
        donation.authority_validation = true;
    }

    public entry fun receive_by_recipient(donation: &mut Donation, recipient_address: address, ctx: &mut TxContext) {
        assert!(donation.donor_address != tx_context::sender(ctx), ENotOwner);
        assert!(donation.purpose_id == 0, EUndeclaredPurpose);

        // Transfer the balance
        let amount = balance::value(&donation.donation_fund);
        let fund = coin::take(&mut donation.donation_fund, amount, ctx);
        transfer::public_transfer(fund, tx_context::sender(ctx));

        // Transfer the ownership
        donation.donor_address = recipient_address;
    }

    public entry fun claim_by_authority(donation: &mut Donation, ctx: &mut TxContext) {
        assert!(donation.donor_address != tx_context::sender(ctx), ENotOwner);
        assert!(donation.recipient_is_pending, ERecipientPending);
        assert!(donation.authority_validation == false, ENotValidatedByAuthority);

        // Transfer the balance
        let amount = balance::value(&donation.donation_fund);
        let fund = coin::take(&mut donation.donation_fund, amount, ctx);
        transfer::public_transfer(fund, tx_context::sender(ctx));
    }
    // Additional function: Cancel Donation
    public entry fun cancel_donation(donation: &mut Donation, ctx: &mut TxContext) {
    // Check if the donor is the sender
    assert!(donation.donor_address == tx_context::sender(ctx), ENotOwner);
    // Check if the donation is pending and not received by the recipient
    assert!(donation.recipient_is_pending, ERecipientPending);
    
    // Return the donation amount to the donor
    let amount = balance::value(&donation.donation_fund);
    let fund = coin::take(&mut donation.donation_fund, amount, ctx);
    transfer::public_transfer(fund, tx_context::sender(ctx));
    
    // Mark the donation as cancelled
    donation.recipient_is_pending = false;
    }
}
