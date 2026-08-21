*> LOGIN <email>
*> Looks up a customer by email (alternate key) and hands back the
*> stored password hash for the Flask client to verify with
*> check_password_hash -- COBOL has no crypto primitives, so hashing
*> and verification stay in Python; this op only owns the lookup.
*> On a miss, the error message is deliberately the same generic text
*> used for a wrong password, so a failed login never reveals whether
*> the email exists.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-LOGIN.

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
01  WS-REPO-FUNCTION    PIC X(10).
01  WS-REPO-FOUND       PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-LOGIN.
    IF LK-ARGC < 2
        DISPLAY "ERR|Argumentos insuficientes"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-CUST-EMAIL FROM ARGUMENT-VALUE

        MOVE "READEMAIL" TO WS-REPO-FUNCTION
        CALL "CUSTOMER-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
            WS-CUSTOMER-RECORD WS-REPO-FOUND

        IF WS-REPO-FOUND = "N"
            DISPLAY "ERR|Correo o contraseña incorrectos"
        ELSE
            DISPLAY "OK|" WS-CUST-CUSTOMER-ID "|"
                FUNCTION TRIM(WS-CUST-PASSWORD-HASH)
        END-IF
    END-IF
    GOBACK.

END PROGRAM OP-LOGIN.
