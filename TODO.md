
# FiveBells - TODO

## v0.2

### A dumb borrower (proof that borrowr <-> bank loop works)

* Takes out a bank loan, uses the capital to pay of the loan
* Starts to earn a salary from the bank when capital cash has run out to pay the rest of the loan.
* Bank is forced to employ borrowers.

## v0.3

### An adjusting market (see pries moving with purchases)

* Market adjusts prices with a fixed spread of 1 so bid_price will alwasy be 1 lower than ask_price.
* Prices go up if inventory is shrinking and they go down if it is increasing
* prices remain 0 otherwise

### Factory (pushing its products)

* Factory determines output (workers, resources etc.)
* see the max it can produce and aford
* Produce produccts and store in inventory
* procudes and then asks the market to buy at the market priec
* Remove products from inventory

### Retail markets

* Buy bulk
* Discount based on TTL
* Prices don't fluctuate sa much but some nontheless

MERGE FACTORY AND MARKET INTO ONE? METAPROGRAMMING? SEEMS TO BE A LOT OF THE SAME STUFF!!!
