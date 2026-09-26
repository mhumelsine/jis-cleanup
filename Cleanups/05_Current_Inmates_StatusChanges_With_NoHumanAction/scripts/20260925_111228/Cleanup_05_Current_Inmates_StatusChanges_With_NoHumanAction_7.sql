DECLARE
    v_object_count PLS_INTEGER;
BEGIN
    ----------------------------------------------------------------------------
    -- JISREM.CLEANUP
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_object_count
    FROM ALL_TABLES
    WHERE owner = 'JISREM'
      AND table_name = 'CLEANUP';

    IF v_object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE JISREM.CLEANUP
            (
                cleanup_id      VARCHAR2(50)     NOT NULL,
                cleanup_name    VARCHAR2(100)  NOT NULL,
                cleanup_date    DATE DEFAULT SYSDATE NOT NULL,
                description     VARCHAR2(1000) NOT NULL,
                requested_by    VARCHAR2(128),
                status          VARCHAR2(20) NOT NULL,

                CONSTRAINT REM_CLEANUP_PK
                    PRIMARY KEY (cleanup_id),

                CONSTRAINT REM_CLEANUP_NAME_UQ
                    UNIQUE (cleanup_name)
            )
        ';

        DBMS_OUTPUT.PUT_LINE('Created JISREM.CLEANUP');
    ELSE
        DBMS_OUTPUT.PUT_LINE('JISREM.CLEANUP already exists');
    END IF;

    ----------------------------------------------------------------------------
    -- JISREM.CLEANUP_SEQ
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_object_count
    FROM ALL_SEQUENCES
    WHERE sequence_owner = 'JISREM'
      AND sequence_name = 'CLEANUP_SEQ';

    IF v_object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE JISREM.CLEANUP_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
        ';

        DBMS_OUTPUT.PUT_LINE('Created JISREM.CLEANUP_SEQ');
    ELSE
        DBMS_OUTPUT.PUT_LINE('JISREM.CLEANUP_SEQ already exists');
    END IF;

    ----------------------------------------------------------------------------
    -- JISREM.CLEANUP_CASE_QUEUE
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_object_count
    FROM ALL_TABLES
    WHERE owner = 'JISREM'
      AND table_name = 'CLEANUP_CASE_QUEUE';

    IF v_object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE JISREM.CLEANUP_CASE_QUEUE
            (
                cleanup_id VARCHAR2(50) NOT NULL,
                case_id    VARCHAR2(50) NOT NULL,
                charge_id  VARCHAR2(50) NOT NULL,
                spn_id     VARCHAR2(50) NOT NULL,
                status     VARCHAR2(50) NOT NULL,
                message    VARCHAR2(512) NULL,    

                CONSTRAINT REM_CLN_CASE_Q_PK
                    PRIMARY KEY (cleanup_id, charge_id),

                CONSTRAINT REM_CLN_CASE_Q_FK
                    FOREIGN KEY (cleanup_id)
                    REFERENCES JISREM.CLEANUP (cleanup_id)
            )
        ';

        DBMS_OUTPUT.PUT_LINE('Created JISREM.CLEANUP_CASE_QUEUE');
    ELSE
        DBMS_OUTPUT.PUT_LINE('JISREM.CLEANUP_CASE_QUEUE already exists');
    END IF;

    ----------------------------------------------------------------------------
    -- JISREM.CLEANUP_LOG
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_object_count
    FROM ALL_TABLES
    WHERE owner = 'JISREM'
      AND table_name = 'CLEANUP_LOG';

    IF v_object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE JISREM.CLEANUP_LOG
            (
                cleanup_id    VARCHAR(50)    NOT NULL,
                charge_id     VARCHAR2(50)  NULL,
                log_sequence  NUMBER       NOT NULL,
                logged_at     DATE DEFAULT SYSDATE NOT NULL,
                step_name     VARCHAR2(50) NULL,
                message       VARCHAR2(512) NULL,
                affected_rows NUMBER,

                CONSTRAINT REM_CLEANUP_LOG_PK
                    PRIMARY KEY
                        (log_sequence)
            )
        ';

        DBMS_OUTPUT.PUT_LINE('Created JISREM.CLEANUP_LOG');
    ELSE
        DBMS_OUTPUT.PUT_LINE('JISREM.CLEANUP_LOG already exists');
    END IF;

    ----------------------------------------------------------------------------
    -- JISREM.CLEANUP_LOG_SEQ
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_object_count
    FROM ALL_SEQUENCES
    WHERE sequence_owner = 'JISREM'
      AND sequence_name = 'CLEANUP_LOG_SEQ';

    IF v_object_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE JISREM.CLEANUP_LOG_SEQ
                START WITH 1
                INCREMENT BY 1
                NOCACHE
        ';

        DBMS_OUTPUT.PUT_LINE('Created JISREM.CLEANUP_LOG_SEQ');
    ELSE
        DBMS_OUTPUT.PUT_LINE('JISREM.CLEANUP_LOG_SEQ already exists');
    END IF;
END;
/



-------------END DDL--------------------------



