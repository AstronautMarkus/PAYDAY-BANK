*> CUSTEXISTS <customer-id>
*> Reports whether a customer-id is already taken. Used by the Flask
*> client to check candidate customer IDs the same way it already uses
*> BALANCE to check candidate account numbers (see account_exists() in
*> app/mainframe/client.py).
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-CUSTEXISTS.

DATA DIVISION.
WORKING-STORAGE SECTION.
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
01  WS-ARG-INDEX        PIC 9(2).
01  WS-ARG-CUSTOMER     PIC X(10).
01  WS-REPO-FUNCTION    PIC X(10).
01  WS-REPO-FOUND       PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-CUSTEXISTS.
    IF LK-ARGC < 2
        DISPLAY "ERR|Insufficient arguments"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CUSTOMER FROM ARGUMENT-VALUE
        MOVE FUNCTION NUMVAL(WS-ARG-CUSTOMER) TO WS-CUST-CUSTOMER-ID

        MOVE "READ" TO WS-REPO-FUNCTION
        CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
            WS-CUSTOMER-RECORD WS-REPO-FOUND

        IF WS-REPO-FOUND = "N"
            DISPLAY "ERR|Customer not found"
        ELSE
            DISPLAY "OK|" FUNCTION TRIM(WS-CUST-DOCUMENT)
        END-IF
    END-IF
    GOBACK.

END PROGRAM OP-CUSTEXISTS.
