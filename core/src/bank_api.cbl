*> Non-interactive COBOL backend: receives command-line arguments
*> and writes one result line to stdout.
*> It is invoked as a subprocess by the web frontend (Flask).
*>
*> Usage:
*>   bank_api REGISTER <cuenta> <nombre> <documento> <email> <teléfono>
*>       <domicilio> <ocupación> <empresa>
*>   bank_api BALANCE  <account>
*>   bank_api DEPOSIT  <account> <amount>
*>   bank_api WITHDRAW <account> <amount>
*>   bank_api LIST
*>
*> Output:
*>   OK|...      successful operation
*>   ERR|message failed operation
*>   ROW|account|name|balance|profile-data  (one per account, LIST only)
*>   END          marks the end of the listing (LIST only)
*>
*> This is only the dispatcher: it opens/closes the data files (through
*> ACCOUNT-REPOSITORY / CUSTOMER-REPOSITORY) and routes the requested
*> operation to its OP-* subprogram (src/ops/). Business logic lives in
*> those subprograms, and file I/O lives in the repository subprograms
*> (src/repository/) -- see core/README structure notes if present.
IDENTIFICATION DIVISION.
PROGRAM-ID. BANK-API.

DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-ARGC                 PIC 9(2).
01  WS-ARG-INDEX            PIC 9(2).
01  WS-OPERATION            PIC X(10).
COPY "account-record.cpy"
    REPLACING ==ACCOUNT-RECORD==    BY ==WS-ACCOUNT-RECORD==
              ==FD-ACCOUNT-NUMBER== BY ==WS-ACCOUNT-NUMBER==
              ==FD-OWNER-NAME==     BY ==WS-OWNER-NAME==
              ==FD-BALANCE==        BY ==WS-BALANCE==.
01  WS-ACCT-REPO-FUNCTION   PIC X(10).
01  WS-ACCT-REPO-FOUND      PIC X.
01  WS-ACCT-REPO-EOF        PIC X.
COPY "customer-record.cpy"
    REPLACING ==CUSTOMER-RECORD==   BY ==WS-CUSTOMER-RECORD==
              ==PF-ACCOUNT-NUMBER== BY ==WS-CUST-ACCOUNT-NUMBER==
              ==PF-DOCUMENT==       BY ==WS-CUST-DOCUMENT==
              ==PF-EMAIL==          BY ==WS-CUST-EMAIL==
              ==PF-PHONE==          BY ==WS-CUST-PHONE==
              ==PF-ADDRESS==        BY ==WS-CUST-ADDRESS==
              ==PF-OCCUPATION==     BY ==WS-CUST-OCCUPATION==
              ==PF-EMPLOYER==       BY ==WS-CUST-EMPLOYER==.
01  WS-CUST-REPO-FUNCTION   PIC X(10).
01  WS-CUST-REPO-FOUND      PIC X.

PROCEDURE DIVISION.
MAIN-PARAGRAPH.
    ACCEPT WS-ARGC FROM ARGUMENT-NUMBER

    IF WS-ARGC < 1
        DISPLAY "ERR|Operación no especificada"
        STOP RUN
    END-IF

    MOVE 1 TO WS-ARG-INDEX
    DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
    ACCEPT WS-OPERATION FROM ARGUMENT-VALUE

    MOVE "OPEN" TO WS-ACCT-REPO-FUNCTION
    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
        WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF
    MOVE "OPEN" TO WS-CUST-REPO-FUNCTION
    CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-CUST-REPO-FUNCTION
        WS-CUSTOMER-RECORD WS-CUST-REPO-FOUND

    EVALUATE FUNCTION UPPER-CASE(WS-OPERATION)
        WHEN "REGISTER"
            CALL "OP-REGISTER" USING BY REFERENCE WS-ARGC
        WHEN "BALANCE"
            CALL "OP-BALANCE" USING BY REFERENCE WS-ARGC
        WHEN "DEPOSIT"
            CALL "OP-DEPOSIT" USING BY REFERENCE WS-ARGC
        WHEN "WITHDRAW"
            CALL "OP-WITHDRAW" USING BY REFERENCE WS-ARGC
        WHEN "LIST"
            CALL "OP-LIST"
        WHEN OTHER
            DISPLAY "ERR|Operación inválida"
    END-EVALUATE

    MOVE "CLOSE" TO WS-ACCT-REPO-FUNCTION
    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
        WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF
    MOVE "CLOSE" TO WS-CUST-REPO-FUNCTION
    CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-CUST-REPO-FUNCTION
        WS-CUSTOMER-RECORD WS-CUST-REPO-FOUND

    STOP RUN.
