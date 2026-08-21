*> Non-interactive COBOL backend: receives command-line arguments
*> and writes one result line to stdout.
*> It is invoked as a subprocess by the web frontend (Flask).
*>
*> Usage:
*>   bank_api REGISTER   <customer-id> <account> <name> <document> <email>
*>       <phone> <address> <occupation> <employer> <password-hash>
*>   bank_api CUSTEXISTS <customer-id>
*>   bank_api LOGIN      <email>
*>   bank_api PROFILE    <customer-id>
*>   bank_api OPENACCT   <customer-id> <account> <name> <type>
*>   bank_api ACCOUNTS   <customer-id>
*>   bank_api BALANCE    <account>
*>   bank_api DEPOSIT    <customer-id> <account> <amount>
*>   bank_api WITHDRAW   <customer-id> <account> <amount>
*>   bank_api TRANSFER   <customer-id> <from-account> <to-account> <amount>
*>   bank_api LIST
*>
*> A customer's login credential (email + password hash) lives in the
*> same customer profile record as everything else -- COBOL owns
*> storage, but never interprets the hash. Hashing/verification is done
*> by the Flask client (see LOGIN/REGISTER above and
*> client/app/blueprints/auth/routes.py).
*>
*> A customer is an identity (profile + login); an account is a product
*> (balance + type, "CHECKING" or "SAVINGS") owned by one customer. Every
*> money-moving operation (DEPOSIT/WITHDRAW/TRANSFER) takes the caller's
*> customer-id and the core verifies each account's ownership before
*> touching its balance -- see OP-DEPOSIT/OP-WITHDRAW/OP-TRANSFER.
*>
*> Output:
*>   OK|...      successful operation
*>   ERR|message failed operation
*>   ROW|...     one per row (ACCOUNTS/LIST only, shape documented in
*>               each OP-* subprogram)
*>   END          marks the end of the listing (ACCOUNTS/LIST only)
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
              ==FD-BALANCE==        BY ==WS-BALANCE==
              ==FD-CUSTOMER-ID==    BY ==WS-ACCOUNT-CUSTOMER-ID==
              ==FD-ACCOUNT-TYPE==   BY ==WS-ACCOUNT-TYPE==.
01  WS-ACCT-REPO-FUNCTION   PIC X(10).
01  WS-ACCT-REPO-FOUND      PIC X.
01  WS-ACCT-REPO-EOF        PIC X.
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
01  WS-CUST-REPO-FUNCTION   PIC X(10).
01  WS-CUST-REPO-FOUND      PIC X.

PROCEDURE DIVISION.
MAIN-PARAGRAPH.
    ACCEPT WS-ARGC FROM ARGUMENT-NUMBER

    IF WS-ARGC < 1
        DISPLAY "ERR|Operation not specified"
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
        WHEN "CUSTEXISTS"
            CALL "OP-CUSTEXISTS" USING BY REFERENCE WS-ARGC
        WHEN "LOGIN"
            CALL "OP-LOGIN" USING BY REFERENCE WS-ARGC
        WHEN "PROFILE"
            CALL "OP-PROFILE" USING BY REFERENCE WS-ARGC
        WHEN "OPENACCT"
            CALL "OP-OPENACCT" USING BY REFERENCE WS-ARGC
        WHEN "ACCOUNTS"
            CALL "OP-ACCOUNTS" USING BY REFERENCE WS-ARGC
        WHEN "BALANCE"
            CALL "OP-BALANCE" USING BY REFERENCE WS-ARGC
        WHEN "DEPOSIT"
            CALL "OP-DEPOSIT" USING BY REFERENCE WS-ARGC
        WHEN "WITHDRAW"
            CALL "OP-WITHDRAW" USING BY REFERENCE WS-ARGC
        WHEN "TRANSFER"
            CALL "OP-TRANSFER" USING BY REFERENCE WS-ARGC
        WHEN "LIST"
            CALL "OP-LIST"
        WHEN OTHER
            DISPLAY "ERR|Invalid operation"
    END-EVALUATE

    MOVE "CLOSE" TO WS-ACCT-REPO-FUNCTION
    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
        WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF
    MOVE "CLOSE" TO WS-CUST-REPO-FUNCTION
    CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-CUST-REPO-FUNCTION
        WS-CUSTOMER-RECORD WS-CUST-REPO-FOUND

    STOP RUN.
