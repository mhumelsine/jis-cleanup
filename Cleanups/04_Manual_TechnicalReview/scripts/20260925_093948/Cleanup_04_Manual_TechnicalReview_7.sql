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

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;



DECLARE
    v_existing NUMBER; 
BEGIN

    IF 0 IS NULL OR 0 NOT IN (0,1) THEN 
         RAISE_APPLICATION_ERROR(-20001,'0 must be 0 or 1'); END IF;
    
    SELECT COUNT(*) 
    INTO v_existing 
    FROM JISREM.CLEANUP 
    WHERE cleanup_name='20260925_093948_Cleanup_04_Manual_TechnicalReview_7';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260925_093948_Cleanup_04_Manual_TechnicalReview_7] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9','20260925_093948_Cleanup_04_Manual_TechnicalReview_7','Deep technical review of cases with human activity since 8/18.','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026HH551A4', '1246734', '276945', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF2936A1', '1210122', '277142', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM1625A1', '1251936', '277270', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3456A1', '1215418', '277524', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF1566A1', '1224425', '277524', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF1566A2', '1224426', '277524', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A1', '1213910', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A2', '1213911', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A3', '1213912', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A4', '1213913', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A5', '1213914', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A6', '1213915', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A7', '1213916', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2024CF3498A8', '1213917', '277643', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF111A1', '1215387', '277728', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1685A2', '1247302', '277728', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CT327A1', '1241113', '277747', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CT327A2', '1241114', '277747', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF323A1', '1216513', '278062', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF323A2', '1216517', '278062', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF323A3', '1216516', '278062', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF323A4', '1216514', '278062', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF323A5', '1216515', '278062', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025MM250A1', '1216588', '278075', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3396A1', '1235945', '278162', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3396A2', '1235946', '278162', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3396A3', '1235947', '278162', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2234A1', '1228563', '278167', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3432A1', '1236147', '278539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3432A2', '1236148', '278539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2112A1', '1227781', '278638', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2112A2', '1227782', '278638', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2112A3', '1227780', '278638', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1427A1', '1245706', '278658', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1427A2', '1245705', '278658', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM1047A1', '1246245', '278925', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2619A1', '1230996', '279312', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3175A1', '1234540', '279424', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3175A2', '1234541', '279424', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3175A3', '1234542', '279424', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3175A4', '1234543', '279424', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025MM1437A1', '1228203', '279530', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CT305A1', '1240878', '279639', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF2084A1', '1250734', '279644', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF2084A2', '1250735', '279644', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2350A1', '1229330', '279669', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM1629A1', '1251963', '279669', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2912A1', '1232847', '279825', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM866A1', '1244771', '279825', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF2681A1', '1231417', '279941', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CT1818A1', '1233159', '280177', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3021A1', '1233520', '280221', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025HV65A1', '1233518', '280221', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3206A1', '1234708', '280408', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025MM2299A1', '1235826', '280502', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1647A1', '1246978', '28055', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1647A2', '1246980', '28055', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1647A3', '1246979', '28055', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3479A1', '1236343', '280600', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2025CF3489A1', '1236381', '280606', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM1196A1', '1247582', '280709', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF248A1', '1238359', '280831', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF641A3', '1240640', '280831', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM540A1', '1241307', '280831', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF507A1', '1239708', '281040', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF507A2', '1239707', '281040', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF508A1', '1239710', '281041', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF508A2', '1239709', '281041', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF596A1', '1240366', '281120', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF596A2', '1240367', '281120', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF700A1', '1241027', '281215', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF700A2', '1241028', '281215', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF700A3', '1241029', '281215', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF700A4', '1241030', '281215', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF700A6', '1241031', '281215', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF703A1', '1241054', '281220', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF703A2', '1241055', '281220', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1615A1', '1246818', '281222', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1615A2', '1246821', '281222', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1615A3', '1246820', '281222', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1615A4', '1246819', '281222', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF758A1', '1241431', '281259', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF758A2', '1241432', '281259', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM576A1', '1241625', '281286', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF806A1', '1241673', '281292', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF916A1', '1242881', '281387', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM659A1', '1242926', '281395', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM659A2', '1242927', '281395', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF994A1', '1243313', '281437', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF994A2', '1243310', '281437', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF994A4', '1243312', '281437', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CF1054A1', '1243657', '281483', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM793A1', '1244168', '281564', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM802A1', '1244198', '281569', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CT601A1', '1244589', '281627', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM1296A1', '1248620', '281633', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM1296A2', '1248621', '281633', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026HH1980A1', '1252691', '281678', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026MM892A1', '1245014', '281699', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('d5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9', '2026CT652A1', '1245306', '281720', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260925_093948_Cleanup_04_Manual_TechnicalReview_7] started'
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocation::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1246734 CJIS_CASE_NUMBER 2026HH551A4
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026HH551A4'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246734',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246734;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246734';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246734
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
and source_row.CHARGE_ID = 1246734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246734',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246734'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1246734';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246734';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246734',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246734
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246734', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246734',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246734';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246734',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246734';
        
END;
/