CREATE OR REPLACE PROCEDURE JISREM.LOG
(
    p_cleanup_id    IN JISREM.CLEANUP_LOG.cleanup_id%TYPE,
    p_charge_id       IN JISREM.CLEANUP_LOG.charge_id%TYPE   DEFAULT NULL,
    p_step_name     IN JISREM.CLEANUP_LOG.step_name%TYPE     DEFAULT NULL,
    p_message       IN JISREM.CLEANUP_LOG.message%TYPE       DEFAULT NULL,
    p_affected_rows IN JISREM.CLEANUP_LOG.affected_rows%TYPE DEFAULT NULL
)
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO JISREM.CLEANUP_LOG
    (
        cleanup_id,
        charge_id,
        log_sequence,
        logged_at,
        step_name,
        message,
        affected_rows
    )
    VALUES
    (
        p_cleanup_id,
        p_charge_id,
        JISREM.CLEANUP_LOG_SEQ.NEXTVAL,
        SYSDATE,
        p_step_name,
        p_message,
        p_affected_rows
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END LOG;
/

DECLARE
    v_table_count PLS_INTEGER;
BEGIN
    SELECT
        COUNT(*)
    INTO
        v_table_count
    FROM
        ALL_TABLES
    WHERE
        owner = 'JISREM'
        AND table_name = 'CHARGE';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.CHARGE AS 
            SELECT * 
            FROM JISJDW.CHARGE
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CHARGE ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CHARGE MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CHARGE 
            ADD CONSTRAINT REM_CHARGE_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                CHARGE_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CHARGE 
            ADD CONSTRAINT REM_CHARGE_FK 
            FOREIGN KEY (cleanup_id) 
            REFERENCES JISREM.CLEANUP (cleanup_id)';
    END IF;
END;
/

DECLARE
    v_table_count PLS_INTEGER;
BEGIN
    SELECT
        COUNT(*)
    INTO
        v_table_count
    FROM
        ALL_TABLES
    WHERE
        owner = 'JISREM'
        AND table_name = 'CJIS_DOCKET';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.CJIS_DOCKET AS 
            SELECT * 
            FROM JISJDW.CJIS_DOCKET
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET 
            ADD CONSTRAINT REM_CJIS_DOCKET_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                CJIS_DOCKET_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET 
            ADD CONSTRAINT REM_CJIS_DOCKET_FK 
            FOREIGN KEY (cleanup_id) 
            REFERENCES JISREM.CLEANUP (cleanup_id)';
    END IF;
END;
/

DECLARE
    v_table_count PLS_INTEGER;
BEGIN
    SELECT
        COUNT(*)
    INTO
        v_table_count
    FROM
        ALL_TABLES
    WHERE
        owner = 'JISREM'
        AND table_name = 'CJIS_DOCKET';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.CJIS_DOCKET AS 
            SELECT * 
            FROM JISJDW.CJIS_DOCKET
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET 
            ADD CONSTRAINT REM_CJIS_DOCKET_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                CJIS_DOCKET_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CJIS_DOCKET 
            ADD CONSTRAINT REM_CJIS_DOCKET_FK 
            FOREIGN KEY (cleanup_id) 
            REFERENCES JISREM.CLEANUP (cleanup_id)';
    END IF;
END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;



DECLARE
    v_existing NUMBER; 
BEGIN

    IF 0 IS NULL OR 0 NOT IN (0,1) THEN 
         RAISE_APPLICATION_ERROR(-20001,'0 must be 0 or 1'); END IF;
    
    SELECT COUNT(*) 
    INTO v_existing 
    FROM JISREM.CLEANUP 
    WHERE cleanup_name='20260925_111228_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_7';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260925_111228_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_7] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44','20260925_111228_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_7','Target current Inmates with changes to status, location, or bond amount that have no human activity in the audit trail after the first status, location, or bond amt change in the go live period.','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2024CF1193A1', '1199593', '275777', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF2376A8', '1232388', '279687', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF246A11', '1216061', '274757', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF2627A8', '1231061', '279687', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF2684A1', '1231426', '164160', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF2767A1', '1231883', '265776', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF2830A9', '1232351', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF2975A1', '1233295', '269541', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF3157A5', '1234420', '279502', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF3193A3', '1234656', '252306', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF3318A1', '1235315', '269541', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF43A1', '1214947', '219553', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF599A1', '1218089', '155506', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF599A4', '1218088', '155506', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF604A1', '1218139', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF604A3', '1218141', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF615A3', '1218198', '278302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF662A1', '1218432', '278302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF713A3', '1223048', '199183', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025CF839A1', '1219692', '259177', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025HH820A3', '1229488', '266651', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025MM1723A1', '1231023', '263453', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2025MM757A3', '1221574', '267704', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1094A2', '1243871', '280649', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1177A2', '1244327', '214849', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1183A1', '1244368', '145279', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1202A1', '1244511', '250214', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1202A5', '1244512', '250214', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1225A5', '1244622', '46065', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1282A1', '1244894', '59944', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1282A3', '1244896', '59944', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1295A1', '1244951', '11163', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1364A1', '1245378', '262153', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1627A2', '1246895', '281903', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1668A2', '1247084', '276396', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1780A2', '1250321', '267980', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1798A1', '1247865', '217886', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1845A10', '1248416', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1845A23', '1248429', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1845A24', '1248430', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1845A25', '1248431', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1845A5', '1248411', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1845A7', '1248413', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1848A1', '1248460', '275406', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1265A1', '1244814', '269672', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1848A2', '1248461', '275406', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1864A3', '1248534', '278219', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1864A5', '1248537', '278219', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1867A2', '1248551', '73420', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1893A3', '1248740', '233866', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1953A5', '1249707', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1953A6', '1249708', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF1953A8', '1249711', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF225A3', '1238213', '276279', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF284A1', '1238568', '233299', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF465A1', '1239516', '274326', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF686A1', '1240873', '140803', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF704A6', '1241061', '180807', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026CF924A1', '1242913', '250888', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026HH605A1', '1248060', '257302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2026MM533A1', '1241161', '221899', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2006CF1959A3', '594616', '9072', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2009CF2608A4', '716639', '98344', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2009CF2608A5', '716642', '98344', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2012CF2850A1', '829001', '34745', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2016CF161A4', '974489', '236300', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2019CF3817A1', '1093070', '259456', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2019MM2731A3', '1091701', '251232', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2020CF1960A2', '1109223', '105906', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2021CF1482A3', '1132660', '266601', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF1388A1', '1154314', '225991', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF1599A1', '1155491', '232816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF1599A3', '1155492', '232816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF1599A8', '1158031', '232816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF1948A3', '1162507', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF1982A5', '1157429', '260690', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF1982A6', '1157430', '260690', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF2542A1', '1160726', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF2650A2', '1161396', '232816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2022CF409A1', '1149128', '268168', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF1135A3', '1175786', '272689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF1138A1', '1175801', '272689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF185A1', '1169770', '105906', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF185A2', '1169771', '105906', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF189B14', '1176123', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF189B20', '1176210', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF189B7', '1176117', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF189E36', '1176265', '272689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF189E39', '1176266', '272689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF196A11', '1169866', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF196A16', '1169871', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF2547A2', '1185943', '273890', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF275A7', '1170415', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF276A1', '1170419', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF2912A1', '1187955', '274192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2023CF513A3', '1171823', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2024CF100C2', '1201244', '275648', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2024CF1764B5', '1204002', '225002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2024CF2297A1', '1206261', '186312', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c6a0dd9c-460c-41a9-a604-ef0b649b7b44', '2024CF2605A1', '1208013', '266181', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260925_111228_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_7] started'
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocationBondAmount::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1199593 CJIS_CASE_NUMBER 2024CF1193A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2024CF1193A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1199593',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1199593;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1199593';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1199593',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1199593'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1199593';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1199593';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1199593',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1199593
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1199593
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1199593',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1199593
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1199593', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1199593',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1199593',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1199593';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1199593',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1199593';
        
