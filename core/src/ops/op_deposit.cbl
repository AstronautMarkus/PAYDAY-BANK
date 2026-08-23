*> DEPOSIT <customer-id> <account> <amount>
*> Adds an amount to an account's balance. The account must belong to
*> the given customer-id (see bank_api.cbl header for why every
*> money-moving op is scoped to its caller's own accounts).
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-DEPOSIT.

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
01  WS-ARG-INDEX        PIC 9(2).
01  WS-ARG-CUSTOMER     PIC X(10).
01  WS-ARG-ACCOUNT      PIC X(10).
01  WS-ARG-VALUE        PIC X(80).
01  WS-CUSTOMER-ID      PIC 9(6).
01  WS-AMOUNT           PIC 9(12) COMP-3.
01  WS-BALANCE-DISPLAY  PIC Z(11)9.
01  WS-REPO-FUNCTION    PIC X(10).
01  WS-REPO-FOUND       PIC X.
01  WS-REPO-EOF         PIC X.
01  WS-TX-REPO-FUNCTION PIC X(10).
01  WS-TX-REPO-FOUND    PIC X.
01  WS-TX-REPO-EOF      PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-DEPOSIT.
    IF LK-ARGC < 4
        DISPLAY "ERR|Insufficient arguments"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CUSTOMER FROM ARGUMENT-VALUE
        MOVE 3 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-ACCOUNT FROM ARGUMENT-VALUE
        MOVE 4 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE

        MOVE FUNCTION NUMVAL(WS-ARG-CUSTOMER) TO WS-CUSTOMER-ID
        MOVE FUNCTION NUMVAL(WS-ARG-ACCOUNT) TO WS-ACCOUNT-NUMBER
        MOVE FUNCTION NUMVAL(WS-ARG-VALUE) TO WS-AMOUNT

        MOVE "READ" TO WS-REPO-FUNCTION
        CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
            WS-ACCOUNT-RECORD WS-REPO-FOUND WS-REPO-EOF

        IF WS-REPO-FOUND = "N"
            DISPLAY "ERR|Account not found"
        ELSE
            IF WS-ACCOUNT-CUSTOMER-ID NOT = WS-CUSTOMER-ID
                DISPLAY "ERR|This account does not belong to the customer"
            ELSE
                IF WS-ACCOUNT-STATUS NOT = "ACTIVE"
                    DISPLAY "ERR|Account is not active"
                ELSE
                    ADD WS-AMOUNT TO WS-BALANCE
                    MOVE "REWRITE" TO WS-REPO-FUNCTION
                    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                        WS-ACCOUNT-RECORD WS-REPO-FOUND WS-REPO-EOF

                    MOVE WS-ACCOUNT-NUMBER TO WS-TX-ACCOUNT
                    MOVE "DEPOSIT" TO WS-TX-TYPE
                    MOVE WS-AMOUNT TO WS-TX-AMOUNT
                    MOVE WS-BALANCE TO WS-TX-BALANCE-AFTER
                    MOVE 0 TO WS-TX-COUNTERPARTY
                    MOVE SPACES TO WS-TX-DESCRIPTION
                    MOVE "APPEND" TO WS-TX-REPO-FUNCTION
                    CALL "TRANSACTION-REPOSITORY" USING BY REFERENCE
                        WS-TX-REPO-FUNCTION WS-TX-RECORD WS-TX-REPO-FOUND
                        WS-TX-REPO-EOF

                    MOVE WS-BALANCE TO WS-BALANCE-DISPLAY
                    DISPLAY "OK|" FUNCTION TRIM(WS-BALANCE-DISPLAY)
                END-IF
            END-IF
        END-IF
    END-IF
    GOBACK.

END PROGRAM OP-DEPOSIT.
