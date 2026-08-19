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
IDENTIFICATION DIVISION.
PROGRAM-ID. BANK-API.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT ACCOUNT-FILE ASSIGN TO "accounts.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS FD-ACCOUNT-NUMBER
        FILE STATUS IS WS-FILE-STATUS.
    SELECT CUSTOMER-FILE ASSIGN TO "customer_profiles.dat"
        ORGANIZATION IS INDEXED
        ACCESS MODE IS DYNAMIC
        RECORD KEY IS PF-ACCOUNT-NUMBER
        FILE STATUS IS WS-FILE-STATUS.

DATA DIVISION.
FILE SECTION.
FD  ACCOUNT-FILE.
01  ACCOUNT-RECORD.
    05 FD-ACCOUNT-NUMBER    PIC 9(6).
    05 FD-OWNER-NAME        PIC X(30).
    05 FD-BALANCE           PIC 9(9)V99.

FD  CUSTOMER-FILE.
01  CUSTOMER-RECORD.
    05 PF-ACCOUNT-NUMBER    PIC 9(6).
    05 PF-DOCUMENT          PIC X(20).
    05 PF-EMAIL             PIC X(60).
    05 PF-PHONE             PIC X(20).
    05 PF-ADDRESS           PIC X(80).
    05 PF-OCCUPATION        PIC X(40).
    05 PF-EMPLOYER          PIC X(50).

WORKING-STORAGE SECTION.
01  WS-FILE-STATUS          PIC XX.
01  WS-ARGC                 PIC 9(2).
01  WS-ARG-INDEX            PIC 9(2).
01  WS-OPERATION            PIC X(10).
01  WS-ARG-ACCOUNT          PIC X(10).
01  WS-ARG-VALUE            PIC X(80).
01  WS-BALANCE-OUT          PIC 9(9)V99.
01  WS-AMOUNT               PIC 9(9)V99.
01  WS-END-OF-FILE          PIC X VALUE "N".

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

    OPEN I-O ACCOUNT-FILE
    IF WS-FILE-STATUS = "35"
        CLOSE ACCOUNT-FILE
        OPEN OUTPUT ACCOUNT-FILE
        CLOSE ACCOUNT-FILE
        OPEN I-O ACCOUNT-FILE
    END-IF

        OPEN I-O CUSTOMER-FILE
        IF WS-FILE-STATUS = "35"
            CLOSE CUSTOMER-FILE
            OPEN OUTPUT CUSTOMER-FILE
            CLOSE CUSTOMER-FILE
            OPEN I-O CUSTOMER-FILE
        END-IF

    EVALUATE FUNCTION UPPER-CASE(WS-OPERATION)
        WHEN "REGISTER"  PERFORM DO-REGISTER
        WHEN "BALANCE"   PERFORM DO-BALANCE
        WHEN "DEPOSIT"   PERFORM DO-DEPOSIT
        WHEN "WITHDRAW"  PERFORM DO-WITHDRAW
        WHEN "LIST"      PERFORM DO-LIST
        WHEN OTHER       DISPLAY "ERR|Operación inválida"
    END-EVALUATE

    CLOSE ACCOUNT-FILE CUSTOMER-FILE
    STOP RUN.

DO-REGISTER.
    IF WS-ARGC < 9
        DISPLAY "ERR|Argumentos insuficientes"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-ACCOUNT FROM ARGUMENT-VALUE
        MOVE 3 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE

        MOVE FUNCTION NUMVAL(WS-ARG-ACCOUNT) TO FD-ACCOUNT-NUMBER
        MOVE WS-ARG-VALUE TO FD-OWNER-NAME
        MOVE 0 TO FD-BALANCE

        WRITE ACCOUNT-RECORD
        IF WS-FILE-STATUS = "00"
            MOVE FD-ACCOUNT-NUMBER TO PF-ACCOUNT-NUMBER
            MOVE 4 TO WS-ARG-INDEX
            DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
            ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE
            MOVE WS-ARG-VALUE TO PF-DOCUMENT
            MOVE 5 TO WS-ARG-INDEX
            DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
            ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE
            MOVE WS-ARG-VALUE TO PF-EMAIL
            MOVE 6 TO WS-ARG-INDEX
            DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
            ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE
            MOVE WS-ARG-VALUE TO PF-PHONE
            MOVE 7 TO WS-ARG-INDEX
            DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
            ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE
            MOVE WS-ARG-VALUE TO PF-ADDRESS
            MOVE 8 TO WS-ARG-INDEX
            DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
            ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE
            MOVE WS-ARG-VALUE TO PF-OCCUPATION
            MOVE 9 TO WS-ARG-INDEX
            DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
            ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE
            MOVE WS-ARG-VALUE TO PF-EMPLOYER
            WRITE CUSTOMER-RECORD
            IF WS-FILE-STATUS = "00"
                DISPLAY "OK|Cuenta y perfil registrados"
            ELSE
                DISPLAY "ERR|La cuenta se registró, pero el perfil no pudo guardarse"
            END-IF
        ELSE
            DISPLAY "ERR|La cuenta ya existe o no se pudo registrar"
        END-IF
    END-IF.

