# solana-ms
Adventures in multisignature schemes using solana-cli  

## License
Open source, under MIT license

## Description
Solana-ms is currently just a set of command line scripts to demonstrate
how to create a multi-signature wallet, for robust storage and retrieval
of SOL, or any SPL token, including NFTs.

## Background
Multiple-signature ("multisig") wallets and transactions, offer enhanced security
and redundancy features over those that rely on a single signature. Also known
as threshold wallets, the multisig configuration relies on having a quorum of 
signers, such as 2 out of 3, 3/5, 4/9 (m of n, generally) in order to complete a transaction.
The benefits are many, including:
* Loss of a single keypair does not result in a total loss of funds
* Theft of a single keypair does not pose an immediate risk of loss/theft
* Diversity of signers, e.g. command-line wallet + paper wallet + hardware wallet reduces the
possibility of a "retirement attack" wherein a bug in a cryptographic library, or in a hardware wallet
from a single vendor doesn't compromise the security of the wallet.
* Funds can be secured by a group of users, in a more decentralized fashion, versus held by a single user,
who in turn represents a single failure point. 

## Requirements
1. These scripts are run in a Linux / BASH environment.
2. You will need to have solana-cli installed and working in order to use the program:
[solana-cli](https://docs.solana.com/cli/install-solana-cli-tools)

## <a name="Problems"></a> Problems
It was found experimentally that it is not possible to send a native SOL token using multisig via
`solana transfer` [command](https://docs.solana.com/ru/cli/transfer-tokens#send-tokens). The multisig confirmation
can only be applied to tokens that were created by you
[personally](https://spl.solana.com/token#example-creating-your-own-fungible-token) `spl-token create-token`,
or if it is a [wrapped](https://spl.solana.com/token#example-wrapping-sol-in-a-token) SOL. 

This means you have to first wrap the native Sol into some WrappedSOL, then [transfer](https://spl.solana.com/token#example-transferring-tokens-to-another-user)
the WrappedSOL, and then unwrap it back to get the original token. 

## Implementation
The program relies on software within the [spl-token](https://spl.solana.com/token#multisig-usage) program in order 
to create a multisig wallet. This is being repurposed for storage and transfer of wrapped SOL, or any other SPL token; the program is intended to be used for
multisig control of an SPL token mint [authority](https://docs.solana.com/offline-signing/durable-nonce#nonce-authority). 

The Demo programs take SOL from a single-key wallet, [wraps](#Problems) it as an
SPL (token address = So11111111111111111111111111111111111111112), then sends to the spl-token multisig address.Finally,
to demonstrate retrieval, a signing ritual is performed to transfer the wrapped SOL from the multisig account to another account. 

## How to run
```
    $ chmod +x *.sh
    $ make online-signers-demo
    $ make clean # WARNING! deletes any keypair files in the current directory (rm *.json)!
    $ make offline-signers-demo
```

## Presigner error issue
You can see that in the [offline signing method](https://spl.solana.com/token#example-offline-signing-with-multisig), 
where the signatures are accumulated separately, using the --sign-only flag the result when attempting
the transfer with combined signatures fails with "presigner error" message.
Conversely, if you have all of the signatures in one place (see: multisig_w_online_signers_demo.sh),
the transaction goes through.

This problem was solved by the introduction of additional flags, which were spotted 
[here](https://github.com/solana-labs/solana-program-library/issues/1805).

## Contribute
The code here is open source, and I welcome anybody who is interested in this use case to contribute. 