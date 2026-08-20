      *> Shared layout for CUSTOMER-FILE (customer_profiles.dat).
      *> Included as-is (prefix PF-) in the FD SECTION of
      *> customer_repository.cbl, and via REPLACING under a different
      *> prefix everywhere else that needs the same fields as a LINKAGE
      *> or WORKING-STORAGE parameter. Keep in sync with
      *> customer_profiles.dat on disk.
       01  CUSTOMER-RECORD.
           05 PF-ACCOUNT-NUMBER    PIC 9(6).
           05 PF-DOCUMENT          PIC X(20).
           05 PF-EMAIL             PIC X(60).
           05 PF-PHONE             PIC X(20).
           05 PF-ADDRESS           PIC X(80).
           05 PF-OCCUPATION        PIC X(40).
           05 PF-EMPLOYER          PIC X(50).
