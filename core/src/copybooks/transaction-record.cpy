      *> Shared layout for TRANSACTION-FILE (transactions.dat), the
      *> append-only ledger of every balance-changing event. Included
      *> as-is (prefix TX-) in the FD SECTION of
      *> transaction_repository.cbl, and via REPLACING under a different
      *> prefix everywhere else. TX-ID is assigned by
      *> TRANSACTION-REPOSITORY's APPEND function -- callers never set it
      *> themselves (see tx-counter-record.cpy).
      *>
      *> TX-TYPE values in use: OPEN, DEPOSIT, WITHDRAW, TRANSFER-OUT,
      *> TRANSFER-IN, P2P-OUT, P2P-IN, CARD-PAY.
       01  TRANSACTION-RECORD.
           05 TX-ID                PIC 9(10).
           05 TX-ACCOUNT           PIC 9(6).
           05 TX-TYPE              PIC X(12).
           05 TX-AMOUNT            PIC 9(12) COMP-3.
           05 TX-BALANCE-AFTER     PIC 9(12) COMP-3.
           *> Related account for TRANSFER-*/P2P-* rows, zero otherwise.
           05 TX-COUNTERPARTY      PIC 9(6).
           05 TX-DESCRIPTION       PIC X(40).
           05 TX-DATETIME          PIC X(14).
