# FiveBells - TODO

## Critical

- MERGE FACTORY AND MARKET INTO ONE? METAPROGRAMMING? SEEMS TO BE A LOT OF THE SAME STUFF!!!
- METAPROGRAM SINGLE ACCOUNT BANK CUSTOMER SO ACCOUNT RELATED STUFF DOES NOT HAVE TO BE DUPLICATE ACROSS AGENTS!!!

## v0.4

### Dump stats

- Dump on cycle reset
  - account deposit and delta
  - ledger totals
  - bank totals
  - factory prices
  - market prices
  - factory inventory
  - market inventory
  - employment (total number of population that has an employer)

### Factory (pushing its products)

- Factory determines output (workers, resources etc.)
- see the max it can produce and afford
- Produce products and store in inventory
- Produces and then asks the market to buy at the market price
- Remove products from inventory

## v0.5

### Factory (produce componentised products)

- Factory uses recipe to determine components required for production
- Uses supplier (market or factory) to acquire components
- All or nothing approach (require components for maximum output)
- As much as possible approach (let acquired components determine output)

## Nice-to-haves

### Retail markets

- Buy bulk
- Discount based on TTL
- Prices don't fluctuate sa much but some nontheless
