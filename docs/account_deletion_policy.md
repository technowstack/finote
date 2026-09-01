# Account Deletion Policy

Finote only permanently deletes a non-default account that has never been
referenced by a transaction or transfer.

## Rules

- The Default Account cannot be deleted or deactivated.
- Active and inactive accounts are eligible when they have no financial
  history.
- Active and soft-deleted transactions both count as financial history.
- Incoming, outgoing, active, and soft-deleted transfers all count as
  financial history.
- An initial balance does not count as financial history. Deleting such an
  unused account removes that balance from Total Assets without changing
  income, expense, or net transaction totals.
- Used accounts can only be deactivated. Their financial records are never
  reassigned or removed automatically.

The repository checks these rules again inside the same database transaction
that performs the deletion. SQLite foreign keys also use `RESTRICT`; no account
relationship uses cascading deletion.
