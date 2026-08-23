      *> Shared layout for ACCOUNT-FILE (accounts.dat). Included as-is
      *> (prefix FD-) in the FD SECTION of account_repository.cbl, and
      *> via REPLACING under a different prefix (LK-, WS-) everywhere
      *> else that needs the same fields as a LINKAGE or WORKING-STORAGE
      *> parameter. Keep in sync with accounts.dat on disk -- do not
      *> reorder or resize fields without a data-migration plan.
       01  ACCOUNT-RECORD.
           05 FD-ACCOUNT-NUMBER    PIC 9(6).
           05 FD-OWNER-NAME        PIC X(30).
           *> This system tracks whole-dollar balances only (no cents):
           *> the balance is stored as an integer number of dollars,
           *> packed in COMP-3 for compact storage and fast arithmetic.
           05 FD-BALANCE           PIC 9(12) COMP-3.
           *> Cliente dueño de esta cuenta (ver customer-record.cpy).
           *> Una cuenta pertenece a exactamente un cliente; un cliente
           *> puede tener varias cuentas (una por FD-ACCOUNT-TYPE, sin
           *> límite impuesto aquí).
           05 FD-CUSTOMER-ID       PIC 9(6).
           05 FD-ACCOUNT-TYPE      PIC X(10).
           *> Lifecycle state. ACTIVE accounts accept money movement;
           *> FROZEN rejects DEPOSIT/WITHDRAW/TRANSFER/TRANSFER-P2P/
           *> CARDPAYMENT; CLOSED is terminal (set by OP-CLOSEACCT, no
           *> reopen operation exists).
           05 FD-ACCOUNT-STATUS    PIC X(8).