DO-BALANCE.
    IF WS-ARGC < 2
        DISPLAY "ERR|Argumentos insuficientes"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-ACCOUNT FROM ARGUMENT-VALUE
        MOVE FUNCTION NUMVAL(WS-ARG-ACCOUNT) TO FD-ACCOUNT-NUMBER

        READ ACCOUNT-FILE
            INVALID KEY
                DISPLAY "ERR|Cuenta no encontrada"
            NOT INVALID KEY
                MOVE FD-BALANCE TO WS-BALANCE-OUT
                DISPLAY "OK|" FUNCTION TRIM(FD-OWNER-NAME)
                    "|" WS-BALANCE-OUT
        END-READ
    END-IF.

DO-DEPOSIT.
    IF WS-ARGC < 3
        DISPLAY "ERR|Argumentos insuficientes"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-ACCOUNT FROM ARGUMENT-VALUE
        MOVE 3 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE

        MOVE FUNCTION NUMVAL(WS-ARG-ACCOUNT) TO FD-ACCOUNT-NUMBER
        MOVE FUNCTION NUMVAL(WS-ARG-VALUE) TO WS-AMOUNT

        READ ACCOUNT-FILE
            INVALID KEY
                DISPLAY "ERR|Cuenta no encontrada"
            NOT INVALID KEY
                ADD WS-AMOUNT TO FD-BALANCE
                REWRITE ACCOUNT-RECORD
                MOVE FD-BALANCE TO WS-BALANCE-OUT
                DISPLAY "OK|" WS-BALANCE-OUT
        END-READ
    END-IF.

DO-WITHDRAW.
    IF WS-ARGC < 3
        DISPLAY "ERR|Argumentos insuficientes"
    ELSE
        MOVE 2 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-ACCOUNT FROM ARGUMENT-VALUE
        MOVE 3 TO WS-ARG-INDEX
        DISPLAY WS-ARG-INDEX UPON ARGUMENT-NUMBER
        ACCEPT WS-ARG-VALUE FROM ARGUMENT-VALUE

        MOVE FUNCTION NUMVAL(WS-ARG-ACCOUNT) TO FD-ACCOUNT-NUMBER
        MOVE FUNCTION NUMVAL(WS-ARG-VALUE) TO WS-AMOUNT

        READ ACCOUNT-FILE
            INVALID KEY
                DISPLAY "ERR|Cuenta no encontrada"
            NOT INVALID KEY
                IF WS-AMOUNT > FD-BALANCE
                    DISPLAY "ERR|Fondos insuficientes"
                ELSE
                    SUBTRACT WS-AMOUNT FROM FD-BALANCE
                    REWRITE ACCOUNT-RECORD
                    MOVE FD-BALANCE TO WS-BALANCE-OUT
                    DISPLAY "OK|" WS-BALANCE-OUT
                END-IF
        END-READ
    END-IF.

DO-LIST.
    MOVE "N" TO WS-END-OF-FILE
    MOVE ZEROS TO FD-ACCOUNT-NUMBER
    START ACCOUNT-FILE KEY IS GREATER THAN OR EQUAL FD-ACCOUNT-NUMBER
        INVALID KEY
            MOVE "Y" TO WS-END-OF-FILE
    END-START

    PERFORM UNTIL WS-END-OF-FILE = "Y"
        READ ACCOUNT-FILE NEXT RECORD
            AT END
                MOVE "Y" TO WS-END-OF-FILE
            NOT AT END
                MOVE FD-BALANCE TO WS-BALANCE-OUT
                MOVE FD-ACCOUNT-NUMBER TO PF-ACCOUNT-NUMBER
                READ CUSTOMER-FILE
                    INVALID KEY
                        DISPLAY "ROW|" FD-ACCOUNT-NUMBER "|"
                            FUNCTION TRIM(FD-OWNER-NAME) "|" WS-BALANCE-OUT
                    NOT INVALID KEY
                        DISPLAY "ROW|" FD-ACCOUNT-NUMBER "|"
                            FUNCTION TRIM(FD-OWNER-NAME) "|" WS-BALANCE-OUT "|"
                            FUNCTION TRIM(PF-DOCUMENT) "|"
                            FUNCTION TRIM(PF-EMAIL) "|"
                            FUNCTION TRIM(PF-PHONE) "|"
                            FUNCTION TRIM(PF-ADDRESS) "|"
                            FUNCTION TRIM(PF-OCCUPATION) "|"
                            FUNCTION TRIM(PF-EMPLOYER)
                END-READ
        END-READ
    END-PERFORM
    DISPLAY "END".
