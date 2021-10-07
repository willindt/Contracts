# Recovery Protocol Contracts

This multi part smart contract deploys, functions and verifies correctly on BSCscan.

It allows adding BNB via the 'distributeDividends' function, which maps the rewards to the users which have been set with the 'setBalances' function.

Then when a holder of the Recovery Protocol token claims - they receive the right distribution of BNB (from what was added).

[BUSD Version](https://github.com/Triex/Dui-Contract-V2/tree/master/Recovery%20Protocol%20-%20BUSD/Contracts)

## Usage
```setBalances 0x00addr00,0x00addr01,0x00addr02 etc & numbers of holdings in the same format 100000,50000,35000 etc```
