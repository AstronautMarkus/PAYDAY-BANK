*> ACCOUNTS <customer-id>
*> Streams one ROW|account|type|balance line per account owned by the
*> given customer, followed by END. This is what the Flask dashboard
*> uses to list "my accounts" -- unlike LIST, it never touches
*> CUSTOMER-REPOSITORY (the caller already has its own profile data).
*>
*> Implemented as a full sequential scan of ACCOUNT-FILE (same
*> START/READNEXT idiom as OP-LIST) filtered by FD-CUSTOMER-ID, rather
*> than an alternate index -- accounts.dat is tiny in this project, so
*> the added repository complexity of a customer-id alternate key
*> is not worth it.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-ACCOUNTS.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "account-record.cpy"
    REPLACING ==ACCOUNT-RECORD==    BY ==WS-ACCOUNT-RECORD==
              ==FD-ACCOUNT-NUMBER== BY ==WS-ACCOUNT-NUMBER==
              ==FD-OWNER-NAME==     BY ==WS-OWNER-NAME==
              ==FD-BALANCE==        BY ==WS-BALANCE==
              ==FD-CUSTOMER-ID==    BY ==WS-ACCOUNT-CUSTOMER-ID==
              ==FD-ACCOUNT-TYPE==   BY ==WS-ACCOUNT-TYPE==
              ==FD-ACCOUNT-STATUS== BY ==WS-ACCOUNT-STATUS==.
01  WS-ARG-INDEX          PIC 9(2).
01  WS-ARG-CUSTOMER       PIC X(10).
01  WS-CUSTOMER-ID        PIC 9(6).
01  WS-BALANCE-DISPLAY    PIC Z(11)9.
01  WS-END-OF-FILE        PIC X VALUE "N".
01  WS-ACCT-REPO-FUNCTION PIC X(10).
01  WS-ACCT-REPO-FOUND    PIC X.
01  WS-ACCT-REPO-EOF      PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-ACCOUNTS.
    IF LK-ARGC < 2
        DISPLAY "ERR|Insufficient arguments"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CUSTOMER FROM ARGUMENT-VALUE
        MOVE FUNCTION NUMVAL(WS-ARG-CUSTOMER) TO WS-CUSTOMER-ID

        MOVE "START" TO WS-ACCT-REPO-FUNCTION
        CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
            WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF
        IF WS-ACCT-REPO-EOF = "Y"
            MOVE "Y" TO WS-END-OF-FILE
        END-IF

        PERFORM UNTIL WS-END-OF-FILE = "Y"
            MOVE "READNEXT" TO WS-ACCT-REPO-FUNCTION
            CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
                WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF
            IF WS-ACCT-REPO-EOF = "Y"
                MOVE "Y" TO WS-END-OF-FILE
            ELSE
                IF WS-ACCOUNT-CUSTOMER-ID = WS-CUSTOMER-ID
                    MOVE WS-BALANCE TO WS-BALANCE-DISPLAY
                    DISPLAY "ROW|" WS-ACCOUNT-NUMBER "|"
                        FUNCTION TRIM(WS-ACCOUNT-TYPE) "|"
                        FUNCTION TRIM(WS-BALANCE-DISPLAY)
                END-IF
            END-IF
        END-PERFORM
        DISPLAY "END"
    END-IF
    GOBACK.

END PROGRAM OP-ACCOUNTS.