END;
/

/***********************************************************
***** CHARGE 1232388 CJIS_CASE_NUMBER 2025CF2376A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF2376A8'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1232388',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1232388;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1232388';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1232388',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232388'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1232388';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232388';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1232388',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232388
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232388
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1232388',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232388
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232388', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1232388',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1232388',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1232388';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1232388',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1232388';
        
END;
/

/***********************************************************
***** CHARGE 1216061 CJIS_CASE_NUMBER 2025CF246A11
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF246A11'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1216061',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1216061;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1216061';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1216061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216061'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216061';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216061';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1216061',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1216061',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216061
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216061', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1216061',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1216061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1216061';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1216061',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1216061';
        
END;
/

/***********************************************************
***** CHARGE 1231061 CJIS_CASE_NUMBER 2025CF2627A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF2627A8'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231061',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1231061;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1231061';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231061'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1231061';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231061';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231061',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231061',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231061
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231061', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231061',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1231061';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1231061',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1231061';
        
END;
/

/***********************************************************
***** CHARGE 1231426 CJIS_CASE_NUMBER 2025CF2684A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF2684A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231426',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1231426;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1231426';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231426',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231426'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1231426';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231426';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231426',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231426
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231426
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231426',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231426
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231426', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231426',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231426',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1231426';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1231426',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1231426';
        
END;
/

/***********************************************************
***** CHARGE 1231883 CJIS_CASE_NUMBER 2025CF2767A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF2767A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231883',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1231883;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1231883';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231883',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231883'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1231883';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231883';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231883',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231883
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231883
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231883',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231883
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231883', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231883',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231883',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1231883';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1231883',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1231883';
        
END;
/

/***********************************************************
***** CHARGE 1232351 CJIS_CASE_NUMBER 2025CF2830A9
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF2830A9'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1232351',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1232351;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1232351';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1232351',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232351'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1232351';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232351';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1232351',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232351
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232351
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1232351',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232351
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232351', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1232351',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1232351',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1232351';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1232351',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1232351';
        
END;
/

/***********************************************************
***** CHARGE 1233295 CJIS_CASE_NUMBER 2025CF2975A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF2975A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1233295',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1233295;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1233295';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1233295',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233295'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233295';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233295';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1233295',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233295
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233295
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1233295',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233295
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233295', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1233295',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1233295',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1233295';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1233295',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1233295';
        
END;
/

/***********************************************************
***** CHARGE 1234420 CJIS_CASE_NUMBER 2025CF3157A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF3157A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1234420',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1234420;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1234420';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1234420',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234420'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1234420';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234420';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1234420',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234420
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234420
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1234420',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234420
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234420', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1234420',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1234420',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1234420';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1234420',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1234420';
        
END;
/

/***********************************************************
***** CHARGE 1234656 CJIS_CASE_NUMBER 2025CF3193A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF3193A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1234656',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1234656;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1234656';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1234656',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234656'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1234656';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234656';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1234656',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234656
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234656
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1234656',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234656
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234656', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1234656',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1234656',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1234656';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1234656',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1234656';
        
END;
/

/***********************************************************
***** CHARGE 1235315 CJIS_CASE_NUMBER 2025CF3318A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF3318A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1235315',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1235315;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1235315';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1235315',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235315'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1235315';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235315';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1235315',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235315
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235315
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1235315',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1235315
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235315', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1235315',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1235315',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1235315';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1235315',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1235315';
        
END;
/

/***********************************************************
***** CHARGE 1214947 CJIS_CASE_NUMBER 2025CF43A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF43A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1214947',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1214947;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1214947';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1214947',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214947'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1214947';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214947';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1214947',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214947
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214947
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1214947',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1214947
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1214947', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1214947',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1214947',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1214947';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1214947',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1214947';
        
END;
/

/***********************************************************
***** CHARGE 1218089 CJIS_CASE_NUMBER 2025CF599A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF599A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218089',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1218089;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1218089';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218089',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218089'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218089';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218089';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218089',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218089
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218089
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218089',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218089
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218089', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218089',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218089',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1218089';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1218089',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1218089';
        
END;
/

/***********************************************************
***** CHARGE 1218088 CJIS_CASE_NUMBER 2025CF599A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF599A4'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218088',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1218088;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1218088';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218088',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218088'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218088';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218088';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218088',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218088
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218088
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218088',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218088
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218088', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218088',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218088',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1218088';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1218088',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1218088';
        
END;
/

/***********************************************************
***** CHARGE 1218139 CJIS_CASE_NUMBER 2025CF604A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF604A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218139',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1218139;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1218139';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218139',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218139'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1218139';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218139';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218139',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218139
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218139
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218139',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218139
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218139', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218139',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218139',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1218139';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1218139',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1218139';
        
END;
/

/***********************************************************
***** CHARGE 1218141 CJIS_CASE_NUMBER 2025CF604A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF604A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218141',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1218141;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1218141';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218141',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218141'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '15000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1218141';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218141';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218141',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218141
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218141
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218141',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218141
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218141', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218141',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218141',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1218141';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1218141',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1218141';
        
END;
/

/***********************************************************
***** CHARGE 1218198 CJIS_CASE_NUMBER 2025CF615A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF615A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218198',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1218198;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1218198';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218198',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218198'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218198';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218198';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218198',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218198
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218198
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218198',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218198
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218198', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218198',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218198',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1218198';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1218198',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1218198';
        
END;
/

/***********************************************************
***** CHARGE 1218432 CJIS_CASE_NUMBER 2025CF662A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF662A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218432',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1218432;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1218432';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218432',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218432'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218432';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218432';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218432',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218432
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218432
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218432',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218432
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218432', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1218432',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1218432',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1218432';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1218432',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1218432';
        
END;
/

/***********************************************************
***** CHARGE 1223048 CJIS_CASE_NUMBER 2025CF713A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF713A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1223048',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1223048;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1223048';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1223048',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1223048'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1223048';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1223048';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1223048',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1223048
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1223048
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1223048',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1223048
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1223048', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1223048',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1223048',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1223048';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1223048',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1223048';
        
END;
/

/***********************************************************
***** CHARGE 1219692 CJIS_CASE_NUMBER 2025CF839A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF839A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1219692',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1219692;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1219692';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1219692',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219692'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1219692';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219692';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1219692',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219692
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219692
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1219692',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1219692
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1219692', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1219692',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1219692',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1219692';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1219692',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1219692';
        
END;
/

/***********************************************************
***** CHARGE 1229488 CJIS_CASE_NUMBER 2025HH820A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025HH820A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1229488',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1229488;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1229488';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1229488',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229488'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1229488';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229488';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1229488',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229488
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229488
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1229488',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1229488
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1229488', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1229488',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1229488',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1229488';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1229488',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1229488';
        
END;
/

/***********************************************************
***** CHARGE 1231023 CJIS_CASE_NUMBER 2025MM1723A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025MM1723A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231023',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1231023;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1231023';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231023',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231023'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1231023';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231023';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231023',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231023
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231023
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231023',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231023
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231023', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1231023',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1231023',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1231023';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1231023',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1231023';
        
END;
/

/***********************************************************
***** CHARGE 1221574 CJIS_CASE_NUMBER 2025MM757A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025MM757A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1221574',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1221574;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1221574';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1221574',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1221574'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1221574';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1221574';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1221574',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1221574
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1221574
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1221574',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1221574
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1221574', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1221574',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1221574',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1221574';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1221574',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1221574';
        
END;
/

/***********************************************************
***** CHARGE 1243871 CJIS_CASE_NUMBER 2026CF1094A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1094A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1243871',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1243871;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1243871';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1243871',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243871'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1243871';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243871';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1243871',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1243871',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243871
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243871', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1243871',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1243871',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1243871';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1243871',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1243871';
        
END;
/

/***********************************************************
***** CHARGE 1244327 CJIS_CASE_NUMBER 2026CF1177A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1177A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244327',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244327;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244327';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244327',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244327'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244327';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244327';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244327',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244327
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244327
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244327',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244327
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244327', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244327',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244327',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244327';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244327',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244327';
        
END;
/

/***********************************************************
***** CHARGE 1244368 CJIS_CASE_NUMBER 2026CF1183A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1183A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244368',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244368;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244368';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244368',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244368'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'RLSDBE'
WHERE CHARGE_ID = '1244368';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244368';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244368',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244368
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244368
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244368',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244368
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244368', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244368',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244368',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244368';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244368',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244368';
        
END;
/

/***********************************************************
***** CHARGE 1244511 CJIS_CASE_NUMBER 2026CF1202A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1202A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244511',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244511;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244511';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244511',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244511'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244511';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244511';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244511',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244511
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244511
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244511',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244511
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244511', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244511',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244511',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244511';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244511',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244511';
        
END;
/

/***********************************************************
***** CHARGE 1244512 CJIS_CASE_NUMBER 2026CF1202A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1202A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244512',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244512;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244512';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244512',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244512'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1244512';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244512';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244512',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244512
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244512
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244512',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244512
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244512', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244512',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244512',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244512';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244512',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244512';
        
END;
/

/***********************************************************
***** CHARGE 1244622 CJIS_CASE_NUMBER 2026CF1225A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1225A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244622',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244622;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244622';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244622',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244622'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1244622';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244622';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244622',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244622
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244622
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244622',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244622
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244622', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244622',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244622',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244622';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244622',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244622';
        
END;
/

/***********************************************************
***** CHARGE 1244894 CJIS_CASE_NUMBER 2026CF1282A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1282A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244894',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244894;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244894';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244894',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244894'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '25000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244894';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244894';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244894',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244894
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244894
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244894',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244894
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244894', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244894',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244894',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244894';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244894',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244894';
        
END;
/

/***********************************************************
***** CHARGE 1244896 CJIS_CASE_NUMBER 2026CF1282A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1282A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244896',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244896;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244896';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244896',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244896'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '1000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244896';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244896';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244896',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244896
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244896
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244896',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244896
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244896', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244896',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244896',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244896';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244896',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244896';
        
END;
/

/***********************************************************
***** CHARGE 1244951 CJIS_CASE_NUMBER 2026CF1295A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1295A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244951',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244951;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244951';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244951',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244951'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '250',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1244951';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244951';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244951',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244951
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244951
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244951',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244951
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244951', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244951',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244951',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244951';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244951',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244951';
        
END;
/

/***********************************************************
***** CHARGE 1245378 CJIS_CASE_NUMBER 2026CF1364A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1364A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1245378',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1245378;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1245378';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1245378',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245378'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1245378';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245378';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1245378',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245378
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245378
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1245378',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245378
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245378', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1245378',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1245378',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1245378';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1245378',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1245378';
        
END;
/

/***********************************************************
***** CHARGE 1246895 CJIS_CASE_NUMBER 2026CF1627A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1627A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1246895',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1246895;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1246895';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1246895',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246895'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1246895';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246895';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1246895',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246895
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246895
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1246895',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246895
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246895', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1246895',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1246895',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1246895';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1246895',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1246895';
        
END;
/

/***********************************************************
***** CHARGE 1247084 CJIS_CASE_NUMBER 2026CF1668A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1668A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1247084',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1247084;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1247084';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1247084',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247084'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1247084';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247084';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1247084',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247084
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247084
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1247084',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247084
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247084', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1247084',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1247084',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1247084';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1247084',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1247084';
        
END;
/

/***********************************************************
***** CHARGE 1250321 CJIS_CASE_NUMBER 2026CF1780A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1780A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1250321',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1250321;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1250321';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1250321',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250321'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'N',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1250321';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250321';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1250321',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250321
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250321
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1250321',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1250321
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1250321', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1250321',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1250321',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1250321';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1250321',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1250321';
        
END;
/

/***********************************************************
***** CHARGE 1247865 CJIS_CASE_NUMBER 2026CF1798A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1798A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1247865',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1247865;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1247865';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1247865',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247865'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1247865';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247865';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1247865',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247865
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247865
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1247865',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247865
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247865', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1247865',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1247865',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1247865';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1247865',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1247865';
        
END;
/

/***********************************************************
***** CHARGE 1248416 CJIS_CASE_NUMBER 2026CF1845A10
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1845A10'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248416',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248416;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248416';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248416',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248416'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248416';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248416';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248416',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248416
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248416
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248416',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248416
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248416', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248416',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248416',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248416';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248416',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248416';
        
END;
/

/***********************************************************
***** CHARGE 1248429 CJIS_CASE_NUMBER 2026CF1845A23
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1845A23'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248429',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248429;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248429';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248429',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248429'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248429';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248429';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248429',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248429',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248429
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248429', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248429',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248429',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248429';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248429',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248429';
        
END;
/

/***********************************************************
***** CHARGE 1248430 CJIS_CASE_NUMBER 2026CF1845A24
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1845A24'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248430',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248430;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248430';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248430',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248430'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248430';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248430';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248430',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248430
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248430
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248430',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248430
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248430', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248430',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248430',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248430';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248430',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248430';
        
END;
/

/***********************************************************
***** CHARGE 1248431 CJIS_CASE_NUMBER 2026CF1845A25
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1845A25'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248431',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248431;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248431';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248431',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248431'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248431';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248431';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248431',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248431
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248431
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248431',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248431
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248431', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248431',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248431',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248431';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248431',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248431';
        
END;
/

/***********************************************************
***** CHARGE 1248411 CJIS_CASE_NUMBER 2026CF1845A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1845A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248411',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248411;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248411';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248411',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248411'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248411';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248411';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248411',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248411
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248411
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248411',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248411
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248411', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248411',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248411',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248411';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248411',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248411';
        
END;
/

/***********************************************************
***** CHARGE 1248413 CJIS_CASE_NUMBER 2026CF1845A7
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1845A7'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248413',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248413;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248413';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248413',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248413'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248413';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248413';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248413',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248413
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248413
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248413',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248413
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248413', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248413',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248413',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248413';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248413',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248413';
        
END;
/

/***********************************************************
***** CHARGE 1248460 CJIS_CASE_NUMBER 2026CF1848A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1848A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248460',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248460;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248460';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248460',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248460'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1248460';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248460';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248460',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248460
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248460
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248460',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248460
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248460', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248460',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248460',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248460';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248460',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248460';
        
END;
/

/***********************************************************
***** CHARGE 1244814 CJIS_CASE_NUMBER 2026CF1265A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1265A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244814',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1244814;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1244814';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244814',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244814'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '75000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244814';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244814';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244814',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244814
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244814
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244814',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244814
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244814', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1244814',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1244814',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1244814';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1244814',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1244814';
        
END;
/

/***********************************************************
***** CHARGE 1248461 CJIS_CASE_NUMBER 2026CF1848A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1848A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248461',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248461;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248461';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248461',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248461'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1248461';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248461';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248461',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248461
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248461
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248461',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248461
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248461', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248461',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248461',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248461';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248461',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248461';
        
END;
/

/***********************************************************
***** CHARGE 1248534 CJIS_CASE_NUMBER 2026CF1864A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1864A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248534',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248534;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248534';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248534',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248534'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1248534';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248534';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248534',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248534
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248534
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248534',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248534
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248534', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248534',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248534',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248534';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248534',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248534';
        
END;
/

/***********************************************************
***** CHARGE 1248537 CJIS_CASE_NUMBER 2026CF1864A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1864A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248537',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248537;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248537';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248537',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248537'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1248537';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248537';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248537',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248537
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248537
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248537',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248537
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248537', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248537',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248537',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248537';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248537',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248537';
        
END;
/

/***********************************************************
***** CHARGE 1248551 CJIS_CASE_NUMBER 2026CF1867A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1867A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248551',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248551;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248551';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248551',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248551'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1248551';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248551';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248551',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248551
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248551
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248551',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248551
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248551', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248551',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248551',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248551';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248551',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248551';
        
END;
/

/***********************************************************
***** CHARGE 1248740 CJIS_CASE_NUMBER 2026CF1893A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1893A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248740',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248740;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248740';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248740',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248740'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248740';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248740';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248740',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248740
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248740
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248740',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248740
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248740', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248740',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248740',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248740';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248740',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248740';
        
END;
/

/***********************************************************
***** CHARGE 1249707 CJIS_CASE_NUMBER 2026CF1953A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1953A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249707',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1249707;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1249707';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249707',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249707'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1249707';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249707';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249707',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249707
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249707
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249707',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249707
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249707', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249707',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249707',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1249707';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1249707',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1249707';
        
END;
/

/***********************************************************
***** CHARGE 1249708 CJIS_CASE_NUMBER 2026CF1953A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1953A6'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249708',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1249708;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1249708';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249708'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1249708';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249708';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249708',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249708
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249708
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249708',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249708
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249708', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249708',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1249708';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1249708',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1249708';
        
END;
/

/***********************************************************
***** CHARGE 1249711 CJIS_CASE_NUMBER 2026CF1953A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF1953A8'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249711',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1249711;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1249711';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249711',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249711'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1249711';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249711';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249711',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249711
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249711
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249711',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249711
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249711', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1249711',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1249711',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1249711';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1249711',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1249711';
        
END;
/

/***********************************************************
***** CHARGE 1238213 CJIS_CASE_NUMBER 2026CF225A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF225A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1238213',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1238213;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1238213';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1238213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238213'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1238213';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238213';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1238213',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238213
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238213
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1238213',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1238213
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238213', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1238213',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1238213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1238213';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1238213',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1238213';
        
END;
/

/***********************************************************
***** CHARGE 1238568 CJIS_CASE_NUMBER 2026CF284A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF284A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1238568',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1238568;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1238568';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1238568',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238568'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1238568';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238568';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1238568',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238568
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238568
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1238568',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1238568
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238568', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1238568',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1238568',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1238568';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1238568',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1238568';
        
END;
/

/***********************************************************
***** CHARGE 1239516 CJIS_CASE_NUMBER 2026CF465A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF465A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1239516',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1239516;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1239516';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1239516',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239516'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1239516';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239516';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1239516',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239516
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239516
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1239516',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239516
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239516', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1239516',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1239516',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1239516';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1239516',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1239516';
        
END;
/

/***********************************************************
***** CHARGE 1240873 CJIS_CASE_NUMBER 2026CF686A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF686A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1240873',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1240873;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1240873';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1240873',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240873'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1240873';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240873';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1240873',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240873
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240873
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1240873',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240873
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240873', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1240873',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1240873',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1240873';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1240873',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1240873';
        
END;
/

/***********************************************************
***** CHARGE 1241061 CJIS_CASE_NUMBER 2026CF704A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF704A6'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1241061',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1241061;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1241061';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1241061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241061'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1241061';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241061';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1241061',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1241061',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241061
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241061', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1241061',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1241061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1241061';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1241061',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1241061';
        
END;
/

/***********************************************************
***** CHARGE 1242913 CJIS_CASE_NUMBER 2026CF924A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026CF924A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1242913',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1242913;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1242913';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1242913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242913'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1242913';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242913';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1242913',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242913
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242913
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1242913',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242913
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242913', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1242913',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1242913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1242913';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1242913',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1242913';
        
END;
/

/***********************************************************
***** CHARGE 1248060 CJIS_CASE_NUMBER 2026HH605A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026HH605A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248060',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1248060;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1248060';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248060',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248060'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1248060';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248060';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248060',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248060
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248060
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248060',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248060
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248060', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1248060',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1248060',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1248060';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1248060',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1248060';
        
END;
/

/***********************************************************
***** CHARGE 1241161 CJIS_CASE_NUMBER 2026MM533A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM533A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1241161',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1241161;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1241161';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1241161',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241161'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1241161';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241161';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1241161',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241161
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241161
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1241161',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241161
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241161', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1241161',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1241161',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1241161';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1241161',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1241161';
        
END;
/

/***********************************************************
***** CHARGE 594616 CJIS_CASE_NUMBER 2006CF1959A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2006CF1959A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '594616',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 594616;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '594616';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '594616',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '594616'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '594616';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '594616';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '594616',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 594616
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 594616
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '594616',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 594616
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '594616', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '594616',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '594616',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '594616';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '594616',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '594616';
        
END;
/

/***********************************************************
***** CHARGE 716639 CJIS_CASE_NUMBER 2009CF2608A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2009CF2608A4'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '716639',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 716639;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '716639';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '716639',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '716639'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '716639';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '716639';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '716639',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 716639
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 716639
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '716639',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 716639
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '716639', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '716639',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '716639',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '716639';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '716639',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '716639';
        
END;
/

/***********************************************************
***** CHARGE 716642 CJIS_CASE_NUMBER 2009CF2608A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2009CF2608A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '716642',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 716642;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '716642';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '716642',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '716642'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '716642';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '716642';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '716642',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 716642
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 716642
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '716642',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 716642
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '716642', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '716642',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '716642',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '716642';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '716642',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '716642';
        
END;
/

/***********************************************************
***** CHARGE 829001 CJIS_CASE_NUMBER 2012CF2850A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2012CF2850A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '829001',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 829001;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '829001';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '829001',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '829001'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '829001';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '829001';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '829001',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 829001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 829001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '829001',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 829001
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '829001', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '829001',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '829001',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '829001';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '829001',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '829001';
        
END;
/

/***********************************************************
***** CHARGE 974489 CJIS_CASE_NUMBER 2016CF161A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2016CF161A4'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '974489',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 974489;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '974489';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '974489',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '974489'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '974489';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '974489';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '974489',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 974489
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 974489
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '974489',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 974489
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '974489', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '974489',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '974489',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '974489';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '974489',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '974489';
        
END;
/

/***********************************************************
***** CHARGE 1093070 CJIS_CASE_NUMBER 2019CF3817A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2019CF3817A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1093070',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1093070;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1093070';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1093070',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1093070'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1093070';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1093070';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1093070',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1093070
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1093070
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1093070',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1093070
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1093070', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1093070',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1093070',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1093070';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1093070',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1093070';
        
END;
/

/***********************************************************
***** CHARGE 1091701 CJIS_CASE_NUMBER 2019MM2731A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2019MM2731A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1091701',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1091701;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1091701';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1091701',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1091701'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1091701';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1091701';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1091701',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1091701
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1091701
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1091701',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1091701
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1091701', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1091701',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1091701',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1091701';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1091701',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1091701';
        
END;
/

/***********************************************************
***** CHARGE 1109223 CJIS_CASE_NUMBER 2020CF1960A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2020CF1960A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1109223',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1109223;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1109223';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1109223',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1109223'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1109223';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1109223';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1109223',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1109223
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1109223
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1109223',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1109223
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1109223', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1109223',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1109223',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1109223';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1109223',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1109223';
        
END;
/

/***********************************************************
***** CHARGE 1132660 CJIS_CASE_NUMBER 2021CF1482A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2021CF1482A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1132660',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1132660;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1132660';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1132660',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1132660'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1132660';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1132660';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1132660',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1132660
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1132660
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1132660',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1132660
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1132660', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1132660',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1132660',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1132660';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1132660',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1132660';
        
END;
/

/***********************************************************
***** CHARGE 1154314 CJIS_CASE_NUMBER 2022CF1388A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF1388A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1154314',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1154314;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1154314';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1154314',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1154314'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1154314';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1154314';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1154314',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1154314
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1154314
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1154314',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1154314
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1154314', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1154314',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1154314',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1154314';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1154314',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1154314';
        
END;
/

/***********************************************************
***** CHARGE 1155491 CJIS_CASE_NUMBER 2022CF1599A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF1599A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1155491',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1155491;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1155491';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1155491',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155491'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1155491';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155491';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1155491',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1155491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1155491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1155491',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1155491
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1155491', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1155491',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1155491',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1155491';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1155491',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1155491';
        
END;
/

/***********************************************************
***** CHARGE 1155492 CJIS_CASE_NUMBER 2022CF1599A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF1599A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1155492',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1155492;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1155492';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1155492',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155492'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1155492';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155492';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1155492',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1155492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1155492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1155492',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1155492
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1155492', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1155492',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1155492',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1155492';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1155492',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1155492';
        
END;
/

/***********************************************************
***** CHARGE 1158031 CJIS_CASE_NUMBER 2022CF1599A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF1599A8'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1158031',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1158031;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1158031';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1158031',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158031'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1158031';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158031';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1158031',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158031
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158031
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1158031',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1158031
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1158031', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1158031',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1158031',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1158031';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1158031',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1158031';
        
END;
/

/***********************************************************
***** CHARGE 1162507 CJIS_CASE_NUMBER 2022CF1948A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF1948A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1162507',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1162507;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1162507';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1162507',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1162507'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1162507';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1162507';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1162507',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1162507
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1162507
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1162507',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1162507
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1162507', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1162507',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1162507',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1162507';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1162507',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1162507';
        
END;
/

/***********************************************************
***** CHARGE 1157429 CJIS_CASE_NUMBER 2022CF1982A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF1982A5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1157429',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1157429;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1157429';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1157429',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157429'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1157429';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157429';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1157429',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1157429',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1157429
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1157429', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1157429',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1157429',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1157429';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1157429',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1157429';
        
END;
/

/***********************************************************
***** CHARGE 1157430 CJIS_CASE_NUMBER 2022CF1982A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF1982A6'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1157430',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1157430;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1157430';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1157430',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157430'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1157430';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157430';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1157430',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157430
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157430
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1157430',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1157430
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1157430', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1157430',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1157430',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1157430';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1157430',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1157430';
        
END;
/

/***********************************************************
***** CHARGE 1160726 CJIS_CASE_NUMBER 2022CF2542A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF2542A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1160726',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1160726;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1160726';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1160726',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1160726'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '25000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1160726';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1160726';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1160726',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1160726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1160726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1160726',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1160726
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1160726', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1160726',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1160726',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1160726';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1160726',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1160726';
        
END;
/

/***********************************************************
***** CHARGE 1161396 CJIS_CASE_NUMBER 2022CF2650A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF2650A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1161396',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1161396;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1161396';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1161396',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161396'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1161396';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161396';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1161396',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161396
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161396
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1161396',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1161396
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1161396', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1161396',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1161396',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1161396';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1161396',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1161396';
        
END;
/

/***********************************************************
***** CHARGE 1149128 CJIS_CASE_NUMBER 2022CF409A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2022CF409A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1149128',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1149128;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1149128';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1149128',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1149128'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1149128';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1149128';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1149128',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1149128
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1149128
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1149128',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1149128
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1149128', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1149128',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1149128',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1149128';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1149128',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1149128';
        
END;
/

/***********************************************************
***** CHARGE 1175786 CJIS_CASE_NUMBER 2023CF1135A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF1135A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1175786',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1175786;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1175786';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1175786',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175786'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1175786';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175786';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1175786',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175786
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175786
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1175786',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1175786
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1175786', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1175786',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1175786',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1175786';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1175786',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1175786';
        
END;
/

/***********************************************************
***** CHARGE 1175801 CJIS_CASE_NUMBER 2023CF1138A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF1138A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1175801',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1175801;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1175801';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1175801',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175801'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '1000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1175801';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175801';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1175801',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175801
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175801
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1175801',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1175801
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1175801', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1175801',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1175801',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1175801';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1175801',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1175801';
        
END;
/

/***********************************************************
***** CHARGE 1169770 CJIS_CASE_NUMBER 2023CF185A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF185A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169770',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1169770;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1169770';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169770',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169770'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1169770';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169770';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169770',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169770
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169770
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169770',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1169770
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169770', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169770',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169770',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1169770';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1169770',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1169770';
        
END;
/

/***********************************************************
***** CHARGE 1169771 CJIS_CASE_NUMBER 2023CF185A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF185A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169771',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1169771;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1169771';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169771',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169771'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1169771';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169771';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169771',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169771
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169771
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169771',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1169771
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169771', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169771',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169771',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1169771';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1169771',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1169771';
        
END;
/

/***********************************************************
***** CHARGE 1176123 CJIS_CASE_NUMBER 2023CF189B14
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189B14'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176123',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1176123;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1176123';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176123',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176123'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176123';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176123';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176123',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176123
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176123
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176123',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1176123
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176123', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176123',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176123',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1176123';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1176123',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1176123';
        
END;
/

/***********************************************************
***** CHARGE 1176210 CJIS_CASE_NUMBER 2023CF189B20
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189B20'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176210',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1176210;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1176210';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176210',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176210'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176210';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176210';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176210',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176210
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176210
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176210',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1176210
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176210', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176210',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176210',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1176210';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1176210',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1176210';
        
END;
/

/***********************************************************
***** CHARGE 1176117 CJIS_CASE_NUMBER 2023CF189B7
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189B7'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176117',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1176117;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1176117';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176117',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176117'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176117';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176117';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176117',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176117
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176117
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176117',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1176117
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176117', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176117',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176117',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1176117';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1176117',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1176117';
        
END;
/

/***********************************************************
***** CHARGE 1176265 CJIS_CASE_NUMBER 2023CF189E36
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189E36'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176265',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1176265;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1176265';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176265',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176265'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '1000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176265';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176265';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176265',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176265
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176265
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176265',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1176265
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176265', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176265',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176265',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1176265';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1176265',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1176265';
        
END;
/

/***********************************************************
***** CHARGE 1176266 CJIS_CASE_NUMBER 2023CF189E39
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189E39'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176266',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1176266;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1176266';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176266',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176266'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '500',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176266';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176266';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176266',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176266
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176266
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176266',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1176266
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176266', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1176266',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1176266',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1176266';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1176266',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1176266';
        
END;
/

/***********************************************************
***** CHARGE 1169866 CJIS_CASE_NUMBER 2023CF196A11
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF196A11'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169866',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1169866;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1169866';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169866',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169866'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1169866';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169866';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169866',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169866
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169866
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169866',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1169866
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169866', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169866',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169866',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1169866';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1169866',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1169866';
        
END;
/

/***********************************************************
***** CHARGE 1169871 CJIS_CASE_NUMBER 2023CF196A16
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF196A16'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169871',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1169871;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1169871';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169871',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169871'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1169871';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169871';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169871',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169871',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1169871
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169871', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1169871',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1169871',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1169871';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1169871',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1169871';
        
END;
/

/***********************************************************
***** CHARGE 1185943 CJIS_CASE_NUMBER 2023CF2547A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF2547A2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1185943',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1185943;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1185943';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1185943',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185943'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1185943';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185943';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1185943',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1185943
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1185943
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1185943',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1185943
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1185943', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1185943',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1185943',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1185943';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1185943',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1185943';
        
END;
/

/***********************************************************
***** CHARGE 1170415 CJIS_CASE_NUMBER 2023CF275A7
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF275A7'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1170415',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1170415;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1170415';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1170415',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170415'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1170415';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170415';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1170415',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170415
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170415
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1170415',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1170415
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170415', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1170415',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1170415',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1170415';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1170415',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1170415';
        
END;
/

/***********************************************************
***** CHARGE 1170419 CJIS_CASE_NUMBER 2023CF276A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF276A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1170419',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1170419;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1170419';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1170419',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170419'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1170419';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170419';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1170419',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170419
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170419
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1170419',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1170419
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170419', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1170419',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1170419',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1170419';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1170419',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1170419';
        
END;
/

/***********************************************************
***** CHARGE 1187955 CJIS_CASE_NUMBER 2023CF2912A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF2912A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1187955',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1187955;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1187955';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1187955',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1187955'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1187955';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1187955';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1187955',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1187955
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1187955
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1187955',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1187955
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1187955', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1187955',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1187955',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1187955';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1187955',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1187955';
        
END;
/

/***********************************************************
***** CHARGE 1171823 CJIS_CASE_NUMBER 2023CF513A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF513A3'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1171823',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1171823;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1171823';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1171823',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1171823'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1171823';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1171823';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1171823',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1171823
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1171823
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1171823',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1171823
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1171823', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1171823',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1171823',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1171823';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1171823',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1171823';
        
END;
/

/***********************************************************
***** CHARGE 1201244 CJIS_CASE_NUMBER 2024CF100C2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2024CF100C2'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1201244',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1201244;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1201244';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1201244',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201244'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1201244';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201244';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1201244',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201244
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201244
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1201244',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1201244
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1201244', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1201244',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1201244',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1201244';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1201244',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1201244';
        
END;
/

/***********************************************************
***** CHARGE 1204002 CJIS_CASE_NUMBER 2024CF1764B5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2024CF1764B5'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1204002',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1204002;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1204002';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1204002',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204002'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '25000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1204002';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204002';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1204002',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1204002
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1204002
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1204002',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1204002
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1204002', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1204002',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1204002',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1204002';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1204002',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1204002';
        
END;
/

/***********************************************************
***** CHARGE 1206261 CJIS_CASE_NUMBER 2024CF2297A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2024CF2297A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1206261',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1206261;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1206261';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1206261',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1206261'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1206261';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1206261';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1206261',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1206261
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1206261
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1206261',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1206261
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1206261', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1206261',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1206261',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1206261';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1206261',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1206261';
        
END;
/

/***********************************************************
***** CHARGE 1208013 CJIS_CASE_NUMBER 2024CF2605A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2024CF2605A1'
AND ACTIVITY_TABLE_NAME = 'CHARGE'
and (ACTIVITY_DETAILS LIKE '%STATUS%'
  OR ACTIVITY_DETAILS LIKE '%LOCATION%'
  OR ACTIVITY_DETAILS LIKE '%BOND_AMT%'
  )
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS', 'RAO')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1208013',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = 1208013;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
       AND charge_id = '1208013';

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1208013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1208013'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1208013';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1208013';


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1208013',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1208013
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1208013
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1208013',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1208013
AND cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1208013', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id       => '1208013',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
    p_charge_id    => '1208013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
            AND charge_id = '1208013';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
            p_charge_id    => '1208013',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44'
        AND charge_id = '1208013';
        
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='CHARGES_PROCESSED'
    WHERE cleanup_id = 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44';
    
    JISREM.LOG
    (
        p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => 'c6a0dd9c-460c-41a9-a604-ef0b649b7b44',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

