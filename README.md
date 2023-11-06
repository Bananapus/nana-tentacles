# Bananapus Tentacles + Lock Manager

`BPLockManager.sol` manages the locking of staked 721 tokens and and manages a `BPTentacleToken.sol` – an ERC-20 token contract with additional functionality allowing its designated lock manager to mint and burn tokens.

### BPLockManager

`BPLockManager` manages "tentacles", which are essentially representations of staked tokens. It provides functionality to create, destroy, and check the status of these tentacles.

The contract interacts with a [staking delegate](https://github.com/Bananapus/bananapus-721-staking-delegate), which is a contract that manages the staking of tokens. The lock manager provides hooks that are called by the staking delegate upon token registration and redemption.

`BPLockManager` allows the owner to set the configuration for each tentacle, including the tentacle implementation and a default helper.

### BPTentacleToken

`BPTentacleToken` is a standard ERC20 token which designates a lock manager, which is the only address authorized to mint and burn tokens. Only the lock manager can mint new tokens and burn existing tokens.

## Usage

You must have [Foundry](https://book.getfoundry.sh/) and [NodeJS](https://nodejs.dev/en/learn/how-to-install-nodejs/) to use this repo.

Install with `forge install && npm install`

If you run into trouble with nested dependencies, try running `git submodule update --init --force --recursive`.

```shell
$ forge build # Build
$ forge test # Run tests
$ forge fmt # Format
$ forge snapshot # Gas Snapshots
```

For help, see https://book.getfoundry.sh/ or run:

```shell
$ forge --help
$ anvil --help
$ cast --help
```
