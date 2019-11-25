
# FiveBells - TODO

## v0.3

### Ecto export

* Add pluggable support for dumping data on transfers, accounts and statistics to a database through Ecto
* Needs to be implemented as an async agent that the bank has access to

### An adjusting market (see pries moving with purchases)

* Market adjusts prices with a fixed spread of 1 so bid_price will alwasy be 1 lower than ask_price.
* Prices go up if inventory is shrinking and they go down if it is increasing
* prices remain 0 otherwise

## v0.4

### Factory (pushing its products)

* Factory determines output (workers, resources etc.)
* see the max it can produce and aford
* Produce produccts and store in inventory
* procudes and then asks the market to buy at the market priec
* Remove products from inventory

## v0.5

### Retail markets

* Buy bulk
* Discount based on TTL
* Prices don't fluctuate sa much but some nontheless

MERGE FACTORY AND MARKET INTO ONE? METAPROGRAMMING? SEEMS TO BE A LOT OF THE SAME STUFF!!!
