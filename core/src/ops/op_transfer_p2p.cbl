*> TRANSFER-P2P <customer-id> <from-account> <to-account> <amount>
*> Moves money from a customer's own account to ANY other existing
*> account in the bank -- unlike OP-TRANSFER, the destination does not
*> need to belong to the same customer. The source account still must
*> belong to <customer-id> and be ACTIVE; the destination just needs to
*> exist and be ACTIVE.
*>
*> Same read-both-before-writing + compensating-rewrite pattern as
*> OP-TRANSFER (see op_transfer.cbl), but the response never reveals
*> the destination's balance -- it may belong to a different customer,
*> so only "OK|<from-balance>" is returned.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-TRANSFER-P2P.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "account-record.cpy"
    REPLACING ==ACCOUNT-RECORD==    BY ==WS-FROM-RECORD==
              ==FD-ACCOUNT-NUMBER== BY ==WS-FROM-NUMBER==
              ==FD-OWNER-NAME==     BY ==WS-FROM-NAME==
              ==FD-BALANCE==        BY ==WS-FROM-BALANCE==
              ==FD-CUSTOMER-ID==    BY ==WS-FROM-CUSTOMER-ID==
              ==FD-ACCOUNT-TYPE==   BY ==WS-FROM-TYPE==
              ==FD-ACCOUNT-STATUS== BY ==WS-FROM-STATUS==.
