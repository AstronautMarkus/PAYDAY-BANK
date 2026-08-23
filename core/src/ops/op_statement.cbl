*> STATEMENT <customer-id> <account>
*> Streams the ledger history of one account owned by the given
*> customer: one ROW|tx-id|type|amount|balance-after|counterparty|
*> description|datetime line per movement, oldest first, followed by
*> END. Scans the whole ledger via START/READNEXT and filters by
*> TX-ACCOUNT itself (see transaction_repository.cbl for why this is a
*> full scan rather than an indexed lookup).
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-STATEMENT.

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
COPY "transaction-record.cpy"
    REPLACING ==TRANSACTION-RECORD== BY ==WS-TX-RECORD==
              ==TX-ID==              BY ==WS-TX-ID==
              ==TX-ACCOUNT==         BY ==WS-TX-ACCOUNT==
              ==TX-TYPE==            BY ==WS-TX-TYPE==
              ==TX-AMOUNT==          BY ==WS-TX-AMOUNT==
              ==TX-BALANCE-AFTER==   BY ==WS-TX-BALANCE-AFTER==
              ==TX-COUNTERPARTY==    BY ==WS-TX-COUNTERPARTY==
              ==TX-DESCRIPTION==     BY ==WS-TX-DESCRIPTION==
              ==TX-DATETIME==        BY ==WS-TX-DATETIME==.
01  WS-ARG-INDEX          PIC 9(2).
01  WS-ARG-CUSTOMER       PIC X(10).
01  WS-ARG-ACCOUNT        PIC X(10).
01  WS-CUSTOMER-ID        PIC 9(6).
01  WS-AMOUNT-DISPLAY     PIC Z(11)9.
01  WS-BALANCE-DISPLAY    PIC Z(11)9.
01  WS-END-OF-FILE        PIC X VALUE "N".
01  WS-ACCT-REPO-FUNCTION PIC X(10).
01  WS-ACCT-REPO-FOUND    PIC X.
01  WS-ACCT-REPO-EOF      PIC X.
01  WS-TX-REPO-FUNCTION   PIC X(10).
01  WS-TX-REPO-FOUND      PIC X.
01  WS-TX-REPO-EOF        PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-STATEMENT.
    IF LK-ARGC < 3
        DISPLAY "ERR|Insufficient arguments"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CUSTOMER FROM ARGUMENT-VALUE
        MOVE 3 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-ACCOUNT FROM ARGUMENT-VALUE

        MOVE FUNCTION NUMVAL(WS-ARG-CUSTOMER) TO WS-CUSTOMER-ID
        MOVE FUNCTION NUMVAL(WS-ARG-ACCOUNT) TO WS-ACCOUNT-NUMBER

        MOVE "READ" TO WS-ACCT-REPO-FUNCTION
        CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
            WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF

        IF WS-ACCT-REPO-FOUND = "N"
            DISPLAY "ERR|Account not found"
        ELSE
            IF WS-ACCOUNT-CUSTOMER-ID NOT = WS-CUSTOMER-ID
                DISPLAY "ERR|This account does not belong to the customer"
            ELSE
                MOVE "START" TO WS-TX-REPO-FUNCTION
                CALL "TRANSACTION-REPOSITORY" USING BY REFERENCE
                    WS-TX-REPO-FUNCTION WS-TX-RECORD WS-TX-REPO-FOUND
                    WS-TX-REPO-EOF
                IF WS-TX-REPO-EOF = "Y"
                    MOVE "Y" TO WS-END-OF-FILE
                END-IF

                PERFORM UNTIL WS-END-OF-FILE = "Y"
                    MOVE "READNEXT" TO WS-TX-REPO-FUNCTION
                    CALL "TRANSACTION-REPOSITORY" USING BY REFERENCE
                        WS-TX-REPO-FUNCTION WS-TX-RECORD WS-TX-REPO-FOUND
                        WS-TX-REPO-EOF
                    IF WS-TX-REPO-EOF = "Y"
                        MOVE "Y" TO WS-END-OF-FILE
                    ELSE
                        IF WS-TX-ACCOUNT = WS-ACCOUNT-NUMBER
                            MOVE WS-TX-AMOUNT TO WS-AMOUNT-DISPLAY
                            MOVE WS-TX-BALANCE-AFTER TO WS-BALANCE-DISPLAY
                            DISPLAY "ROW|" WS-TX-ID "|"
                                FUNCTION TRIM(WS-TX-TYPE) "|"
                                FUNCTION TRIM(WS-AMOUNT-DISPLAY) "|"
                                FUNCTION TRIM(WS-BALANCE-DISPLAY) "|"
                                WS-TX-COUNTERPARTY "|"
                                FUNCTION TRIM(WS-TX-DESCRIPTION) "|"
                                WS-TX-DATETIME
                        END-IF
                    END-IF
                END-PERFORM
                DISPLAY "END"
            END-IF
        END-IF
    END-IF
    GOBACK.

END PROGRAM OP-STATEMENT.
