*> TRANSFER <customer-id> <from-account> <to-account> <amount>
*> Moves money between two accounts. Both accounts must be owned by
*> <customer-id> (this phase only supports transfers between a
*> customer's own accounts, never to another customer).
*>
*> Sequence: read and verify both accounts fully (existence, ownership,
*> distinctness, funds) before writing anything. Only after both checks
*> pass does it debit the source and credit the destination. If the
*> destination REWRITE fails after the source was already debited, it
*> attempts one compensating REWRITE to restore the source's balance,
*> so a mid-transfer failure never silently loses money.
IDENTIFICATION DIVISION.
PROGRAM-ID. OP-TRANSFER.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "account-record.cpy"
    REPLACING ==ACCOUNT-RECORD==    BY ==WS-FROM-RECORD==
              ==FD-ACCOUNT-NUMBER== BY ==WS-FROM-NUMBER==
              ==FD-OWNER-NAME==     BY ==WS-FROM-NAME==
              ==FD-BALANCE==        BY ==WS-FROM-BALANCE==
              ==FD-CUSTOMER-ID==    BY ==WS-FROM-CUSTOMER-ID==
              ==FD-ACCOUNT-TYPE==   BY ==WS-FROM-TYPE==.
COPY "account-record.cpy"
    REPLACING ==ACCOUNT-RECORD==    BY ==WS-TO-RECORD==
              ==FD-ACCOUNT-NUMBER== BY ==WS-TO-NUMBER==
              ==FD-OWNER-NAME==     BY ==WS-TO-NAME==
              ==FD-BALANCE==        BY ==WS-TO-BALANCE==
              ==FD-CUSTOMER-ID==    BY ==WS-TO-CUSTOMER-ID==
              ==FD-ACCOUNT-TYPE==   BY ==WS-TO-TYPE==.
01  WS-ARG-INDEX            PIC 9(2).
01  WS-ARG-CUSTOMER         PIC X(10).
01  WS-ARG-FROM             PIC X(10).
01  WS-ARG-TO               PIC X(10).
01  WS-ARG-VALUE            PIC X(80).
01  WS-CUSTOMER-ID          PIC 9(6).
01  WS-AMOUNT               PIC 9(12) COMP-3.
01  WS-FROM-BALANCE-DISPLAY PIC Z(11)9.
01  WS-TO-BALANCE-DISPLAY   PIC Z(11)9.
01  WS-REPO-FUNCTION        PIC X(10).
01  WS-REPO-FOUND           PIC X.
01  WS-REPO-EOF             PIC X.

LINKAGE SECTION.
01  LK-ARGC  PIC 9(2).

PROCEDURE DIVISION USING BY REFERENCE LK-ARGC.
MAIN-OP-TRANSFER.
    IF LK-ARGC < 5
        DISPLAY "ERR|Argumentos insuficientes"
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
            DISPLAY "ERR|La cuenta de origen y destino deben ser distintas"
        ELSE
            MOVE "READ" TO WS-REPO-FUNCTION
            CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                WS-FROM-RECORD WS-REPO-FOUND WS-REPO-EOF

            IF WS-REPO-FOUND = "N"
                DISPLAY "ERR|Cuenta de origen no encontrada"
            ELSE
                IF WS-FROM-CUSTOMER-ID NOT = WS-CUSTOMER-ID
                    DISPLAY "ERR|La cuenta de origen no pertenece al cliente"
                ELSE
                    MOVE "READ" TO WS-REPO-FUNCTION
                    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                        WS-TO-RECORD WS-REPO-FOUND WS-REPO-EOF

                    IF WS-REPO-FOUND = "N"
                        DISPLAY "ERR|Cuenta de destino no encontrada"
                    ELSE
                        IF WS-TO-CUSTOMER-ID NOT = WS-CUSTOMER-ID
                            DISPLAY "ERR|La cuenta de destino no pertenece al cliente"
                        ELSE
                            IF WS-AMOUNT > WS-FROM-BALANCE
                                DISPLAY "ERR|Fondos insuficientes"
                            ELSE
                                SUBTRACT WS-AMOUNT FROM WS-FROM-BALANCE
                                MOVE "REWRITE" TO WS-REPO-FUNCTION
                                CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                                    WS-FROM-RECORD WS-REPO-FOUND WS-REPO-EOF

                                IF WS-REPO-FOUND = "N"
                                    DISPLAY "ERR|No se pudo debitar la cuenta de origen"
                                ELSE
                                    ADD WS-AMOUNT TO WS-TO-BALANCE
                                    MOVE "REWRITE" TO WS-REPO-FUNCTION
                                    CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                                        WS-TO-RECORD WS-REPO-FOUND WS-REPO-EOF

                                    IF WS-REPO-FOUND = "Y"
                                        MOVE WS-FROM-BALANCE TO WS-FROM-BALANCE-DISPLAY
                                        MOVE WS-TO-BALANCE TO WS-TO-BALANCE-DISPLAY
                                        DISPLAY "OK|" FUNCTION TRIM(WS-FROM-BALANCE-DISPLAY)
                                            "|" FUNCTION TRIM(WS-TO-BALANCE-DISPLAY)
                                    ELSE
                                        *> Compensate: the source was already debited but the
                                        *> destination credit failed. Restore the source balance
                                        *> so the failed transfer doesn't silently lose money.
                                        ADD WS-AMOUNT TO WS-FROM-BALANCE
                                        MOVE "REWRITE" TO WS-REPO-FUNCTION
                                        CALL "ACCOUNT-REPOSITORY" USING BY REFERENCE WS-REPO-FUNCTION
                                            WS-FROM-RECORD WS-REPO-FOUND WS-REPO-EOF

                                        IF WS-REPO-FOUND = "Y"
                                            DISPLAY "ERR|La transferencia no se pudo completar y fue revertida"
                                        ELSE
                                            DISPLAY "ERR|Fallo crítico: la cuenta de origen puede haber quedado inconsistente, contacte soporte"
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

END PROGRAM OP-TRANSFER.
