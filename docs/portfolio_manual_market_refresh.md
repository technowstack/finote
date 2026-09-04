# Portfolio Manual Market Refresh

Portfolio loads holdings and local prices from Drift without making a network
request. Opening Portfolio, rebuilding widgets, switching tabs, app startup,
and price age do not trigger market requests.

The app-bar `Refresh Harga` action is the only market refresh trigger. It sends
one batch containing active positive API-priced Stock and Crypto assets. Manual
prices and assets without a position are excluded.

Last-known prices remain usable when refresh fails or returns partial results.
An API-priced asset without a local price shows `Harga belum tersedia`; it is
not treated as zero. Users may explicitly switch Stock/Crypto to manual pricing
or return to automatic pricing.
