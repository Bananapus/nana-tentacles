# Bananapus Tentacles + Lock Manager

`BPLockManager.sol` manages the locking of staked 721 tokens and and manages a `BPTentacleToken.sol` – an ERC-20 token contract with additional functionality allowing its designated lock manager to mint and burn tokens.

### BPLockManager

`BPLockManager` manages "tentacles", which are essentially representations of staked tokens. It provides functionality to create, destroy, and check the status of these tentacles.

The contract interacts with a [staking delegate](https://github.com/Bananapus/bananapus-721-staking-delegate), which is a contract that manages the staking of tokens. The lock manager provides hooks that are called by the staking delegate upon token registration and redemption.

`BPLockManager` allows the owner to set the configuration for each tentacle, including the tentacle implementation and a default helper.

### BPTentacleToken

`BPTentacleToken` is a standard ERC20 token which designates a lock manager, which is the only address authorized to mint and burn tokens. Only the lock manager can mint new tokens and burn existing tokens.

## Install

For `npm` projects (recommended):

```bash
npm install @bananapus/tentacles
```

For `forge` projects (not recommended):

```bash
forge install Bananapus/nana-tentacles
```

Add `@bananapus/tentacles/=lib/nana-tentacles/` to `remappings.txt`. You'll also need to install `nana-tentacles`' dependencies and add similar remappings for them.

## Develop

`nana-tentacles` uses [npm](https://www.npmjs.com/) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
npm install && forge install
```

If you run into trouble with `forge install`, try using `git submodule update --init --recursive` to ensure that nested submodules have been properly initialized.

Some useful commands:

| Command               | Description                                         |
| --------------------- | --------------------------------------------------- |
| `forge build`         | Compile the contracts and write artifacts to `out`. |
| `forge fmt`           | Lint.                                               |
| `forge test`          | Run the tests.                                      |
| `forge build --sizes` | Get contract sizes.                                 |
| `forge coverage`      | Generate a test coverage report.                    |
| `foundryup`           | Update foundry. Run this periodically.              |
| `forge clean`         | Remove the build artifacts and cache directories.   |

To learn more, visit the [Foundry Book](https://book.getfoundry.sh/) docs.

## Scripts

For convenience, several utility commands are available in `package.json`.

| Command                           | Description                            |
| --------------------------------- | -------------------------------------- |
| `npm test`                        | Run local tests.                       |
| `npm run coverage`                | Generate an LCOV test coverage report. |
| `npm run deploy:ethereum-mainnet` | Deploy to Ethereum mainnet             |
| `npm run deploy:ethereum-sepolia` | Deploy to Ethereum Sepolia testnet     |
| `npm run deploy:optimism-mainnet` | Deploy to Optimism mainnet             |
| `npm run deploy:optimism-testnet` | Deploy to Optimism testnet             |
