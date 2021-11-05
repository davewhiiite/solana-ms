#!/bin/bash

#Official version: demo of "presigner error" that comes with creating a multisig wallet.
echo "hello world"
url="https://api.devnet.solana.com"
solana config set --url $url

# Create keypairs for the multisig
# hard-coded 2/3 multisig. Not yet extensible to 3/5, 4/9, 7/12, etc.
echo "creating the keypairs for the multisig"
for i in {1..3}
do
    solana-keygen new --no-bip39-passphrase -o signer${i}.json;
done

signer1=signer1.json
signer2=signer2.json
signer3=signer3.json
signer1Pubkey=`solana-keygen pubkey $signer1`
signer2Pubkey=`solana-keygen pubkey $signer2`
signer3Pubkey=`solana-keygen pubkey $signer3`
echo ""

# Set up your fee payer
echo "setting up the fee payer account, which is signer1.json keypair by default"
solana airdrop 1 $signer1Pubkey
feePayer=$signer1
solana config set --keypair $signer1
echo ""

# create the multisig
echo "creating the mutisig account"
multisigAddress=`spl-token create-multisig 2 $signer1Pubkey $signer2Pubkey $signer3Pubkey | grep multisig | xargs -n 1 | tail -n -1`
echo "multisigAddress: $multisigAddress"
echo ""

# Token transfer details:
amount=0.75
wSOLTokenAddress=So11111111111111111111111111111111111111112 #NOTE! Unwrap the token and it deletes the associated wSOL address!

# create some wrapped sol using the signer1 address 
echo "wrapping some SOL"
spl-token wrap $amount $signer1
echo "sending wrapped sol to $multisigAddress"
amountActual=`spl-token accounts | grep $wSOLTokenAddress | xargs -n 1 | tail -n -1`
spl-token transfer --fund-recipient $wSOLTokenAddress $amountActual $multisigAddress
echo "check the balance"
spl-token accounts --owner $multisigAddress
echo ""

# create a nonce account for handling offline signing, and coordinating blockhash of the multisig account
echo "creating and funding the nonce account with 0.1 SOL"
nonceAccount="nonce-keypair.json"
solana-keygen new --no-bip39-passphrase -o $nonceAccount 
nonceAccountPubkey=`solana-keygen pubkey $nonceAccount`
solana create-nonce-account $nonceAccount 0.1


# Final recipient of the wrapped SOL (sent from the multisig):
recipient=$signer1Pubkey

# more nonce configuration setup
blockhash=`solana nonce-account $nonceAccountPubkey | grep blockhash | xargs -n 1 | tail -n -1`
echo "blockhash: $blockhash"
nonceAuthority=$signer1
echo "nonceAuthority: $nonceAuthority"
nonceAuthorityPubkey=`solana-keygen pubkey $nonceAuthority`
echo "nonceAuthorityPubkey: $nonceAuthorityPubkey"
mintDecimals=9
echo ""

# broadcast the transaction
echo "commencing multisig transfer:"
### This multisig signing and transfer method works, but requires all keypairs 
# to be present during signing.
spl-token transfer $wSOLTokenAddress $amountActual $recipient \
--owner $multisigAddress \
--multisig-signer $signer1 \
--multisig-signer $signer2 \
--blockhash $blockhash \
--fee-payer $signer1 \
--nonce $nonceAccountPubkey \
--nonce-authority $nonceAuthority
echo "wrapped sol has been sent."
echo ""

### --- SPL multisig transfer is done now. Below is just unwrapping it to native SOL ---
#
# Unwrap part 1: need the associated token address for the recipient wrapped SOL:
echo "displaying the SPL token balance for $signer1"
spl-token accounts # for $signer1 keypair
SPLAccountAddress=`spl-token account-info $wSOLTokenAddress $recipient | grep Address | xargs -n 1 | tail -n -1`

# Unwrap part 2: unwrap the SOL to native SOL:
spl-token unwrap $SPLAccountAddress

echo "displaying final balance in native SOL for ${signer1}, address $recipient"
solana balance $recipient
echo ""

echo "Demonstration complete: multisig wallet was created, round-trip wrapped sol transfer completed using Solana spl-token program."  