/***********************************************************
***** CHARGE 1210122 CJIS_CASE_NUMBER 2024CF2936A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF2936A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1210122',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1210122;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1210122';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1210122',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1210122
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
and source_row.CHARGE_ID = 1210122
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1210122',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1210122'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNG'
WHERE CHARGE_ID = '1210122';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1210122';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1210122',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1210122
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1210122', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1210122',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1210122',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1210122';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1210122',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1210122';
        
END;
/

/***********************************************************
***** CHARGE 1251936 CJIS_CASE_NUMBER 2026MM1625A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM1625A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1251936',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1251936;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1251936';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1251936',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1251936
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
and source_row.CHARGE_ID = 1251936
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1251936',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251936'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1251936';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251936';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1251936',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251936
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251936', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1251936',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1251936',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1251936';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1251936',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1251936';
        
END;
/

/***********************************************************
***** CHARGE 1215418 CJIS_CASE_NUMBER 2024CF3456A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3456A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1215418',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1215418;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1215418';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1215418',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1215418
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
and source_row.CHARGE_ID = 1215418
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1215418',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215418'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1215418';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215418';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1215418',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215418
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215418', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1215418',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1215418',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1215418';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1215418',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1215418';
        
END;
/

/***********************************************************
***** CHARGE 1224425 CJIS_CASE_NUMBER 2025CF1566A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF1566A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1224425',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1224425;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1224425';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1224425',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1224425
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
and source_row.CHARGE_ID = 1224425
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1224425',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1224425'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1224425';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1224425';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1224425',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1224425
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1224425', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1224425',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1224425',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1224425';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1224425',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1224425';
        
END;
/

/***********************************************************
***** CHARGE 1224426 CJIS_CASE_NUMBER 2025CF1566A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF1566A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1224426',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1224426;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1224426';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1224426',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1224426
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
and source_row.CHARGE_ID = 1224426
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1224426',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1224426'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1224426';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1224426';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1224426',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1224426
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1224426', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1224426',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1224426',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1224426';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1224426',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1224426';
        
END;
/

/***********************************************************
***** CHARGE 1213910 CJIS_CASE_NUMBER 2024CF3498A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213910',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213910;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213910';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213910',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213910
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
and source_row.CHARGE_ID = 1213910
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213910',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213910'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213910';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213910';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213910',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213910
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213910', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213910',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213910',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213910';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213910',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213910';
        
END;
/

/***********************************************************
***** CHARGE 1213911 CJIS_CASE_NUMBER 2024CF3498A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213911',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213911;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213911';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213911',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213911
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
and source_row.CHARGE_ID = 1213911
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213911',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213911'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213911';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213911';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213911',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213911
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213911', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213911',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213911',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213911';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213911',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213911';
        
END;
/

/***********************************************************
***** CHARGE 1213912 CJIS_CASE_NUMBER 2024CF3498A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213912',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213912;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213912';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213912',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213912
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
and source_row.CHARGE_ID = 1213912
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213912',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213912'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213912';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213912';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213912',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213912
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213912', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213912',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213912',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213912';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213912',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213912';
        
END;
/

/***********************************************************
***** CHARGE 1213913 CJIS_CASE_NUMBER 2024CF3498A4
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A4'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213913',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213913;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213913';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213913
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
and source_row.CHARGE_ID = 1213913
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213913',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213913'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213913';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213913';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213913',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213913
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213913', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213913',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213913';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213913',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213913';
        
END;
/

/***********************************************************
***** CHARGE 1213914 CJIS_CASE_NUMBER 2024CF3498A5
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A5'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213914',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213914;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213914';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213914',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213914
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
and source_row.CHARGE_ID = 1213914
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213914',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213914'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213914';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213914';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213914',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213914
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213914', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213914',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213914',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213914';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213914',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213914';
        
END;
/

/***********************************************************
***** CHARGE 1213915 CJIS_CASE_NUMBER 2024CF3498A6
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A6'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213915',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213915;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213915';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213915',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213915
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
and source_row.CHARGE_ID = 1213915
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213915',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213915'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213915';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213915';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213915',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213915
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213915', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213915',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213915',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213915';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213915',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213915';
        
END;
/

/***********************************************************
***** CHARGE 1213916 CJIS_CASE_NUMBER 2024CF3498A7
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A7'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213916',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213916;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213916';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213916',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213916
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
and source_row.CHARGE_ID = 1213916
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213916',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213916'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1213916';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213916';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213916',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213916
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213916', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213916',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213916',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213916';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213916',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213916';
        
END;
/

/***********************************************************
***** CHARGE 1213917 CJIS_CASE_NUMBER 2024CF3498A8
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2024CF3498A8'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213917',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1213917;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1213917';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213917',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1213917
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
and source_row.CHARGE_ID = 1213917
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213917',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213917'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1213917';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213917';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213917',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213917
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213917', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1213917',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1213917',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1213917';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1213917',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1213917';
        
END;
/

/***********************************************************
***** CHARGE 1215387 CJIS_CASE_NUMBER 2025CF111A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF111A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1215387',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1215387;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1215387';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1215387',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1215387
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
and source_row.CHARGE_ID = 1215387
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1215387',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215387'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1215387';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215387';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1215387',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215387
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215387', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1215387',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1215387',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1215387';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1215387',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1215387';
        
END;
/

/***********************************************************
***** CHARGE 1247302 CJIS_CASE_NUMBER 2026CF1685A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1685A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1247302',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1247302;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1247302';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1247302',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1247302
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
and source_row.CHARGE_ID = 1247302
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1247302',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247302'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1247302';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247302';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1247302',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247302
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247302', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1247302',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1247302',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1247302';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1247302',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1247302';
        
END;
/

/***********************************************************
***** CHARGE 1241113 CJIS_CASE_NUMBER 2026CT327A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CT327A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241113',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241113;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241113';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241113',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241113
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
and source_row.CHARGE_ID = 1241113
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241113',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241113'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241113';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241113';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241113',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241113
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241113', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241113',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241113',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241113';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241113',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241113';
        
END;
/

/***********************************************************
***** CHARGE 1241114 CJIS_CASE_NUMBER 2026CT327A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CT327A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241114',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241114;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241114';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241114',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241114
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
and source_row.CHARGE_ID = 1241114
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241114',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241114'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241114';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241114';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241114',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241114
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241114', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241114',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241114',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241114';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241114',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241114';
        
END;
/

/***********************************************************
***** CHARGE 1216513 CJIS_CASE_NUMBER 2025CF323A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF323A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216513',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1216513;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1216513';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216513',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1216513
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
and source_row.CHARGE_ID = 1216513
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216513',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216513'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1216513';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216513';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216513',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216513
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216513', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216513',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216513',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1216513';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1216513',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1216513';
        
END;
/

/***********************************************************
***** CHARGE 1216517 CJIS_CASE_NUMBER 2025CF323A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF323A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216517',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1216517;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1216517';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216517',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1216517
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
and source_row.CHARGE_ID = 1216517
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216517',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216517'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1216517';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216517';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216517',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216517
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216517', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216517',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216517',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1216517';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1216517',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1216517';
        
END;
/

/***********************************************************
***** CHARGE 1216516 CJIS_CASE_NUMBER 2025CF323A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF323A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216516',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1216516;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1216516';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216516',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1216516
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
and source_row.CHARGE_ID = 1216516
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216516',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216516'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1216516';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216516';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216516',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216516
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216516', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216516',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216516',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1216516';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1216516',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1216516';
        
END;
/

/***********************************************************
***** CHARGE 1216514 CJIS_CASE_NUMBER 2025CF323A4
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF323A4'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216514',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1216514;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1216514';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216514',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1216514
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
and source_row.CHARGE_ID = 1216514
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216514',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216514'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1216514';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216514';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216514',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216514
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216514', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216514',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216514',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1216514';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1216514',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1216514';
        
END;
/

/***********************************************************
***** CHARGE 1216515 CJIS_CASE_NUMBER 2025CF323A5
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF323A5'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216515',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1216515;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1216515';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216515',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1216515
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
and source_row.CHARGE_ID = 1216515
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216515',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216515'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1216515';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216515';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216515',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216515
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216515', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216515',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216515',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1216515';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1216515',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1216515';
        
END;
/

/***********************************************************
***** CHARGE 1216588 CJIS_CASE_NUMBER 2025MM250A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025MM250A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216588',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1216588;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1216588';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216588',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1216588
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
and source_row.CHARGE_ID = 1216588
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216588',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216588'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1216588';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216588';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216588',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216588
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216588', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1216588',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1216588',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1216588';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1216588',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1216588';
        
END;
/

/***********************************************************
***** CHARGE 1235945 CJIS_CASE_NUMBER 2025CF3396A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3396A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235945',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1235945;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1235945';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235945',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1235945
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
and source_row.CHARGE_ID = 1235945
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235945',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235945'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1235945';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235945';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235945',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1235945
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235945', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235945',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235945',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1235945';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1235945',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1235945';
        
END;
/

/***********************************************************
***** CHARGE 1235946 CJIS_CASE_NUMBER 2025CF3396A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3396A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235946',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1235946;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1235946';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235946',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1235946
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
and source_row.CHARGE_ID = 1235946
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235946',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235946'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1235946';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235946';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235946',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1235946
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235946', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235946',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235946',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1235946';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1235946',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1235946';
        
END;
/

/***********************************************************
***** CHARGE 1235947 CJIS_CASE_NUMBER 2025CF3396A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3396A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235947',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1235947;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1235947';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235947',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1235947
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
and source_row.CHARGE_ID = 1235947
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235947',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235947'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1235947';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235947';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235947',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1235947
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235947', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235947',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235947',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1235947';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1235947',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1235947';
        
END;
/

/***********************************************************
***** CHARGE 1228563 CJIS_CASE_NUMBER 2025CF2234A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2234A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1228563',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1228563;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1228563';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1228563',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1228563
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
and source_row.CHARGE_ID = 1228563
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1228563',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228563'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1228563';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228563';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1228563',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228563
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228563', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1228563',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1228563',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1228563';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1228563',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1228563';
        
END;
/

/***********************************************************
***** CHARGE 1236147 CJIS_CASE_NUMBER 2025CF3432A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3432A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236147',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1236147;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1236147';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236147',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1236147
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
and source_row.CHARGE_ID = 1236147
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236147',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236147'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1236147';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236147';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236147',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1236147
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236147', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236147',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236147',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1236147';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1236147',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1236147';
        
END;
/

/***********************************************************
***** CHARGE 1236148 CJIS_CASE_NUMBER 2025CF3432A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3432A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236148',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1236148;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1236148';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236148',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1236148
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
and source_row.CHARGE_ID = 1236148
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236148',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236148'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1236148';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236148';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236148',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1236148
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236148', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236148',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236148',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1236148';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1236148',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1236148';
        
END;
/

/***********************************************************
***** CHARGE 1227781 CJIS_CASE_NUMBER 2025CF2112A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2112A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227781',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1227781;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1227781';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227781',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1227781
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
and source_row.CHARGE_ID = 1227781
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227781',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227781'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1227781';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227781';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227781',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227781
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227781', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227781',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227781',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1227781';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1227781',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1227781';
        
END;
/

/***********************************************************
***** CHARGE 1227782 CJIS_CASE_NUMBER 2025CF2112A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2112A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227782',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1227782;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1227782';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227782',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1227782
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
and source_row.CHARGE_ID = 1227782
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227782',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227782'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1227782';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227782';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227782',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227782
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227782', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227782',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227782',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1227782';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1227782',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1227782';
        
END;
/

/***********************************************************
***** CHARGE 1227780 CJIS_CASE_NUMBER 2025CF2112A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2112A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227780',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1227780;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1227780';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227780',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1227780
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
and source_row.CHARGE_ID = 1227780
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227780',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227780'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1227780';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227780';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227780',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227780
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227780', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1227780',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1227780',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1227780';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1227780',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1227780';
        
END;
/

/***********************************************************
***** CHARGE 1245706 CJIS_CASE_NUMBER 2026CF1427A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1427A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245706',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1245706;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1245706';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245706',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1245706
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
and source_row.CHARGE_ID = 1245706
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245706',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245706'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1245706';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245706';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245706',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245706
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245706', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245706',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245706',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1245706';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1245706',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1245706';
        
END;
/

/***********************************************************
***** CHARGE 1245705 CJIS_CASE_NUMBER 2026CF1427A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1427A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245705',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1245705;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1245705';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245705',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1245705
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
and source_row.CHARGE_ID = 1245705
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245705',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245705'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1245705';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245705';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245705',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245705
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245705', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245705',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245705',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1245705';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1245705',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1245705';
        
END;
/

/***********************************************************
***** CHARGE 1246245 CJIS_CASE_NUMBER 2026MM1047A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM1047A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246245',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246245;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246245';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246245',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246245
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
and source_row.CHARGE_ID = 1246245
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246245',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246245'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246245';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246245';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246245',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246245
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246245', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246245',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246245',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246245';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246245',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246245';
        
END;
/

/***********************************************************
***** CHARGE 1230996 CJIS_CASE_NUMBER 2025CF2619A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2619A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1230996',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1230996;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1230996';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1230996',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1230996
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
and source_row.CHARGE_ID = 1230996
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1230996',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230996'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1230996';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230996';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1230996',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1230996
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230996', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1230996',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1230996',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1230996';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1230996',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1230996';
        
END;
/

/***********************************************************
***** CHARGE 1234540 CJIS_CASE_NUMBER 2025CF3175A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3175A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234540',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1234540;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1234540';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234540',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1234540
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
and source_row.CHARGE_ID = 1234540
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234540',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234540'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1234540';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234540';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234540',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234540
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234540', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234540',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234540',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1234540';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1234540',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1234540';
        
END;
/

/***********************************************************
***** CHARGE 1234541 CJIS_CASE_NUMBER 2025CF3175A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3175A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234541',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1234541;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1234541';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234541',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1234541
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
and source_row.CHARGE_ID = 1234541
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234541',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234541'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1234541';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234541';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234541',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234541
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234541', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234541',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234541',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1234541';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1234541',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1234541';
        
END;
/

/***********************************************************
***** CHARGE 1234542 CJIS_CASE_NUMBER 2025CF3175A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3175A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234542',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1234542;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1234542';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234542',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1234542
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
and source_row.CHARGE_ID = 1234542
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234542',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234542'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1234542';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234542';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234542',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234542
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234542', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234542',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234542',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1234542';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1234542',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1234542';
        
END;
/

/***********************************************************
***** CHARGE 1234543 CJIS_CASE_NUMBER 2025CF3175A4
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3175A4'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234543',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1234543;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1234543';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234543',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1234543
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
and source_row.CHARGE_ID = 1234543
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234543',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234543'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1234543';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234543';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234543',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234543
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234543', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234543',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234543',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1234543';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1234543',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1234543';
        
END;
/

/***********************************************************
***** CHARGE 1228203 CJIS_CASE_NUMBER 2025MM1437A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025MM1437A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1228203',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1228203;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1228203';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1228203',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1228203
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
and source_row.CHARGE_ID = 1228203
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1228203',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228203'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1228203';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228203';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1228203',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228203
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228203', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1228203',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1228203',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1228203';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1228203',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1228203';
        
END;
/

/***********************************************************
***** CHARGE 1240878 CJIS_CASE_NUMBER 2026CT305A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CT305A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240878',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1240878;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1240878';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240878',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1240878
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
and source_row.CHARGE_ID = 1240878
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240878',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240878'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1240878';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240878';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240878',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240878
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240878', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240878',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240878',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1240878';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1240878',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1240878';
        
END;
/

/***********************************************************
***** CHARGE 1250734 CJIS_CASE_NUMBER 2026CF2084A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF2084A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1250734',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1250734;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1250734';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1250734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1250734
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
and source_row.CHARGE_ID = 1250734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1250734',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250734'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1250734';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250734';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1250734',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1250734
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1250734', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1250734',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1250734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1250734';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1250734',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1250734';
        
END;
/

/***********************************************************
***** CHARGE 1250735 CJIS_CASE_NUMBER 2026CF2084A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF2084A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1250735',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1250735;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1250735';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1250735',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1250735
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
and source_row.CHARGE_ID = 1250735
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1250735',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250735'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1250735';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250735';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1250735',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1250735
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1250735', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1250735',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1250735',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1250735';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1250735',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1250735';
        
END;
/

/***********************************************************
***** CHARGE 1229330 CJIS_CASE_NUMBER 2025CF2350A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2350A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1229330',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1229330;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1229330';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1229330',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1229330
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
and source_row.CHARGE_ID = 1229330
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1229330',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229330'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1229330';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229330';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1229330',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1229330
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1229330', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1229330',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1229330',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1229330';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1229330',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1229330';
        
END;
/

/***********************************************************
***** CHARGE 1251963 CJIS_CASE_NUMBER 2026MM1629A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM1629A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1251963',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1251963;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1251963';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1251963',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1251963
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
and source_row.CHARGE_ID = 1251963
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1251963',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251963'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1251963';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251963';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1251963',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251963
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251963', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1251963',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1251963',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1251963';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1251963',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1251963';
        
END;
/

/***********************************************************
***** CHARGE 1232847 CJIS_CASE_NUMBER 2025CF2912A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2912A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1232847',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1232847;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1232847';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1232847',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1232847
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
and source_row.CHARGE_ID = 1232847
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1232847',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232847'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1232847';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232847';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1232847',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232847
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232847', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1232847',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1232847',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1232847';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1232847',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1232847';
        
END;
/

/***********************************************************
***** CHARGE 1244771 CJIS_CASE_NUMBER 2026MM866A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM866A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244771',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1244771;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1244771';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244771',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1244771
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
and source_row.CHARGE_ID = 1244771
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244771',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244771'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1244771';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244771';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244771',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244771
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244771', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244771',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244771',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1244771';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1244771',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1244771';
        
END;
/

/***********************************************************
***** CHARGE 1231417 CJIS_CASE_NUMBER 2025CF2681A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF2681A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1231417',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1231417;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1231417';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1231417',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1231417
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
and source_row.CHARGE_ID = 1231417
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1231417',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231417'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1231417';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231417';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1231417',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231417
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231417', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1231417',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1231417',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1231417';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1231417',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1231417';
        
END;
/

/***********************************************************
***** CHARGE 1233159 CJIS_CASE_NUMBER 2025CT1818A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CT1818A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233159',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1233159;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1233159';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233159',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1233159
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
and source_row.CHARGE_ID = 1233159
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233159',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233159'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'C',
    LOCATION = 'CAP.'
WHERE CHARGE_ID = '1233159';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233159';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233159',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233159
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233159', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233159',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233159',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1233159';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1233159',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1233159';
        
END;
/

/***********************************************************
***** CHARGE 1233520 CJIS_CASE_NUMBER 2025CF3021A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3021A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233520',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1233520;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1233520';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233520',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1233520
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
and source_row.CHARGE_ID = 1233520
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233520',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233520'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1233520';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233520';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233520',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233520
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233520', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233520',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233520',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1233520';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1233520',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1233520';
        
END;
/

/***********************************************************
***** CHARGE 1233518 CJIS_CASE_NUMBER 2025HV65A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025HV65A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233518',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1233518;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1233518';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233518',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1233518
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
and source_row.CHARGE_ID = 1233518
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233518',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233518'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1233518';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233518';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233518',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233518
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233518', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1233518',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1233518',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1233518';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1233518',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1233518';
        
END;
/

/***********************************************************
***** CHARGE 1234708 CJIS_CASE_NUMBER 2025CF3206A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3206A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234708',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1234708;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1234708';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1234708
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
and source_row.CHARGE_ID = 1234708
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234708',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234708'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1234708';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234708';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234708',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234708
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234708', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1234708',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1234708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1234708';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1234708',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1234708';
        
END;
/

/***********************************************************
***** CHARGE 1235826 CJIS_CASE_NUMBER 2025MM2299A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025MM2299A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235826',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1235826;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1235826';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235826',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1235826
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
and source_row.CHARGE_ID = 1235826
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235826',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235826'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1235826';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235826';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235826',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1235826
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235826', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1235826',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1235826',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1235826';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1235826',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1235826';
        
END;
/

/***********************************************************
***** CHARGE 1246978 CJIS_CASE_NUMBER 2026CF1647A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1647A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246978',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246978;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246978';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246978',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246978
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
and source_row.CHARGE_ID = 1246978
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246978',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246978'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246978';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246978';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246978',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246978
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246978', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246978',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246978',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246978';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246978',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246978';
        
END;
/

/***********************************************************
***** CHARGE 1246980 CJIS_CASE_NUMBER 2026CF1647A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1647A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246980',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246980;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246980';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246980',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246980
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
and source_row.CHARGE_ID = 1246980
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246980',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246980'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246980';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246980';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246980',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246980
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246980', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246980',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246980',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246980';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246980',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246980';
        
END;
/

/***********************************************************
***** CHARGE 1246979 CJIS_CASE_NUMBER 2026CF1647A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1647A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246979',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246979;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246979';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246979',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246979
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
and source_row.CHARGE_ID = 1246979
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246979',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246979'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246979';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246979';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246979',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246979
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246979', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246979',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246979',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246979';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246979',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246979';
        
END;
/

/***********************************************************
***** CHARGE 1236343 CJIS_CASE_NUMBER 2025CF3479A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3479A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236343',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1236343;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1236343';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236343',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1236343
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
and source_row.CHARGE_ID = 1236343
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236343',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236343'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1236343';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236343';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236343',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1236343
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236343', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236343',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236343',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1236343';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1236343',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1236343';
        
END;
/

/***********************************************************
***** CHARGE 1236381 CJIS_CASE_NUMBER 2025CF3489A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2025CF3489A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236381',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1236381;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1236381';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236381',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1236381
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
and source_row.CHARGE_ID = 1236381
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236381',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236381'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1236381';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236381';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236381',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1236381
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236381', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1236381',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1236381',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1236381';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1236381',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1236381';
        
END;
/

/***********************************************************
***** CHARGE 1247582 CJIS_CASE_NUMBER 2026MM1196A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM1196A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1247582',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1247582;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1247582';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1247582',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1247582
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
and source_row.CHARGE_ID = 1247582
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1247582',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247582'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1247582';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247582';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1247582',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247582
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247582', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1247582',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1247582',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1247582';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1247582',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1247582';
        
END;
/

/***********************************************************
***** CHARGE 1238359 CJIS_CASE_NUMBER 2026CF248A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF248A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1238359',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1238359;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1238359';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1238359',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1238359
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
and source_row.CHARGE_ID = 1238359
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1238359',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238359'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1238359';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238359';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1238359',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1238359
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238359', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1238359',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1238359',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1238359';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1238359',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1238359';
        
END;
/

/***********************************************************
***** CHARGE 1240640 CJIS_CASE_NUMBER 2026CF641A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF641A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240640',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1240640;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1240640';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240640',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1240640
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
and source_row.CHARGE_ID = 1240640
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240640',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240640'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1240640';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240640';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240640',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240640
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240640', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240640',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240640',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1240640';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1240640',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1240640';
        
END;
/

/***********************************************************
***** CHARGE 1241307 CJIS_CASE_NUMBER 2026MM540A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM540A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241307',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241307;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241307';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241307
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
and source_row.CHARGE_ID = 1241307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241307',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241307'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1241307';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241307';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241307',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241307
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241307', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241307',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241307';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241307',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241307';
        
END;
/

/***********************************************************
***** CHARGE 1239708 CJIS_CASE_NUMBER 2026CF507A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF507A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239708',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1239708;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1239708';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1239708
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
and source_row.CHARGE_ID = 1239708
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239708',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239708'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1239708';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239708';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239708',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239708
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239708', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239708',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1239708';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1239708',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1239708';
        
END;
/

/***********************************************************
***** CHARGE 1239707 CJIS_CASE_NUMBER 2026CF507A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF507A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239707',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1239707;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1239707';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239707',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1239707
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
and source_row.CHARGE_ID = 1239707
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239707',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239707'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1239707';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239707';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239707',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239707
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239707', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239707',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239707',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1239707';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1239707',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1239707';
        
END;
/

/***********************************************************
***** CHARGE 1239710 CJIS_CASE_NUMBER 2026CF508A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF508A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239710',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1239710;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1239710';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239710',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1239710
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
and source_row.CHARGE_ID = 1239710
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239710',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239710'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1239710';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239710';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239710',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239710
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239710', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239710',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239710',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1239710';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1239710',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1239710';
        
END;
/

/***********************************************************
***** CHARGE 1239709 CJIS_CASE_NUMBER 2026CF508A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF508A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239709',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1239709;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1239709';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239709',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1239709
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
and source_row.CHARGE_ID = 1239709
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239709',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239709'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1239709';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239709';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239709',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239709
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239709', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1239709',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1239709',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1239709';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1239709',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1239709';
        
END;
/

/***********************************************************
***** CHARGE 1240366 CJIS_CASE_NUMBER 2026CF596A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF596A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240366',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1240366;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1240366';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240366',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1240366
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
and source_row.CHARGE_ID = 1240366
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240366',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240366'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1240366';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240366';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240366',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240366
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240366', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240366',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240366',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1240366';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1240366',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1240366';
        
END;
/

/***********************************************************
***** CHARGE 1240367 CJIS_CASE_NUMBER 2026CF596A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF596A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240367',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1240367;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1240367';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240367',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1240367
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
and source_row.CHARGE_ID = 1240367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240367',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240367'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1240367';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240367';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240367',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240367
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240367', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1240367',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1240367',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1240367';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1240367',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1240367';
        
END;
/

/***********************************************************
***** CHARGE 1241027 CJIS_CASE_NUMBER 2026CF700A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF700A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241027',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241027;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241027';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241027',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241027
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
and source_row.CHARGE_ID = 1241027
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241027',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241027'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241027';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241027';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241027',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241027
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241027', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241027',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241027',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241027';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241027',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241027';
        
END;
/

/***********************************************************
***** CHARGE 1241028 CJIS_CASE_NUMBER 2026CF700A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF700A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241028',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241028;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241028';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241028',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241028
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
and source_row.CHARGE_ID = 1241028
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241028',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241028'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241028';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241028';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241028',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241028
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241028', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241028',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241028',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241028';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241028',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241028';
        
END;
/

/***********************************************************
***** CHARGE 1241029 CJIS_CASE_NUMBER 2026CF700A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF700A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241029',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241029;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241029';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241029',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241029
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
and source_row.CHARGE_ID = 1241029
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241029',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241029'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241029';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241029';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241029',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241029
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241029', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241029',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241029',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241029';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241029',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241029';
        
END;
/

/***********************************************************
***** CHARGE 1241030 CJIS_CASE_NUMBER 2026CF700A4
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF700A4'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241030',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241030;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241030';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241030',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241030
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
and source_row.CHARGE_ID = 1241030
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241030',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241030'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241030';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241030';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241030',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241030
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241030', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241030',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241030',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241030';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241030',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241030';
        
END;
/

/***********************************************************
***** CHARGE 1241031 CJIS_CASE_NUMBER 2026CF700A6
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF700A6'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241031',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241031;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241031';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241031',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241031
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
and source_row.CHARGE_ID = 1241031
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241031',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241031'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241031';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241031';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241031',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241031
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241031', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241031',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241031',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241031';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241031',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241031';
        
END;
/

/***********************************************************
***** CHARGE 1241054 CJIS_CASE_NUMBER 2026CF703A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF703A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241054',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241054;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241054';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241054',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241054
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
and source_row.CHARGE_ID = 1241054
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241054',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241054'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241054';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241054';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241054',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241054
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241054', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241054',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241054',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241054';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241054',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241054';
        
END;
/

/***********************************************************
***** CHARGE 1241055 CJIS_CASE_NUMBER 2026CF703A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF703A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241055',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241055;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241055';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241055',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241055
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
and source_row.CHARGE_ID = 1241055
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241055',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241055'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241055';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241055';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241055',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241055
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241055', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241055',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241055',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241055';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241055',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241055';
        
END;
/

/***********************************************************
***** CHARGE 1246818 CJIS_CASE_NUMBER 2026CF1615A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1615A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246818',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246818;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246818';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246818',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246818
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
and source_row.CHARGE_ID = 1246818
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246818',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246818'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1246818';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246818';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246818',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246818
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246818', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246818',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246818',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246818';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246818',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246818';
        
END;
/

/***********************************************************
***** CHARGE 1246821 CJIS_CASE_NUMBER 2026CF1615A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1615A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246821',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246821;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246821';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246821',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246821
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
and source_row.CHARGE_ID = 1246821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246821',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246821'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1246821';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246821';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246821',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246821
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246821', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246821',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246821',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246821';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246821',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246821';
        
END;
/

/***********************************************************
***** CHARGE 1246820 CJIS_CASE_NUMBER 2026CF1615A3
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1615A3'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246820',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246820;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246820';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246820',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246820
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
and source_row.CHARGE_ID = 1246820
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246820',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246820'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1246820';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246820';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246820',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246820
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246820', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246820',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246820',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246820';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246820',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246820';
        
END;
/

/***********************************************************
***** CHARGE 1246819 CJIS_CASE_NUMBER 2026CF1615A4
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1615A4'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246819',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1246819;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1246819';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246819',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1246819
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
and source_row.CHARGE_ID = 1246819
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246819',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246819'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1246819';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246819';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246819',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246819
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246819', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1246819',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1246819',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1246819';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1246819',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1246819';
        
END;
/

/***********************************************************
***** CHARGE 1241431 CJIS_CASE_NUMBER 2026CF758A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF758A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241431',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241431;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241431';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241431',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241431
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
and source_row.CHARGE_ID = 1241431
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241431',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241431'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241431';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241431';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241431',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241431
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241431', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241431',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241431',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241431';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241431',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241431';
        
END;
/

/***********************************************************
***** CHARGE 1241432 CJIS_CASE_NUMBER 2026CF758A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF758A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241432',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241432;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241432';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241432',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241432
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
and source_row.CHARGE_ID = 1241432
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241432',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241432'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1241432';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241432';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241432',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241432
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241432', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241432',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241432',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241432';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241432',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241432';
        
END;
/

/***********************************************************
***** CHARGE 1241625 CJIS_CASE_NUMBER 2026MM576A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM576A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241625',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241625;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241625';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241625',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241625
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
and source_row.CHARGE_ID = 1241625
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241625',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241625'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1241625';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241625';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241625',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241625
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241625', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241625',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241625',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241625';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241625',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241625';
        
END;
/

/***********************************************************
***** CHARGE 1241673 CJIS_CASE_NUMBER 2026CF806A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF806A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241673',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1241673;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1241673';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241673',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1241673
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
and source_row.CHARGE_ID = 1241673
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241673',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241673'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1241673';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241673';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241673',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241673
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241673', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1241673',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1241673',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1241673';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1241673',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1241673';
        
END;
/

/***********************************************************
***** CHARGE 1242881 CJIS_CASE_NUMBER 2026CF916A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF916A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242881',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1242881;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1242881';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242881',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1242881
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
and source_row.CHARGE_ID = 1242881
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242881',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242881'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1242881';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242881';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242881',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242881
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242881', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242881',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242881',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1242881';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1242881',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1242881';
        
END;
/

/***********************************************************
***** CHARGE 1242926 CJIS_CASE_NUMBER 2026MM659A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM659A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242926',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1242926;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1242926';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242926',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1242926
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
and source_row.CHARGE_ID = 1242926
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242926',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242926'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1242926';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242926';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242926',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242926
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242926', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242926',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242926',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1242926';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1242926',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1242926';
        
END;
/

/***********************************************************
***** CHARGE 1242927 CJIS_CASE_NUMBER 2026MM659A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM659A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242927',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1242927;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1242927';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242927',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1242927
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
and source_row.CHARGE_ID = 1242927
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242927',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242927'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1242927';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242927';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242927',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242927
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242927', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1242927',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1242927',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1242927';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1242927',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1242927';
        
END;
/

/***********************************************************
***** CHARGE 1243313 CJIS_CASE_NUMBER 2026CF994A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF994A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243313',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1243313;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1243313';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243313',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1243313
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
and source_row.CHARGE_ID = 1243313
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243313',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243313'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1243313';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243313';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243313',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243313
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243313', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243313',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243313',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1243313';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1243313',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1243313';
        
END;
/

/***********************************************************
***** CHARGE 1243310 CJIS_CASE_NUMBER 2026CF994A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF994A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243310',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1243310;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1243310';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243310',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1243310
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
and source_row.CHARGE_ID = 1243310
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243310',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243310'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1243310';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243310';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243310',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243310
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243310', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243310',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243310',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1243310';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1243310',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1243310';
        
END;
/

/***********************************************************
***** CHARGE 1243312 CJIS_CASE_NUMBER 2026CF994A4
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF994A4'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243312',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1243312;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1243312';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243312',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1243312
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
and source_row.CHARGE_ID = 1243312
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243312',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243312'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1243312';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243312';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243312',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243312
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243312', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243312',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243312',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1243312';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1243312',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1243312';
        
END;
/

/***********************************************************
***** CHARGE 1243657 CJIS_CASE_NUMBER 2026CF1054A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CF1054A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243657',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1243657;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1243657';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1243657
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
and source_row.CHARGE_ID = 1243657
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243657',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243657'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1243657';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243657';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243657',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243657
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243657', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1243657',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1243657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1243657';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1243657',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1243657';
        
END;
/

/***********************************************************
***** CHARGE 1244168 CJIS_CASE_NUMBER 2026MM793A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM793A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244168',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1244168;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1244168';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244168',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1244168
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
and source_row.CHARGE_ID = 1244168
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244168',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244168'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1244168';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244168';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244168',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244168
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244168', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244168',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244168',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1244168';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1244168',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1244168';
        
END;
/

/***********************************************************
***** CHARGE 1244198 CJIS_CASE_NUMBER 2026MM802A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM802A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244198',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1244198;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1244198';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244198',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1244198
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
and source_row.CHARGE_ID = 1244198
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244198',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244198'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1244198';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244198';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244198',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244198
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244198', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244198',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244198',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1244198';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1244198',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1244198';
        
END;
/

/***********************************************************
***** CHARGE 1244589 CJIS_CASE_NUMBER 2026CT601A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CT601A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244589',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1244589;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1244589';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244589',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1244589
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
and source_row.CHARGE_ID = 1244589
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244589',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244589'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1244589';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244589';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244589',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244589
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244589', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1244589',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1244589',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1244589';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1244589',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1244589';
        
END;
/

/***********************************************************
***** CHARGE 1248620 CJIS_CASE_NUMBER 2026MM1296A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM1296A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1248620',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1248620;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1248620';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1248620',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1248620
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
and source_row.CHARGE_ID = 1248620
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1248620',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248620'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1248620';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248620';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1248620',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248620
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248620', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1248620',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1248620',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1248620';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1248620',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1248620';
        
END;
/

/***********************************************************
***** CHARGE 1248621 CJIS_CASE_NUMBER 2026MM1296A2
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM1296A2'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1248621',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1248621;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1248621';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1248621',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1248621
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
and source_row.CHARGE_ID = 1248621
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1248621',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248621'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1248621';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248621';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1248621',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248621
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248621', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1248621',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1248621',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1248621';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1248621',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1248621';
        
END;
/

/***********************************************************
***** CHARGE 1252691 CJIS_CASE_NUMBER 2026HH1980A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026HH1980A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1252691',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1252691;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1252691';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1252691',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1252691
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
and source_row.CHARGE_ID = 1252691
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1252691',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252691'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1252691';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252691';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1252691',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1252691
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1252691', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1252691',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1252691',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1252691';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1252691',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1252691';
        
END;
/

/***********************************************************
***** CHARGE 1245014 CJIS_CASE_NUMBER 2026MM892A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026MM892A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245014',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1245014;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1245014';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245014',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1245014
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
and source_row.CHARGE_ID = 1245014
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245014',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245014'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1245014';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245014';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245014',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245014
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245014', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245014',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245014',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1245014';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1245014',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1245014';
        
END;
/

/***********************************************************
***** CHARGE 1245306 CJIS_CASE_NUMBER 2026CT652A1
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
from JISJDW.AUDIT_TRAIL
WHERE ACTIVITY_DATE_TIME > '23-SEP-2026'
AND CJIS_CASE_NUMBER = '2026CT652A1'
AND ((
    ACTIVITY_TABLE_NAME = 'CUSTODY'
    AND (ACTIVITY_DETAILS LIKE '%STATUS%' OR ACTIVITY_DETAILS LIKE '%LOCATION%'))
OR (
         ACTIVITY_TABLE_NAME = 'CHARGE'
             AND ACTIVITY_DETAILS LIKE '%STATUS%'
         ));
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Changes to STATUS or LOCATION detected';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245306',
    p_step_name  => 'NoStatusOrLocationChanges',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = 1245306;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
       AND charge_id = '1245306';

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245306',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
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
and source_row.CHARGE_ID = 1245306
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
and source_row.CHARGE_ID = 1245306
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245306',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245306'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1245306';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245306';


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245306',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245306
AND cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245306', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id       => '1245306',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
    p_charge_id    => '1245306',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
            AND charge_id = '1245306';

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
            p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
            p_charge_id    => '1245306',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9'
        AND charge_id = '1245306';
        
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='CHARGES_PROCESSED'
    WHERE cleanup_id = 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9';
    
    JISREM.LOG
    (
        p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => 'd5fba7f4-ad3b-4f04-8cad-7e070e3e9fc9',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

