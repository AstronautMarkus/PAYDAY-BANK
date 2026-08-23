*> REGISTER <customer-id> <account> <name> <document> <email> <phone>
*>     <address> <occupation> <employer> <password-hash>
*> Creates the customer profile first, then the initial account (type
*> CHECKING, balance 0) owned by that customer. Rejects the request if
*> the email or document is already registered to another customer.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-REGISTER.

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
COPY "customer-record.cpy"
    REPLACING ==CUSTOMER-RECORD==   BY ==WS-CUSTOMER-RECORD==
              ==PF-CUSTOMER-ID==    BY ==WS-CUST-CUSTOMER-ID==
              ==PF-DOCUMENT==       BY ==WS-CUST-DOCUMENT==
              ==PF-EMAIL==          BY ==WS-CUST-EMAIL==
              ==PF-PHONE==          BY ==WS-CUST-PHONE==
              ==PF-ADDRESS==        BY ==WS-CUST-ADDRESS==
              ==PF-OCCUPATION==     BY ==WS-CUST-OCCUPATION==
              ==PF-EMPLOYER==       BY ==WS-CUST-EMPLOYER==
              ==PF-NAME==           BY ==WS-CUST-NAME==
              ==PF-PASSWORD-HASH==  BY ==WS-CUST-PASSWORD-HASH==.
01  WS-ARG-INDEX          PIC 9(2).
01  WS-ARG-CUSTOMER       PIC X(10).
01  WS-ARG-ACCOUNT        PIC X(10).
01  WS-ARG-VALUE          PIC X(80).
01  WS-ARG-PASSWORD-HASH  PIC X(255).
01  WS-ACCT-REPO-FUNCTION PIC X(10).
01  WS-ACCT-REPO-FOUND    PIC X.
01  WS-ACCT-REPO-EOF      PIC X.
01  WS-CUST-REPO-FUNCTION PIC X(10).
01  WS-CUST-REPO-FOUND    PIC X.
01  WS-TX-REPO-FUNCTION   PIC X(10).
01  WS-TX-REPO-FOUND      PIC X.
01  WS-TX-REPO-EOF        PIC X.
COPY "customer-record.cpy"
    REPLACING ==CUSTOMER-RECORD==   BY ==WS-DUP-RECORD==
              ==PF-CUSTOMER-ID==    BY ==WS-DUP-CUSTOMER-ID==
              ==PF-DOCUMENT==       BY ==WS-DUP-DOCUMENT==
              ==PF-EMAIL==          BY ==WS-DUP-EMAIL==
              ==PF-PHONE==          BY ==WS-DUP-PHONE==
              ==PF-ADDRESS==        BY ==WS-DUP-ADDRESS==
              ==PF-OCCUPATION==     BY ==WS-DUP-OCCUPATION==
              ==PF-EMPLOYER==       BY ==WS-DUP-EMPLOYER==
              ==PF-NAME==           BY ==WS-DUP-NAME==
              ==PF-PASSWORD-HASH==  BY ==WS-DUP-PASSWORD-HASH==.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-REGISTER.
    IF LK-ARGC < 11
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

        MOVE FUNCTION NUMVAL(WS-ARG-CUSTOMER) TO WS-CUST-CUSTOMER-ID
        MOVE 5 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-CUST-DOCUMENT FROM ARGUMENT-VALUE
        MOVE 6 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-CUST-EMAIL FROM ARGUMENT-VALUE
        MOVE 7 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-CUST-PHONE FROM ARGUMENT-VALUE
        MOVE 8 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-CUST-ADDRESS FROM ARGUMENT-VALUE
        MOVE 9 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-CUST-OCCUPATION FROM ARGUMENT-VALUE
        MOVE 10 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-CUST-EMPLOYER FROM ARGUMENT-VALUE
        MOVE 11 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-PASSWORD-HASH FROM ARGUMENT-VALUE

        MOVE WS-ARG-VALUE TO WS-CUST-NAME
        MOVE WS-ARG-PASSWORD-HASH TO WS-CUST-PASSWORD-HASH

        MOVE WS-CUST-EMAIL TO WS-DUP-EMAIL
        MOVE "READEMAIL" TO WS-CUST-REPO-FUNCTION
        CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-CUST-REPO-FUNCTION
            WS-DUP-RECORD WS-CUST-REPO-FOUND

        IF WS-CUST-REPO-FOUND = "Y"
            DISPLAY "ERR|A customer with that email or document already exists"
        ELSE
            MOVE WS-CUST-DOCUMENT TO WS-DUP-DOCUMENT
            MOVE "READDOC" TO WS-CUST-REPO-FUNCTION
            CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-CUST-REPO-FUNCTION
                WS-DUP-RECORD WS-CUST-REPO-FOUND

            IF WS-CUST-REPO-FOUND = "Y"
                DISPLAY "ERR|A customer with that email or document already exists"
            ELSE
                MOVE "WRITE" TO WS-CUST-REPO-FUNCTION
                CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-CUST-REPO-FUNCTION
                    WS-CUSTOMER-RECORD WS-CUST-REPO-FOUND

                IF WS-CUST-REPO-FOUND = "Y"
                    MOVE FUNCTION NUMVAL(WS-ARG-ACCOUNT) TO WS-ACCOUNT-NUMBER
                    MOVE WS-CUST-CUSTOMER-ID TO WS-ACCOUNT-CUSTOMER-ID
                    MOVE WS-ARG-VALUE TO WS-OWNER-NAME
                    MOVE "CHECKING" TO WS-ACCOUNT-TYPE
                    MOVE 0 TO WS-BALANCE
                    MOVE "ACTIVE" TO WS-ACCOUNT-STATUS

                    MOVE "WRITE" TO WS-ACCT-REPO-FUNCTION
                    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
                        WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF

                    IF WS-ACCT-REPO-FOUND = "Y"
                        MOVE WS-ACCOUNT-NUMBER TO WS-TX-ACCOUNT
                        MOVE "OPEN" TO WS-TX-TYPE
                        MOVE 0 TO WS-TX-AMOUNT
                        MOVE 0 TO WS-TX-BALANCE-AFTER
                        MOVE 0 TO WS-TX-COUNTERPARTY
                        MOVE SPACES TO WS-TX-DESCRIPTION
                        MOVE "APPEND" TO WS-TX-REPO-FUNCTION
                        CALL "TRANSACTION-REPOSITORY" USING BY REFERENCE
                            WS-TX-REPO-FUNCTION WS-TX-RECORD WS-TX-REPO-FOUND
                            WS-TX-REPO-EOF

                        DISPLAY "OK|Customer and account registered"
                    ELSE
                        DISPLAY "ERR|The customer was registered, but the account could not be created"
                    END-IF
                ELSE
                    DISPLAY "ERR|The customer already exists or could not be registered"
                END-IF
            END-IF
        END-IF
    END-IF
    GOBACK.

END PROGRAM OP-REGISTER.
