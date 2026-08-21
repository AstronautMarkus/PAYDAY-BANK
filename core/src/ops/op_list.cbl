*> LIST
*> Bank-wide admin/debug dump: streams one ROW| line per account (short
*> form, or long form with the owning customer's profile when found),
*> followed by END. Not used by the Flask client (which lists accounts
*> scoped to one customer via ACCOUNTS instead) -- kept for CLI
*> inspection of the whole accounts.dat/customer_profiles.dat state.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-LIST.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "account-record.cpy"
    REPLACING ==ACCOUNT-RECORD==    BY ==WS-ACCOUNT-RECORD==
              ==FD-ACCOUNT-NUMBER== BY ==WS-ACCOUNT-NUMBER==
              ==FD-OWNER-NAME==     BY ==WS-OWNER-NAME==
              ==FD-BALANCE==        BY ==WS-BALANCE==
              ==FD-CUSTOMER-ID==    BY ==WS-ACCOUNT-CUSTOMER-ID==
              ==FD-ACCOUNT-TYPE==   BY ==WS-ACCOUNT-TYPE==.
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
01  WS-BALANCE-DISPLAY    PIC Z(11)9.
01  WS-END-OF-FILE        PIC X VALUE "N".
01  WS-ACCT-REPO-FUNCTION PIC X(10).
01  WS-ACCT-REPO-FOUND    PIC X.
01  WS-ACCT-REPO-EOF      PIC X.
01  WS-CUST-REPO-FUNCTION PIC X(10).
01  WS-CUST-REPO-FOUND    PIC X.

PROCEDURE DIVISION.
MAIN-OP-LIST.
    MOVE "N" TO WS-END-OF-FILE

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
            MOVE WS-BALANCE TO WS-BALANCE-DISPLAY
            MOVE WS-ACCOUNT-CUSTOMER-ID TO WS-CUST-CUSTOMER-ID

            MOVE "READ" TO WS-CUST-REPO-FUNCTION
            CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-CUST-REPO-FUNCTION
                WS-CUSTOMER-RECORD WS-CUST-REPO-FOUND

            IF WS-CUST-REPO-FOUND = "N"
                DISPLAY "ROW|" WS-ACCOUNT-NUMBER "|" WS-ACCOUNT-CUSTOMER-ID "|"
                    FUNCTION TRIM(WS-ACCOUNT-TYPE) "|"
                    FUNCTION TRIM(WS-OWNER-NAME) "|" FUNCTION TRIM(WS-BALANCE-DISPLAY)
            ELSE
                DISPLAY "ROW|" WS-ACCOUNT-NUMBER "|" WS-ACCOUNT-CUSTOMER-ID "|"
                    FUNCTION TRIM(WS-ACCOUNT-TYPE) "|"
                    FUNCTION TRIM(WS-OWNER-NAME) "|" FUNCTION TRIM(WS-BALANCE-DISPLAY) "|"
                    FUNCTION TRIM(WS-CUST-DOCUMENT) "|"
                    FUNCTION TRIM(WS-CUST-EMAIL) "|"
                    FUNCTION TRIM(WS-CUST-PHONE) "|"
                    FUNCTION TRIM(WS-CUST-ADDRESS) "|"
                    FUNCTION TRIM(WS-CUST-OCCUPATION) "|"
                    FUNCTION TRIM(WS-CUST-EMPLOYER)
            END-IF
        END-IF
    END-PERFORM
    DISPLAY "END"
    GOBACK.

END PROGRAM OP-LIST.
