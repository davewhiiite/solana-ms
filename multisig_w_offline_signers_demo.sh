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

# more nonce configuration setup 
blockhash=`solana nonce-account $nonceAccountPubkey | grep blockhash | xargs -n 1 | tail -n -1`
echo "blockhash: $blockhash"
nonceAuthority=$signer1
echo "nonceAuthority: $nonceAuthority"
nonceAuthorityPubkey=`solana-keygen pubkey $nonceAuthority`
echo "nonceAuthorityPubkey: $nonceAuthorityPubkey"
mintDecimals=9
echo ""

### This section is the multisig transfer with offline signature scheme
# Currently, I believe this to be set up correctly, but results in "presigner error"
# Looking for support to fix the bug / error I am experiencing


# initialize
spl-token create-account $wSOLTokenAddress --owner $signer1Pubkey # using signer1.json
recipientTokenAddress=`spl-token account-info $wSOLTokenAddress $signer1Pubkey | grep Address | xargs -n 1 | tail -n -1 | sed 's/=/ /g' | xargs -n 1 | tail -n 1`
echo "recipientTokenAddress: $recipientTokenAddress"
echo ""
echo "iniatizing the transaction"
spl-token transfer $wSOLTokenAddress $amountActual $recipientTokenAddress \
--fund-recipient \
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
signature1=`spl-token transfer $wSOLTokenAddress $amountActual $recipientTokenAddress \
--fund-recipient \
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
signature2=`spl-token transfer $wSOLTokenAddress $amountActual $recipientTokenAddress \
--fund-recipient \
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
# Use RUST_BACKTRACE=1? How to troubleshoot the "presigner error"
#USAGE:
#    spl-token transfer <TOKEN_ADDRESS> <TOKEN_AMOUNT> <RECIPIENT_ADDRESS or RECIPIENT_TOKEN_ACCOUNT_ADDRESS> --blockhash <BLOCKHASH> --config <PATH> --from <SENDER_TOKEN_ACCOUNT_ADDRESS> --fund-recipient --mint-decimals <MINT_DECIMALS> --multisig-signer <MULTISIG_SIGNER>... --nonce <PUBKEY> --nonce-authority <KEYPAIR> --recipient-is-ata-owner --sign-only --signer <PUBKEY=SIGNATURE>...
spl-token transfer $wSOLTokenAddress $amountActual $recipientTokenAddress \
--fund-recipient \
--blockhash $blockhash \
--owner $multisigAddress \
--multisig-signer $signer1Pubkey \
--multisig-signer $signer2Pubkey \
--nonce $nonceAccountPubkey \
--nonce-authority $nonceAuthorityPubkey \
--signer $signature1 \
--signer $signature2

# println to console for debug ;)
#echo "nonceAccountPubkey: $nonceAccountPubkey"
#echo "nonceAuthorityPubkey: $nonceAuthorityPubkey"
#echo "signer1Pubkey: $signer1Pubkey"
#echo "signer2Pubkey: $signer2Pubkey"
#echo "signer3Pubkey: $signer3Pubkey"
#echo "recipient $recipient"
#echo "recipientTokenAddress: $recipientTokenAddress"

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
