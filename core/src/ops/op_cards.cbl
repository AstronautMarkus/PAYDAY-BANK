*> CARDS <customer-id>
*> Streams one ROW|card-number|account|type|status|expiry line per
*> card owned by the customer, followed by END. Scans every card via
*> START/READNEXT and filters by CD-CUSTOMER-ID itself (see
*> card_repository.cbl). The CVV and spending limit are never included
*> in this listing.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-CARDS.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "card-record.cpy"
    REPLACING ==CARD-RECORD==       BY ==WS-CARD-RECORD==
              ==CD-CARD-NUMBER==    BY ==WS-CARD-NUMBER==
              ==CD-ACCOUNT-NUMBER== BY ==WS-CARD-ACCOUNT==
              ==CD-CUSTOMER-ID==    BY ==WS-CARD-CUSTOMER-ID==
              ==CD-CARD-TYPE==      BY ==WS-CARD-TYPE==
              ==CD-CVV==            BY ==WS-CVV==
              ==CD-EXPIRY==         BY ==WS-EXPIRY==
              ==CD-STATUS==         BY ==WS-CARD-STATUS==
              ==CD-TX-LIMIT==       BY ==WS-TX-LIMIT==.
01  WS-ARG-INDEX          PIC 9(2).
01  WS-ARG-CUSTOMER       PIC X(10).
01  WS-CUSTOMER-ID        PIC 9(6).
01  WS-END-OF-FILE        PIC X VALUE "N".
01  WS-CARD-REPO-FUNCTION PIC X(10).
01  WS-CARD-REPO-FOUND    PIC X.
01  WS-CARD-REPO-EOF      PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-CARDS.
    IF LK-ARGC < 2
        DISPLAY "ERR|Insufficient arguments"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CUSTOMER FROM ARGUMENT-VALUE
        MOVE FUNCTION NUMVAL(WS-ARG-CUSTOMER) TO WS-CUSTOMER-ID

        MOVE "START" TO WS-CARD-REPO-FUNCTION
        CALL "CARD-REPOSITORY" USING BY REFERENCE WS-CARD-REPO-FUNCTION
            WS-CARD-RECORD WS-CARD-REPO-FOUND WS-CARD-REPO-EOF
        IF WS-CARD-REPO-EOF = "Y"
            MOVE "Y" TO WS-END-OF-FILE
        END-IF

        PERFORM UNTIL WS-END-OF-FILE = "Y"
            MOVE "READNEXT" TO WS-CARD-REPO-FUNCTION
            CALL "CARD-REPOSITORY" USING BY REFERENCE WS-CARD-REPO-FUNCTION
                WS-CARD-RECORD WS-CARD-REPO-FOUND WS-CARD-REPO-EOF
            IF WS-CARD-REPO-EOF = "Y"
                MOVE "Y" TO WS-END-OF-FILE
            ELSE
                IF WS-CARD-CUSTOMER-ID = WS-CUSTOMER-ID
                    DISPLAY "ROW|" WS-CARD-NUMBER "|" WS-CARD-ACCOUNT "|"
                        FUNCTION TRIM(WS-CARD-TYPE) "|"
                        FUNCTION TRIM(WS-CARD-STATUS) "|" WS-EXPIRY
                END-IF
            END-IF
        END-PERFORM
        DISPLAY "END"
    END-IF
    GOBACK.

END PROGRAM OP-CARDS.
