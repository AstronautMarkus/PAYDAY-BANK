      *> Shared layout for ACCOUNT-FILE (accounts.dat). Included as-is
      *> (prefix FD-) in the FD SECTION of account_repository.cbl, and
      *> via REPLACING under a different prefix (LK-, WS-) everywhere
      *> else that needs the same fields as a LINKAGE or WORKING-STORAGE
      *> parameter. Keep in sync with accounts.dat on disk -- do not
      *> reorder or resize fields without a data-migration plan.
       01  ACCOUNT-RECORD.
           05 FD-ACCOUNT-NUMBER    PIC 9(6).
           05 FD-OWNER-NAME        PIC X(30).
           *> CLP (peso chileno) no tiene submúltiplo decimal de uso
           *> corriente: el saldo se guarda como pesos enteros,
           *> empaquetado en COMP-3 para ahorrar espacio y acelerar la
           *> aritmética de montos.
           05 FD-BALANCE           PIC 9(12) COMP-3.
