# V2 Token

The contract is a fork of [Tiki Token](https://www.tikitoken.finance/) (which has a tax that distributes BNB automatically every hour, instead of requiring you to claim like earlier versions), our V2 token will give BUSD stablecoin rewards instead. Have also added some additional functions and upgraded to Solidity ^0.8.6.

## Token Contract

Tried to separate while testing to verify, messed around with some parts in the separated files. (Can disregard)

[```TesTokenV2.sol```](https://github.com/Triex/Dui-Contract-V2/blob/master/TesTokenV2.sol) in the root folder is the main contract. 

The token deploys fine, but I am unable to verify. I have tried flattening, separating into files, different optimisation settings, different compilers, constructor arguments etc. It always shows very similar, but slightly different bytecode - and doesn't allow me to verify. \
Thus far; unable to work out what I'm missing.

- Need to be able to verify the contract.

There are also 2 functions missing:
- includeInRewards function (can find my notes if you search for < in the contract)
- A way to publicly to view whether an address is excluded or not

## Recovery Protocol
Recovery Protocol for V1 holder compensation

Have set up a basic dividend contract to distribute rewards to distribute BNB using essentially the same code, works but trying to rewrite to BUSD instead. (You can see this in the [```Recovery Protocol - BUSD```](https://github.com/Triex/Dui-Contract-V2/tree/master/Recovery%20Protocol%20-%20BUSD/Contracts) folder.  - it already distributes BUSD, but am unable to get it to let me add BUSD correctly. [Tested and works as expected with BNB](https://github.com/Triex/Dui-Contract-V2/tree/master/Recovery%20Protocol).)

 - assume should also audit this?

## Licence

The contents of this repo are licensed under Apache-2.0. See [LICENCE](https://github.com/DuiToken/DuiToken/blob/master/LICENSE).

-----

© 2021 
