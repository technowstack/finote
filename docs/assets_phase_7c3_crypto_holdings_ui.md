# Finote v1.3.0 - Phase 7C.3 Crypto Holdings UI

Status: **NOT SEPARATELY COMPLETED**

The shared Portfolio screen already supports crypto assets through the common
holdings and valuation pipeline. Crypto rows use symbol, asset name, fractional
coin/token quantity, per-unit price, and current value. API assets use the same
single explicit batch refresh as stocks; rows never issue individual requests.

Missing prices remain unknown rather than `Rp0`, and cached prices remain usable
offline. Asset activities, account-linked cashflow, backup/restore, and Net Worth
semantics remain shared with the rest of the Assets implementation.

Automated coverage includes BTC quote rendering and current-value calculation.
Dedicated crypto-specific Android visual and offline runtime verification was not
performed, so this phase remains unchecked and is not claimed as complete by the
7E.5 release audit.

Deferred: P/L, ROI, charts, historical market data, trading, broker integration,
and per-asset network requests.
