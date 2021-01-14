# Meaning of term
1. Priceunit => Unit of collateral asset price. Strategy contract determines SBT strike price, valid shape of bond token and amount of bond to tranche using this value. When collateral asset is ETH/USDC, priceunit is $10 and when collateral asset is USDC/ETH, priceunit is $0.00001.
2. AggregatorLength => Term length of aggregator.

# Aggregator
- Receive collateral asset and issue share token (share token is ERC20)
- Issue bond token and provide liquidity for DOTC contract (DOTC is decentralized exchange of bond)
## addLiquidity()
- Send the collateral asset to provide liquidity. 
- You can run this function anytime, but the collateral asset you have provided is not used in this term as the amount of share token is not determined at this point and the amount of the collateral token in the aggregator contract in this term will not have not been unconfirmed until the end of this term.

## removeLiquidity()
- Withdraw liquidity and burn share token.
- You can run this function anytime, but the collateral asset you have provided is not returned at this point, because the amount of the collateral token in the aggregator contract in this term will not have not been confirmed until the end of this term.
- Share Token is burned at this point.

## TrancheBonds()
- Receive array of ```[bondGroupID, amount to be issued]``` and issue bond.
- The 0th of this array is the amount of collateral to be locked in the DOTC contract.
- If the amount to be issued is negative value, run ```reverseBondToCollateral``` to burn the bond and get the collateral asset.
- If the amount to be issued is positive value, run ```issueNewBonds``` to mint a new bond.

## addIssuableBondGroup()
- Add a valid bond group to issue in ```TrancheBonds()```.
- ```Strategy.isValidLBT()``` determines whether this bond group is valid to issue.
- If valid, add this bond group to the issuable bond group list and approve each bond token to DOTC contract.

## liquidateBonds()
- Burn all the bond tokens in the aggregator contract.
- Select and burn the bond tokens owned by the aggregator contract whose maturity comes at the end of the period.
- Run after maturity of this period.
- If there are too many bond groups to be processed, stop the process to avoid out-of-gas.

## renewMaturity()
- Update maturity and strike price, then set the supply of the share token.
- Determine the total supply of share token in the next period from the liquidity added/removed during this period.
- Determine the amount of the collateral asset that can be used for issuing bond tokens.
- The collateral asset that will be used in ```settleTokens``` is moved to another contract (ReserveETH or ReserveERC20).
- Determines collateral token amount per 1 share token, and this amount will be used in ```settleTokens()```

## SettleTokens()
- Settle collateral token and share token added/removed by ```addLiquidity()``` or ```removeLiquidity()```.
- If ```addLiquidity()```or ```removeLiquidity()``` was executed in the previous period, the share token balance is incremented/transferred.
- This function is called automatically when ```addLiquidity()``` or ```removeLiquidity()``` was called in the previous period.

# Strategy
- Check and add the given SBT strike price and its maturity to the issuable bond group list.
- Determine the amount of bond token to be issued in ```TrancheBond()```.
## calcMaturity
- Return the farest unix time of Friday 3 p.m UTC within 3 weeks. 
## isValidLBT()
- Check if the given bond group is issuable or not.
- Confirm the 0th bond in the bond group is SBT, 1th is Call Option, 2th is Leveraged token, 3th is Volatility short token, and whether the Volatility short token parameters is in between the valid range.
## getCurrentStrikePrice
- Determine the valid strike price for the new period.
- Calculate SBT price whose strike price is half the current price, and if the SBT value is more than 95% of its strike price, return SBT strike price.
- If not, try once more with a lower strike price.
## getTrancheBonds()
- Get the list of issuable bond groups from the aggregator contract, and determine the bond token amount to be issued/burned.
- Return positive value for the bond group whose Call option strike price is in between Current Price +- PriceUnit * 2. (Amount to supply is calculated by ```Usable collateral asset amount / 5 - balance of this bond token```)
- Return negative value for the bond group whose Call option strike price is out of the range Current Price +- PriceUnit * 5 and balance of aggregator is more than ```Usable collateral asset amount / 10```.

# Flow of aggregator
1. Before the Period
   - Run ```renewMaturity()``` to update strike price and maturity for this period
2. During the Period
   - Add IssuableBondGroup through ```addIssuableBond()```
   - Run ```TrancheBonds()``` to provide liquidity to GDOTC
3. After Maturity
   - Burn All the bond tokens in the aggregator contract
4. After Liquidation
   - Run ```renewMaturity()``` to update strike price and maturity for the new period

# Usage
- Initialize (install libraries, download and process submodule repository)
```yarn initialize```
or
```yarn```
- Compile
```yarn compile```
- Migrate to local testnet
```yarn migrate:test:local```
- Unit test
```yarn test:unit```
- Combine test between aggregator and strategy
```yarn test:combine```
- Combine test with bondtoken contract and GDOTC contract (You can't use this command because BondToken and GDOTC repository which this aggregator uses is not published)
```yarn test:combine:bondtoken```

# Target contracts
- contracts/SimpleAggregator/ReserveERC20.sol
- contracts/SimpleAggregator/ReserveETH.sol
- contracts/SimpleAggregator/SimpleAggregator.sol
- contracts/SimpleAggregator/SimpleAggregatorCollateralizedERC20.sol
- contracts/SimpleAggregator/SimpleAggregatorCollateralizedEth.sol
- contracts/Strategy/StrategyForSimpleAggregator.sol
