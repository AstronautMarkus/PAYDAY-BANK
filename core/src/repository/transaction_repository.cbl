*> Data-access module for TRANSACTION-FILE (transactions.dat), the
*> append-only ledger, plus its companion TX-COUNTER-FILE
*> (tx_counter.dat) which hands out unique TX-IDs. Both files are
*> declared here -- per COBOL rules, all I/O on a file must happen
*> inside the program that declares it -- and exposed through the same
*> function-code interface style as account_repository.cbl.
*>
*> LK-REPO-FUNCTION selects the operation:
*>   OPEN | CLOSE | APPEND | START | READNEXT
*>
*> APPEND takes a caller-filled LK-TRANSACTION-RECORD (TX-ID is ignored
*> on input -- the repository assigns it) and writes it, stamping
*> TX-ID and TX-DATETIME; the assigned TX-ID is handed back in
*> LK-TX-ID. START/READNEXT walk every ledger row in TX-ID order (same
*> full-scan idiom as account_repository.cbl) -- callers filter by
*> TX-ACCOUNT themselves, same responsibility op_accounts.cbl already
*> has scanning ACCOUNT-FILE. A TX-ACCOUNT alternate key looked simpler
*> but its sequential READ NEXT does not reliably stop at end of file
*> under GnuCOBOL 3.2, so this deliberately mirrors the proven
*> primary-key scan instead.
IDENTIFICATION DIVISION.
PROGRAM-ID. TRANSACTION-REPOSITORY.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT TRANSACTION-FILE ASSIGN TO "transactions.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS TX-ID
        FILE STATUS IS WS-TX-FILE-STATUS.
    SELECT TX-COUNTER-FILE ASSIGN TO "tx_counter.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS TC-KEY
        FILE STATUS IS WS-COUNTER-FILE-STATUS.

DATA DIVISION.
FILE SECTION.
FD  TRANSACTION-FILE.
COPY "transaction-record.cpy".
FD  TX-COUNTER-FILE.
COPY "tx-counter-record.cpy".

WORKING-STORAGE SECTION.
01  WS-TX-FILE-STATUS       PIC XX.
01  WS-COUNTER-FILE-STATUS  PIC XX.
01  WS-NEXT-ID              PIC 9(10).

LINKAGE SECTION.
01  LK-REPO-FUNCTION        PIC X(10).
COPY "transaction-record.cpy"
    REPLACING ==TRANSACTION-RECORD== BY ==LK-TRANSACTION-RECORD==
              ==TX-ID==              BY ==LK-TX-ID==
              ==TX-ACCOUNT==         BY ==LK-TX-ACCOUNT==
              ==TX-TYPE==            BY ==LK-TX-TYPE==
              ==TX-AMOUNT==          BY ==LK-TX-AMOUNT==
              ==TX-BALANCE-AFTER==   BY ==LK-TX-BALANCE-AFTER==
              ==TX-COUNTERPARTY==    BY ==LK-TX-COUNTERPARTY==
              ==TX-DESCRIPTION==     BY ==LK-TX-DESCRIPTION==
              ==TX-DATETIME==        BY ==LK-TX-DATETIME==.
01  LK-REPO-FOUND           PIC X.
01  LK-REPO-EOF             PIC X.

PROCEDURE DIVISION USING BY REFERENCE LK-REPO-FUNCTION
                          BY REFERENCE LK-TRANSACTION-RECORD
                          BY REFERENCE LK-REPO-FOUND
                          BY REFERENCE LK-REPO-EOF.
MAIN-TRANSACTION-REPOSITORY.
    MOVE "N" TO LK-REPO-FOUND
    MOVE "N" TO LK-REPO-EOF
    EVALUATE LK-REPO-FUNCTION
        WHEN "OPEN"         PERFORM OPEN-TRANSACTION-FILES
        WHEN "CLOSE"        PERFORM CLOSE-TRANSACTION-FILES
        WHEN "APPEND"       PERFORM APPEND-TRANSACTION
        WHEN "START"        PERFORM START-TRANSACTION-SCAN
        WHEN "READNEXT"     PERFORM READ-NEXT-TRANSACTION
        WHEN OTHER          CONTINUE
    END-EVALUATE
    GOBACK.

OPEN-TRANSACTION-FILES.
    *> Auto-creates both files if missing, same behavior as
    *> account_repository.cbl/customer_repository.cbl.
    OPEN I-O TRANSACTION-FILE
    IF WS-TX-FILE-STATUS = "35"
        CLOSE TRANSACTION-FILE
        OPEN OUTPUT TRANSACTION-FILE
        CLOSE TRANSACTION-FILE
        OPEN I-O TRANSACTION-FILE
    END-IF

    OPEN I-O TX-COUNTER-FILE
    IF WS-COUNTER-FILE-STATUS = "35"
        CLOSE TX-COUNTER-FILE
        OPEN OUTPUT TX-COUNTER-FILE
        CLOSE TX-COUNTER-FILE
        OPEN I-O TX-COUNTER-FILE
    END-IF

    *> Seed the single counter row the first time ever; on every later
    *> run this WRITE simply fails on a duplicate key, which is fine.
    MOVE "01" TO TC-KEY
    MOVE 0 TO TC-LAST-ID
    WRITE TX-COUNTER-RECORD
        INVALID KEY
            CONTINUE
    END-WRITE.

CLOSE-TRANSACTION-FILES.
    CLOSE TRANSACTION-FILE
    CLOSE TX-COUNTER-FILE.

APPEND-TRANSACTION.
    *> Read-increment-rewrite the shared counter to mint the next TX-ID.
    MOVE "01" TO TC-KEY
    READ TX-COUNTER-FILE
        INVALID KEY
            MOVE 0 TO TC-LAST-ID
    END-READ
    ADD 1 TO TC-LAST-ID
    MOVE TC-LAST-ID TO WS-NEXT-ID
    REWRITE TX-COUNTER-RECORD
        INVALID KEY
            WRITE TX-COUNTER-RECORD
    END-REWRITE

    MOVE LK-TRANSACTION-RECORD TO TRANSACTION-RECORD
    MOVE WS-NEXT-ID TO TX-ID
    MOVE FUNCTION CURRENT-DATE(1:14) TO TX-DATETIME
    WRITE TRANSACTION-RECORD
    IF WS-TX-FILE-STATUS = "00"
        MOVE WS-NEXT-ID TO LK-TX-ID
        MOVE "Y" TO LK-REPO-FOUND
    ELSE
        MOVE "N" TO LK-REPO-FOUND
    END-IF.

START-TRANSACTION-SCAN.
    MOVE ZEROS TO TX-ID
    START TRANSACTION-FILE KEY IS GREATER THAN OR EQUAL TX-ID
        INVALID KEY
            MOVE "Y" TO LK-REPO-EOF
    END-START.

READ-NEXT-TRANSACTION.
    READ TRANSACTION-FILE NEXT RECORD
        AT END
            MOVE "Y" TO LK-REPO-EOF
        NOT AT END
            MOVE TRANSACTION-RECORD TO LK-TRANSACTION-RECORD
    END-READ.

END PROGRAM TRANSACTION-REPOSITORY.
