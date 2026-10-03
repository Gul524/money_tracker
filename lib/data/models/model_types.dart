enum CategoryType { income, expense, both }

enum AccountType { cash, bank, microfinance }

enum TransactionType { income, expense, oweIn, oweOut }

enum OweStatus { pending, completed }

/// Sentinel used by copyWith to distinguish omitted nullable fields from null.
const omitted = Object();
