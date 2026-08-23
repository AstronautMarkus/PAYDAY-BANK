      *> Shared layout for TX-COUNTER-FILE (tx_counter.dat): a single
      *> record holding the last TX-ID assigned, so
      *> TRANSACTION-REPOSITORY can hand out unique, gapless, increasing
      *> ledger IDs without depending on wall-clock timestamps (two ledger
      *> rows written by the same operation, e.g. a transfer, would
      *> otherwise risk colliding on the same second).
       01  TX-COUNTER-RECORD.
           05 TC-KEY               PIC X(2).
           05 TC-LAST-ID           PIC 9(10).
