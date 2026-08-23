*> Data-access module for CARD-FILE (cards.dat). Same function-code
*> pattern as account_repository.cbl.
*>
*> LK-REPO-FUNCTION selects the operation:
*>   OPEN | CLOSE | READ | WRITE | REWRITE | START | READNEXT
*>
*> READ expects LK-CARD-NUMBER set by the caller (primary key lookup,
*> used by OP-CARDPAYMENT/OP-BLOCKCARD/OP-UNBLOCKCARD). START/READNEXT
*> walk every card in CD-CARD-NUMBER order (same full-scan idiom as
*> account_repository.cbl); OP-CARDS filters by CD-CUSTOMER-ID itself
*> -- see transaction_repository.cbl for why this is a full scan
*> rather than an indexed lookup by customer.
IDENTIFICATION DIVISION.
PROGRAM-ID. CARD-REPOSITORY.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT CARD-FILE ASSIGN TO "cards.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS CD-CARD-NUMBER
        FILE STATUS IS WS-FILE-STATUS.

DATA DIVISION.
FILE SECTION.
FD  CARD-FILE.
COPY "card-record.cpy".

WORKING-STORAGE SECTION.
01  WS-FILE-STATUS          PIC XX.

LINKAGE SECTION.
01  LK-REPO-FUNCTION        PIC X(10).
COPY "card-record.cpy"
    REPLACING ==CARD-RECORD==        BY ==LK-CARD-RECORD==
              ==CD-CARD-NUMBER==     BY ==LK-CARD-NUMBER==
              ==CD-ACCOUNT-NUMBER==  BY ==LK-ACCOUNT-NUMBER==
              ==CD-CUSTOMER-ID==     BY ==LK-CUSTOMER-ID==
              ==CD-CARD-TYPE==       BY ==LK-CARD-TYPE==
              ==CD-CVV==             BY ==LK-CVV==
              ==CD-EXPIRY==          BY ==LK-EXPIRY==
              ==CD-STATUS==          BY ==LK-STATUS==
              ==CD-TX-LIMIT==        BY ==LK-TX-LIMIT==.
01  LK-REPO-FOUND           PIC X.
01  LK-REPO-EOF             PIC X.

PROCEDURE DIVISION USING BY REFERENCE LK-REPO-FUNCTION
                          BY REFERENCE LK-CARD-RECORD
                          BY REFERENCE LK-REPO-FOUND
                          BY REFERENCE LK-REPO-EOF.
MAIN-CARD-REPOSITORY.
    MOVE "N" TO LK-REPO-FOUND
    MOVE "N" TO LK-REPO-EOF
    EVALUATE LK-REPO-FUNCTION
        WHEN "OPEN"          PERFORM OPEN-CARD-FILE
        WHEN "CLOSE"         PERFORM CLOSE-CARD-FILE
        WHEN "READ"          PERFORM READ-CARD-BY-KEY
        WHEN "WRITE"         PERFORM WRITE-CARD
        WHEN "REWRITE"       PERFORM REWRITE-CARD
        WHEN "START"         PERFORM START-CARD-SCAN
        WHEN "READNEXT"      PERFORM READ-NEXT-CARD
        WHEN OTHER           CONTINUE
    END-EVALUATE
    GOBACK.

OPEN-CARD-FILE.
    *> Auto-creates cards.dat if it does not exist yet, same behavior
    *> as account_repository.cbl/customer_repository.cbl.
    OPEN I-O CARD-FILE
    IF WS-FILE-STATUS = "35"
        CLOSE CARD-FILE
        OPEN OUTPUT CARD-FILE
        CLOSE CARD-FILE
        OPEN I-O CARD-FILE
    END-IF.

CLOSE-CARD-FILE.
    CLOSE CARD-FILE.

READ-CARD-BY-KEY.
    MOVE LK-CARD-NUMBER TO CD-CARD-NUMBER
    READ CARD-FILE
        INVALID KEY
            MOVE "N" TO LK-REPO-FOUND
        NOT INVALID KEY
            MOVE CARD-RECORD TO LK-CARD-RECORD
            MOVE "Y" TO LK-REPO-FOUND
    END-READ.

WRITE-CARD.
    MOVE LK-CARD-RECORD TO CARD-RECORD
    WRITE CARD-RECORD
    IF WS-FILE-STATUS = "00"
        MOVE "Y" TO LK-REPO-FOUND
    ELSE
        MOVE "N" TO LK-REPO-FOUND
    END-IF.

REWRITE-CARD.
    MOVE LK-CARD-RECORD TO CARD-RECORD
    REWRITE CARD-RECORD
    IF WS-FILE-STATUS = "00"
        MOVE "Y" TO LK-REPO-FOUND
    ELSE
        MOVE "N" TO LK-REPO-FOUND
    END-IF.

START-CARD-SCAN.
    MOVE ZEROS TO CD-CARD-NUMBER
    START CARD-FILE KEY IS GREATER THAN OR EQUAL CD-CARD-NUMBER
        INVALID KEY
            MOVE "Y" TO LK-REPO-EOF
    END-START.

READ-NEXT-CARD.
    READ CARD-FILE NEXT RECORD
        AT END
            MOVE "Y" TO LK-REPO-EOF
        NOT AT END
            MOVE CARD-RECORD TO LK-CARD-RECORD
    END-READ.

END PROGRAM CARD-REPOSITORY.