COPY "account-record.cpy"
    REPLACING ==ACCOUNT-RECORD==    BY ==WS-TO-RECORD==
              ==FD-ACCOUNT-NUMBER== BY ==WS-TO-NUMBER==
              ==FD-OWNER-NAME==     BY ==WS-TO-NAME==
              ==FD-BALANCE==        BY ==WS-TO-BALANCE==
              ==FD-CUSTOMER-ID==    BY ==WS-TO-CUSTOMER-ID==
              ==FD-ACCOUNT-TYPE==   BY ==WS-TO-TYPE==
              ==FD-ACCOUNT-STATUS== BY ==WS-TO-STATUS==.
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
01  WS-ARG-INDEX            PIC 9(2).
01  WS-ARG-CUSTOMER         PIC X(10).
01  WS-ARG-FROM             PIC X(10).
01  WS-ARG-TO               PIC X(10).
01  WS-ARG-VALUE            PIC X(80).
01  WS-CUSTOMER-ID          PIC 9(6).
01  WS-AMOUNT               PIC 9(12) COMP-3.
01  WS-FROM-BALANCE-DISPLAY PIC Z(11)9.
01  WS-REPO-FUNCTION        PIC X(10).
01  WS-REPO-FOUND           PIC X.
01  WS-REPO-EOF             PIC X.
01  WS-TX-REPO-FUNCTION     PIC X(10).
01  WS-TX-REPO-FOUND        PIC X.
01  WS-TX-REPO-EOF          PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-TRANSFER-P2P.
    IF LK-ARGC < 5
        DISPLAY "ERR|Insufficient arguments"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-CUSTOMER FROM ARGUMENT-VALUE
        MOVE 3 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-FROM FROM ARGUMENT-VALUE
        MOVE 4 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-TO FROM ARGUMENT-VALUE
        MOVE 5 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE

        MOVE FUNCTION NUMVAL(WS-ARG-CUSTOMER) TO WS-CUSTOMER-ID
        MOVE FUNCTION NUMVAL(WS-ARG-FROM) TO WS-FROM-NUMBER
        MOVE FUNCTION NUMVAL(WS-ARG-TO) TO WS-TO-NUMBER
        MOVE FUNCTION NUMVAL(WS-ARG-VALUE) TO WS-AMOUNT

        IF WS-FROM-NUMBER = WS-TO-NUMBER
            DISPLAY "ERR|Source and destination accounts must be different"
        ELSE
            MOVE "READ" TO WS-REPO-FUNCTION
            CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                WS-FROM-RECORD WS-REPO-FOUND WS-REPO-EOF

            IF WS-REPO-FOUND = "N"
                DISPLAY "ERR|Source account not found"
            ELSE
                IF WS-FROM-CUSTOMER-ID NOT = WS-CUSTOMER-ID
                    DISPLAY "ERR|The source account does not belong to the customer"
                ELSE
                  IF WS-FROM-STATUS NOT = "ACTIVE"
                    DISPLAY "ERR|Source account is not active"
                  ELSE
                    MOVE "READ" TO WS-REPO-FUNCTION
                    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                        WS-TO-RECORD WS-REPO-FOUND WS-REPO-EOF

                    IF WS-REPO-FOUND = "N"
                        DISPLAY "ERR|Destination account not found"
                    ELSE
                      IF WS-TO-STATUS NOT = "ACTIVE"
                        DISPLAY "ERR|Destination account is not active"
                      ELSE
                        IF WS-AMOUNT > WS-FROM-BALANCE
                            DISPLAY "ERR|Insufficient funds"
                        ELSE
                            SUBTRACT WS-AMOUNT FROM WS-FROM-BALANCE
                            MOVE "REWRITE" TO WS-REPO-FUNCTION
                            CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                                WS-FROM-RECORD WS-REPO-FOUND WS-REPO-EOF

                            IF WS-REPO-FOUND = "N"
                                DISPLAY "ERR|Could not debit the source account"
                            ELSE
                                ADD WS-AMOUNT TO WS-TO-BALANCE
                                MOVE "REWRITE" TO WS-REPO-FUNCTION
                                CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                                    WS-TO-RECORD WS-REPO-FOUND WS-REPO-EOF

                                IF WS-REPO-FOUND = "Y"
                                    MOVE WS-FROM-NUMBER TO WS-TX-ACCOUNT
                                    MOVE "P2P-OUT" TO WS-TX-TYPE
                                    MOVE WS-AMOUNT TO WS-TX-AMOUNT
                                    MOVE WS-FROM-BALANCE TO WS-TX-BALANCE-AFTER
                                    MOVE WS-TO-NUMBER TO WS-TX-COUNTERPARTY
                                    MOVE SPACES TO WS-TX-DESCRIPTION
                                    MOVE "APPEND" TO WS-TX-REPO-FUNCTION
                                    CALL "TRANSACTION-REPOSITORY" USING BY REFERENCE
                                        WS-TX-REPO-FUNCTION WS-TX-RECORD WS-TX-REPO-FOUND
                                        WS-TX-REPO-EOF

                                    MOVE WS-TO-NUMBER TO WS-TX-ACCOUNT
                                    MOVE "P2P-IN" TO WS-TX-TYPE
                                    MOVE WS-AMOUNT TO WS-TX-AMOUNT
                                    MOVE WS-TO-BALANCE TO WS-TX-BALANCE-AFTER
                                    MOVE WS-FROM-NUMBER TO WS-TX-COUNTERPARTY
                                    MOVE SPACES TO WS-TX-DESCRIPTION
                                    MOVE "APPEND" TO WS-TX-REPO-FUNCTION
                                    CALL "TRANSACTION-REPOSITORY" USING BY REFERENCE
                                        WS-TX-REPO-FUNCTION WS-TX-RECORD WS-TX-REPO-FOUND
                                        WS-TX-REPO-EOF

                                    MOVE WS-FROM-BALANCE TO WS-FROM-BALANCE-DISPLAY
                                    DISPLAY "OK|" FUNCTION TRIM(WS-FROM-BALANCE-DISPLAY)
                                ELSE
                                    *> Compensate: the source was already debited but the
                                    *> destination credit failed. Restore the source balance
                                    *> so the failed transfer doesn't silently lose money.
                                    ADD WS-AMOUNT TO WS-FROM-BALANCE
                                    MOVE "REWRITE" TO WS-REPO-FUNCTION
                                    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                                        WS-FROM-RECORD WS-REPO-FOUND WS-REPO-EOF

                                    IF WS-REPO-FOUND = "Y"
                                        DISPLAY "ERR|The transfer could not be completed and was reversed"
                                    ELSE
                                        DISPLAY "ERR|Critical failure: the source account may be left inconsistent, contact support"
                                    END-IF
                                END-IF
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

END PROGRAM OP-TRANSFER-P2P.
