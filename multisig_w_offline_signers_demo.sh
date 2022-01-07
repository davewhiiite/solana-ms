#!/bin/bash

echo "------------Step 0. Initial preparation------------"
#Official version: demo of "presigner error" that comes with creating a multisig wallet.
echo "hello world"
url="https://api.devnet.solana.com"
solana config set --url $url
echo ""

echo "------------Step 1. Creating the keypairs for the multisig------------"
# Create keypairs for the multisig
# hard-coded 2/3 multisig. Not yet extensible to 3/5, 4/9, 7/12, etc.
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

echo "------------Step 2. Setting up the fee payer account, which is signer1.json keypair by default------------"
# Set up your fee payer
feePayer=$signer1
solana airdrop 1 $signer1Pubkey
solana config set --keypair $signer1
echo ""

echo "------------Step 3. Create the multisig and wrapping some SOL------------"
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
echo amountActual
spl-token transfer --fund-recipient $wSOLTokenAddress $amountActual $multisigAddress
echo "check the balance multisig"
spl-token accounts --owner $multisigAddress
echo "check the balance owner1"
spl-token accounts --owner $signer1Pubkey
echo ""

echo "------------Step 4. Creating and setting up the nonce account------------"
# create a nonce account for handling offline signing, and coordinating blockhash of the multisig account
echo "creating and funding the nonce account with 0.1 SOL"
nonceAccount="nonce-keypair.json"
solana-keygen new --no-bip39-passphrase -o $nonceAccount
nonceAccountPubkey=`solana-keygen pubkey $nonceAccount`
solana create-nonce-account $nonceAccount 0.1

# more nonce configuration setup
blockhash=`solana nonce-account $nonceAccountPubkey | grep blockhash | xargs -n 1 | tail -n -1`
echo "blockhash: $blockhash"
nonceAuthority=$signer1
echo "nonceAuthority: $nonceAuthority"
nonceAuthorityPubkey=`solana-keygen pubkey $nonceAuthority`
echo "nonceAuthorityPubkey: $nonceAuthorityPubkey"
mintDecimals=9
echo ""

echo "------------Step 5. Sending WrappedSOL from multisig to signer2------------"
### This section is the multisig transfer with offline signature scheme
# initialize
# Replaced $recipientTokenAddress with $signer2Pubkey, for this added --recipient-is-ata-owner and --allow-unfunded-recipient
echo "iniatizing the transaction"
spl-token transfer $wSOLTokenAddress $amountActual $signer2Pubkey \
--fund-recipient \
--recipient-is-ata-owner \
--sign-only \
--blockhash $blockhash \
--owner $multisigAddress \
--mint-decimals $mintDecimals \
--multisig-signer $signer1Pubkey \
--multisig-signer $signer2Pubkey \
--nonce $nonceAccountPubkey \
--nonce-authority $nonceAuthorityPubkey
 # | grep "=" | tr -d [:space:]`

# first signature
echo "obtaining first signature"
signature1=`spl-token transfer $wSOLTokenAddress $amountActual $signer2Pubkey \
--fund-recipient \
--recipient-is-ata-owner \
--sign-only \
--blockhash $blockhash \
--owner $multisigAddress \
--mint-decimals $mintDecimals \
--multisig-signer $signer1 \
--multisig-signer $signer2Pubkey \
--nonce $nonceAccountPubkey \
--nonce-authority $nonceAuthorityPubkey | grep "=" | tail -n -1 | tr -d [:space:]`
echo $signature1
echo ""

#2nd signature
echo "obtaining second signature"
signature2=`spl-token transfer $wSOLTokenAddress $amountActual $signer2Pubkey \
--fund-recipient \
--recipient-is-ata-owner \
--sign-only \
--blockhash $blockhash \
--owner $multisigAddress \
--mint-decimals $mintDecimals \
--multisig-signer $signer1Pubkey \
--multisig-signer $signer2 \
--nonce $nonceAccountPubkey \
--nonce-authority $nonceAuthorityPubkey | grep "=" | tail -n -1 | tr -d [:space:]`
echo $signature2
echo ""

# broadcast the transaction
echo "commencing multisig transfer:"
spl-token transfer $wSOLTokenAddress $amountActual $signer2Pubkey \
--fund-recipient \
--allow-unfunded-recipient \
--blockhash $blockhash \
--owner $multisigAddress \
--multisig-signer $signer1Pubkey \
--multisig-signer $signer2Pubkey \
--nonce $nonceAccountPubkey \
--nonce-authority $nonceAuthorityPubkey \
--signer $signature1 \
--signer $signature2

## println to console for debug ;)
# echo "nonceAccountPubkey: $nonceAccountPubkey"
# echo "nonceAuthorityPubkey: $nonceAuthorityPubkey"
# echo "signer1Pubkey: $signer1Pubkey"
# echo "signer2Pubkey: $signer2Pubkey"
# echo "signer3Pubkey: $signer3Pubkey"
# echo "recipientTokenAddress: $recipientTokenAddress"

echo "wrapped sol has been sent."
echo ""

echo "------------Step 6.unwrap WrappedSOL and get native SOLs------------"
### --- SPL multisig transfer is done now. Below is just unwrapping it to native SOL ---
# Unwrap part 1: need the associated token address for the recipient wrapped SOL:
spl-token accounts --owner $multisigAddress
spl-token accounts --owner $signer1Pubkey
spl-token accounts --owner $signer2Pubkey

SPLAccountAddress=`spl-token account-info $wSOLTokenAddress $signer2Pubkey | grep Address | xargs -n 1 | tail -n -1`
spl-token account-info $wSOLTokenAddress $signer2Pubkey

# Unwrap part 2: unwrap the SOL to native SOL:
spl-token unwrap $SPLAccountAddress $signer2

echo "displaying final balance in native SOL for ${signer2}"
solana balance $signer2Pubkey

echo "displaying final balance in native SOL for ${signer1}"
solana balance $signer1Pubkey