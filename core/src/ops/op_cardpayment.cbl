*> CARDPAYMENT <card-number> <cvv> <merchant> <amount>
*> Simulates a card-present/e-commerce purchase: authenticates with the
*> card number + CVV (no customer-id/session, mirroring how a real POS
*> or checkout authorizes a card), then debits the linked account.
*>
*> Validated in order: card exists -> status ACTIVE -> not expired
*> (CD-EXPIRY, YYMM, vs today) -> CVV matches -> amount within
*> CD-TX-LIMIT -> linked account ACTIVE -> sufficient funds. On success,
*> debits the account and appends a CARD-PAY ledger row with the
*> merchant name as its description.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-CARDPAYMENT.

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
01  WS-ARG-CARD           PIC X(20).
01  WS-ARG-CVV            PIC X(10).
01  WS-ARG-MERCHANT       PIC X(80).
01  WS-ARG-VALUE          PIC X(80).
01  WS-AMOUNT             PIC 9(12) COMP-3.
01  WS-CVV-INPUT          PIC 9(3).
01  WS-CURRENT-DATE       PIC X(8).
01  WS-CURRENT-YYMM       PIC 9(4).
01  WS-BALANCE-DISPLAY    PIC Z(11)9.
01  WS-CARD-REPO-FUNCTION PIC X(10).
01  WS-CARD-REPO-FOUND    PIC X.
01  WS-CARD-REPO-EOF      PIC X.
01  WS-ACCT-REPO-FUNCTION PIC X(10).
01  WS-ACCT-REPO-FOUND    PIC X.
01  WS-ACCT-REPO-EOF      PIC X.
01  WS-TX-REPO-FUNCTION   PIC X(10).
01  WS-TX-REPO-FOUND      PIC X.
01  WS-TX-REPO-EOF        PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-CARDPAYMENT.
    IF LK-ARGC < 5
        DISPLAY "ERR|Insufficient arguments"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CARD FROM ARGUMENT-VALUE
        MOVE 3 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CVV FROM ARGUMENT-VALUE
        MOVE 4 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-MERCHANT FROM ARGUMENT-VALUE
        MOVE 5 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE

        MOVE FUNCTION NUMVAL(WS-ARG-CARD) TO WS-CARD-NUMBER
        MOVE FUNCTION NUMVAL(WS-ARG-CVV) TO WS-CVV-INPUT
        MOVE FUNCTION NUMVAL(WS-ARG-VALUE) TO WS-AMOUNT

        MOVE "READ" TO WS-CARD-REPO-FUNCTION
        CALL "CARD-REPOSITORY" USING BY REFERENCE WS-CARD-REPO-FUNCTION
            WS-CARD-RECORD WS-CARD-REPO-FOUND WS-CARD-REPO-EOF

        IF WS-CARD-REPO-FOUND = "N"
            DISPLAY "ERR|Card not found"
        ELSE
            IF WS-CARD-STATUS NOT = "ACTIVE"
                DISPLAY "ERR|Card is blocked"
            ELSE
                MOVE FUNCTION CURRENT-DATE(1:8) TO WS-CURRENT-DATE
                MOVE FUNCTION NUMVAL(WS-CURRENT-DATE(3:4)) TO WS-CURRENT-YYMM

                IF WS-EXPIRY < WS-CURRENT-YYMM
                    DISPLAY "ERR|Card is expired"
                ELSE
                    IF WS-CVV NOT = WS-CVV-INPUT
                        DISPLAY "ERR|Invalid CVV"
                    ELSE
                        IF WS-AMOUNT > WS-TX-LIMIT
                            DISPLAY "ERR|Amount exceeds the card's limit"
                        ELSE
                            MOVE WS-CARD-ACCOUNT TO WS-ACCOUNT-NUMBER
                            MOVE "READ" TO WS-ACCT-REPO-FUNCTION
                            CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
                                WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF

                            IF WS-ACCT-REPO-FOUND = "N"
                                DISPLAY "ERR|Linked account not found"
                            ELSE
                                IF WS-ACCOUNT-STATUS NOT = "ACTIVE"
                                    DISPLAY "ERR|Linked account is not active"
                                ELSE
                                    IF WS-AMOUNT > WS-BALANCE
                                        DISPLAY "ERR|Insufficient funds"
                                    ELSE
                                        SUBTRACT WS-AMOUNT FROM WS-BALANCE
                                        MOVE "REWRITE" TO WS-ACCT-REPO-FUNCTION
                                        CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-ACCT-REPO-FUNCTION
                                            WS-ACCOUNT-RECORD WS-ACCT-REPO-FOUND WS-ACCT-REPO-EOF

                                        MOVE WS-ACCOUNT-NUMBER TO WS-TX-ACCOUNT
                                        MOVE "CARD-PAY" TO WS-TX-TYPE
                                        MOVE WS-AMOUNT TO WS-TX-AMOUNT
                                        MOVE WS-BALANCE TO WS-TX-BALANCE-AFTER
                                        MOVE 0 TO WS-TX-COUNTERPARTY
                                        MOVE WS-ARG-MERCHANT TO WS-TX-DESCRIPTION
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
                    END-IF
                END-IF
            END-IF
        END-IF
    END-IF
    GOBACK.

END PROGRAM OP-CARDPAYMENT.
