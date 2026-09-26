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
        AND table_name = 'FA_CHARGE';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.FA_CHARGE AS 
            SELECT * 
            FROM JISJDW.FA_CHARGE
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FA_CHARGE ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FA_CHARGE MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FA_CHARGE 
            ADD CONSTRAINT REM_FA_CHARGE_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                FA_CHARGE_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FA_CHARGE 
            ADD CONSTRAINT REM_FA_CHARGE_FK 
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
        AND table_name = 'COURT_CALENDAR';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.COURT_CALENDAR AS 
            SELECT * 
            FROM JISJDW.COURT_CALENDAR
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.COURT_CALENDAR ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.COURT_CALENDAR MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.COURT_CALENDAR 
            ADD CONSTRAINT REM_COURT_CALENDAR_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                COURT_CALENDAR_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.COURT_CALENDAR 
            ADD CONSTRAINT REM_COURT_CALENDAR_FK 
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
        AND table_name = 'FIRST_APPEARANCE';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.FIRST_APPEARANCE AS 
            SELECT * 
            FROM JISJDW.FIRST_APPEARANCE
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FIRST_APPEARANCE ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FIRST_APPEARANCE MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FIRST_APPEARANCE 
            ADD CONSTRAINT REM_FIRST_APPEARANCE_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                FIRST_APPEARANCE_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.FIRST_APPEARANCE 
            ADD CONSTRAINT REM_FIRST_APPEARANCE_FK 
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
        AND table_name = 'CUSTODY_STATUS';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.CUSTODY_STATUS AS 
            SELECT * 
            FROM JISJDW.CUSTODY_STATUS
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CUSTODY_STATUS ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CUSTODY_STATUS MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CUSTODY_STATUS 
            ADD CONSTRAINT REM_CUSTODY_STATUS_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                CUSTODY_STATUS_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.CUSTODY_STATUS 
            ADD CONSTRAINT REM_CUSTODY_STATUS_FK 
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
        AND table_name = 'RELEASE_BOND';

    IF v_table_count = 0
    THEN
        EXECUTE IMMEDIATE
            'CREATE TABLE JISREM.RELEASE_BOND AS 
            SELECT * 
            FROM JISJDW.RELEASE_BOND
            WHERE 1 = 0';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.RELEASE_BOND ADD 
            ( 
                cleanup_id VARCHAR2(50), 
                change_action VARCHAR2(50), 
                row_state VARCHAR2(50) 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.RELEASE_BOND MODIFY 
            ( 
                cleanup_id NOT NULL, 
                change_action NOT NULL, 
                row_state NOT NULL 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.RELEASE_BOND 
            ADD CONSTRAINT REM_RELEASE_BOND_UQ 
            UNIQUE 
            ( 
                cleanup_id, 
                BOND_ID, 
                row_state 
            )';

        EXECUTE IMMEDIATE
            'ALTER TABLE JISREM.RELEASE_BOND 
            ADD CONSTRAINT REM_RELEASE_BOND_FK 
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
    WHERE cleanup_name='20260925_091546_Cleanup_01_GroceryStoreRun_4';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260925_091546_Cleanup_01_GroceryStoreRun_4] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4','20260925_091546_Cleanup_01_GroceryStoreRun_4','Grocery store run; Initial cleanup of cases with only invalid system activity for defendants already released.','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2016CF1431A4', '987134', '199686', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2016CF1431A3', '987133', '199686', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2016CF1431A2', '987132', '199686', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2016CF1431A1', '987131', '199686', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2008MM3938A1', '680578', '199686', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026HH231A1', '1241101', '281224', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026CF660A1', '1240734', '114172', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2024CF1964A1', '1204022', '257981', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2024CF1963A1', '1204018', '257981', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2018CT501A1', '1044642', '243287', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2015CF3742A5', '970713', '243287', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2015CF3742A3', '970711', '243287', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2025MM1359A1', '1227442', '221020', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026MM1202A1', '1247590', '222603', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2006CF3162A2', '604079', '162582', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2006CF3162A1', '604078', '162582', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2021HH687A1', '1144040', '265718', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2005MM5924A1', '567429', '132685', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2025CF2275A2', '1228871', '31578', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026HH546A1', '1246620', '280025', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2019CF458A1', '1073173', '61711', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2025HH679A1', '1227276', '252913', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020HH608A1', '1113377', '252913', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2017CF3848A1', '1035235', '252913', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2013MM1358A2', '861373', '212395', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A9', '1103521', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A23', '1103535', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A15', '1103527', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A14', '1103526', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A13', '1103525', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A12', '1103524', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A11', '1103523', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF963A10', '1103522', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF2868A3', '1118177', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF2212A3', '1110486', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2014MM1731A4', '915008', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2014MM1731A2', '915006', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2006MM7579A1', '612404', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2006CF2362A1', '598020', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026HH524A1', '1246299', '150898', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026HH244A1', '1241367', '150898', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020MM644A1', '1102969', '150898', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2016CF1152A1', '984150', '150898', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2015CF2136A1', '952737', '150898', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026CF1389A3', '1245493', '158208', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026CF1389A2', '1245494', '158208', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026CF1389A1', '1245492', '158208', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026CF376A3', '1239000', '196085', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026CF376A2', '1239001', '196085', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2026CF376A1', '1239002', '196085', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF1126A2', '1104726', '257857', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a57dab2e-8791-45b4-b0a1-909f209b17c4', '2020CF1126A1', '1104725', '257857', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260925_091546_Cleanup_01_GroceryStoreRun_4] started'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[52] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[8] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocationBondAmount::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: FaChargeDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CourtCalendarDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: FirstAppearanceDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CustodyStatusDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: ReleaseBondDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 987134 CJIS_CASE_NUMBER 2016CF1431A4
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
AND cjis_case_number = '2016CF1431A4'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987134',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 987134;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '987134';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987134',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987134'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '987134';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987134';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 987134
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
and source_row.CHARGE_ID = 987134
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987134
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987134
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987134'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987134'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987134
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987134
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 987134
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '987134', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987134',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987134',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '987134';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '987134',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '987134';
        
END;
/

/***********************************************************
***** CHARGE 987133 CJIS_CASE_NUMBER 2016CF1431A3
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
AND cjis_case_number = '2016CF1431A3'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987133',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 987133;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '987133';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987133',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987133'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '987133';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987133';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 987133
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
and source_row.CHARGE_ID = 987133
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987133
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987133
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987133'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987133'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987133
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987133
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 987133
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '987133', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987133',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987133',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '987133';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '987133',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '987133';
        
END;
/

/***********************************************************
***** CHARGE 987132 CJIS_CASE_NUMBER 2016CF1431A2
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
AND cjis_case_number = '2016CF1431A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987132',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 987132;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '987132';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987132',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987132'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '987132';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987132';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 987132
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
and source_row.CHARGE_ID = 987132
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987132
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987132
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987132'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987132'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987132
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987132
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 987132
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '987132', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987132',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987132',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '987132';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '987132',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '987132';
        
END;
/

/***********************************************************
***** CHARGE 987131 CJIS_CASE_NUMBER 2016CF1431A1
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
AND cjis_case_number = '2016CF1431A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987131',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 987131;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '987131';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987131',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987131'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '987131';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '987131';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 987131
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
and source_row.CHARGE_ID = 987131
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987131
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 987131
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 726683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987131'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '987131'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987131
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 987131
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 987131
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '987131', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '987131',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '987131',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '987131';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '987131',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '987131';
        
END;
/

/***********************************************************
***** CHARGE 680578 CJIS_CASE_NUMBER 2008MM3938A1
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
AND cjis_case_number = '2008MM3938A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '680578',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 680578;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '680578';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '680578',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '680578'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '680578';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '680578';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 680578
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
and source_row.CHARGE_ID = 680578
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 680578
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 680578
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 500848
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 500848
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 500848
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 500848
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '680578'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '680578'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 680578
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 680578
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 680578
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '680578', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '680578',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '680578',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '680578';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '680578',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '680578';
        
END;
/

/***********************************************************
***** CHARGE 1241101 CJIS_CASE_NUMBER 2026HH231A1
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
AND cjis_case_number = '2026HH231A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1241101',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1241101;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1241101';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1241101',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241101'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1241101';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241101';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1241101
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
and source_row.CHARGE_ID = 1241101
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1241101
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1241101
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 892960
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 892960
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 892960
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 892960
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1241101'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1241101'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1241101
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1241101
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241101
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241101', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241101',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1241101',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1241101';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1241101',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1241101';
        
END;
/

/***********************************************************
***** CHARGE 1240734 CJIS_CASE_NUMBER 2026CF660A1
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
AND cjis_case_number = '2026CF660A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1240734',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1240734;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1240734';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1240734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240734'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1240734';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240734';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1240734
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
and source_row.CHARGE_ID = 1240734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1240734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1240734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 892726
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 892726
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 892726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 892726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1240734'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1240734'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1240734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1240734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240734
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240734', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1240734',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1240734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1240734';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1240734',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1240734';
        
END;
/

/***********************************************************
***** CHARGE 1204022 CJIS_CASE_NUMBER 2024CF1964A1
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
AND cjis_case_number = '2024CF1964A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1204022',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1204022;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1204022';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1204022',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204022'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1204022';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204022';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1204022
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
and source_row.CHARGE_ID = 1204022
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1204022
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1204022
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 868444
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 868444
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 868444
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 868444
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1204022'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1204022'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1204022
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1204022
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1204022
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1204022', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204022',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1204022',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1204022';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1204022',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1204022';
        
END;
/

/***********************************************************
***** CHARGE 1204018 CJIS_CASE_NUMBER 2024CF1963A1
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
AND cjis_case_number = '2024CF1963A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1204018',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1204018;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1204018';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1204018',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204018'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1204018';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204018';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1204018
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
and source_row.CHARGE_ID = 1204018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1204018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1204018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 868441
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 868441
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 868441
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 868441
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1204018'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1204018'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1204018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1204018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1204018
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1204018', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1204018',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1204018',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1204018';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1204018',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1204018';
        
END;
/

/***********************************************************
***** CHARGE 1044642 CJIS_CASE_NUMBER 2018CT501A1
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
AND cjis_case_number = '2018CT501A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1044642',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1044642;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1044642';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1044642',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1044642'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1044642';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1044642';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1044642
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
and source_row.CHARGE_ID = 1044642
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1044642
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1044642
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 764661
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 764661
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 764661
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 764661
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1044642'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1044642'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1044642
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1044642
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1044642
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1044642', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1044642',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1044642',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1044642';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1044642',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1044642';
        
END;
/

/***********************************************************
***** CHARGE 970713 CJIS_CASE_NUMBER 2015CF3742A5
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
AND cjis_case_number = '2015CF3742A5'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '970713',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 970713;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '970713';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '970713',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '970713'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '970713';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '970713';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 970713
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
and source_row.CHARGE_ID = 970713
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 970713
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 970713
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '970713'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '970713'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 970713
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 970713
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 970713
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '970713', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970713',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '970713',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '970713';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '970713',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '970713';
        
END;
/

/***********************************************************
***** CHARGE 970711 CJIS_CASE_NUMBER 2015CF3742A3
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
AND cjis_case_number = '2015CF3742A3'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '970711',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 970711;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '970711';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '970711',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '970711'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '970711';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '970711';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 970711
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
and source_row.CHARGE_ID = 970711
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 970711
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 970711
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 714655
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '970711'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '970711'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 970711
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 970711
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 970711
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '970711', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '970711',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '970711',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '970711';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '970711',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '970711';
        
END;
/

/***********************************************************
***** CHARGE 1227442 CJIS_CASE_NUMBER 2025MM1359A1
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
AND cjis_case_number = '2025MM1359A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1227442',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1227442;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1227442';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1227442',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227442'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1227442';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227442';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1227442
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
and source_row.CHARGE_ID = 1227442
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1227442
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1227442
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 882557
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 882557
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 882557
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 882557
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1227442'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1227442'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1227442
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1227442
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227442
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227442', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227442',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1227442',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1227442';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1227442',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1227442';
        
END;
/

/***********************************************************
***** CHARGE 1247590 CJIS_CASE_NUMBER 2026MM1202A1
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
AND cjis_case_number = '2026MM1202A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1247590',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1247590;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1247590';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1247590',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247590'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1247590';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247590';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1247590
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
and source_row.CHARGE_ID = 1247590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1247590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1247590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 896852
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 896852
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 896852
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 896852
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1247590'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1247590'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1247590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1247590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247590
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247590', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1247590',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1247590',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1247590';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1247590',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1247590';
        
END;
/

/***********************************************************
***** CHARGE 604079 CJIS_CASE_NUMBER 2006CF3162A2
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
AND cjis_case_number = '2006CF3162A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '604079',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 604079;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '604079';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '604079',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '604079'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '604079';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '604079';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 604079
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
and source_row.CHARGE_ID = 604079
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 604079
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 604079
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '604079'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '604079'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 604079
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 604079
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 604079
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '604079', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604079',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '604079',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '604079';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '604079',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '604079';
        
END;
/

/***********************************************************
***** CHARGE 604078 CJIS_CASE_NUMBER 2006CF3162A1
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
AND cjis_case_number = '2006CF3162A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '604078',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 604078;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '604078';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '604078',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '604078'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '604078';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '604078';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 604078
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
and source_row.CHARGE_ID = 604078
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 604078
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 604078
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 444675
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '604078'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '604078'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 604078
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 604078
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 604078
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '604078', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '604078',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '604078',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '604078';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '604078',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '604078';
        
END;
/

/***********************************************************
***** CHARGE 1144040 CJIS_CASE_NUMBER 2021HH687A1
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
AND cjis_case_number = '2021HH687A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1144040',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1144040;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1144040';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1144040',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144040'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1144040';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144040';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1144040
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
and source_row.CHARGE_ID = 1144040
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1144040
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1144040
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 829517
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 829517
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 829517
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 829517
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1144040'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1144040'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1144040
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1144040
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1144040
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1144040', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1144040',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1144040',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1144040';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1144040',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1144040';
        
END;
/

/***********************************************************
***** CHARGE 567429 CJIS_CASE_NUMBER 2005MM5924A1
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
AND cjis_case_number = '2005MM5924A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '567429',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 567429;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '567429';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '567429',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '567429'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '567429';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '567429';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 567429
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
and source_row.CHARGE_ID = 567429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 567429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 567429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 419016
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 419016
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 419016
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 419016
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '567429'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '567429'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 567429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 567429
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 567429
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '567429', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '567429',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '567429',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '567429';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '567429',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '567429';
        
END;
/

/***********************************************************
***** CHARGE 1228871 CJIS_CASE_NUMBER 2025CF2275A2
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
AND cjis_case_number = '2025CF2275A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1228871',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1228871;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1228871';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1228871',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228871'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1228871';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228871';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1228871
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
and source_row.CHARGE_ID = 1228871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1228871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1228871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 883591
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 883591
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 883591
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 883591
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1228871'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1228871'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1228871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1228871
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228871
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228871', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1228871',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1228871',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1228871';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1228871',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1228871';
        
END;
/

/***********************************************************
***** CHARGE 1246620 CJIS_CASE_NUMBER 2026HH546A1
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
AND cjis_case_number = '2026HH546A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1246620',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1246620;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1246620';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1246620',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246620'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1246620';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246620';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1246620
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
and source_row.CHARGE_ID = 1246620
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1246620
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1246620
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 896056
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 896056
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 896056
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 896056
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246620'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246620'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246620
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246620
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246620
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246620', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246620',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1246620',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1246620';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1246620',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1246620';
        
END;
/

/***********************************************************
***** CHARGE 1073173 CJIS_CASE_NUMBER 2019CF458A1
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
AND cjis_case_number = '2019CF458A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1073173',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1073173;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1073173';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1073173',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1073173'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1073173';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1073173';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1073173
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
and source_row.CHARGE_ID = 1073173
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1073173
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1073173
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 783707
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 783707
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 783707
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 783707
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1073173'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1073173'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1073173
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1073173
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1073173
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1073173', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1073173',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1073173',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1073173';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1073173',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1073173';
        
END;
/

/***********************************************************
***** CHARGE 1227276 CJIS_CASE_NUMBER 2025HH679A1
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
AND cjis_case_number = '2025HH679A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1227276',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1227276;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1227276';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1227276',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227276'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1227276';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227276';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1227276
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
and source_row.CHARGE_ID = 1227276
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1227276
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1227276
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 882450
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 882450
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 882450
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 882450
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1227276'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1227276'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1227276
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1227276
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227276
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227276', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1227276',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1227276',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1227276';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1227276',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1227276';
        
END;
/

/***********************************************************
***** CHARGE 1113377 CJIS_CASE_NUMBER 2020HH608A1
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
AND cjis_case_number = '2020HH608A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1113377',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1113377;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1113377';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1113377',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1113377'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1113377';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1113377';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1113377
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
and source_row.CHARGE_ID = 1113377
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1113377
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1113377
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 809199
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 809199
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 809199
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 809199
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1113377'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1113377'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1113377
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1113377
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1113377
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1113377', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1113377',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1113377',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1113377';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1113377',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1113377';
        
END;
/

/***********************************************************
***** CHARGE 1035235 CJIS_CASE_NUMBER 2017CF3848A1
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
AND cjis_case_number = '2017CF3848A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1035235',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1035235;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1035235';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1035235',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1035235'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1035235';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1035235';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1035235
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
and source_row.CHARGE_ID = 1035235
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1035235
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1035235
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 758260
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 758260
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 758260
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 758260
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1035235'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1035235'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1035235
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1035235
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1035235
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1035235', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1035235',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1035235',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1035235';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1035235',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1035235';
        
END;
/

/***********************************************************
***** CHARGE 861373 CJIS_CASE_NUMBER 2013MM1358A2
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
AND cjis_case_number = '2013MM1358A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '861373',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 861373;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '861373';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '861373',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '861373'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '861373';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '861373';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 861373
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
and source_row.CHARGE_ID = 861373
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 861373
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 861373
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 632560
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 632560
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 632560
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 632560
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '861373'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '861373'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 861373
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 861373
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 861373
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '861373', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '861373',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '861373',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '861373';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '861373',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '861373';
        
END;
/

/***********************************************************
***** CHARGE 1103521 CJIS_CASE_NUMBER 2020CF963A9
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
AND cjis_case_number = '2020CF963A9'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103521',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103521;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103521';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103521',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103521'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103521';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103521';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103521
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
and source_row.CHARGE_ID = 1103521
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103521
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103521
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103521'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103521'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103521
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103521
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103521
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103521', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103521',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103521',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103521';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103521',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103521';
        
END;
/

/***********************************************************
***** CHARGE 1103535 CJIS_CASE_NUMBER 2020CF963A23
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
AND cjis_case_number = '2020CF963A23'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103535',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103535;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103535';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103535',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103535'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103535';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103535';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103535
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
and source_row.CHARGE_ID = 1103535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103535'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103535'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103535
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103535', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103535',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103535',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103535';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103535',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103535';
        
END;
/

/***********************************************************
***** CHARGE 1103527 CJIS_CASE_NUMBER 2020CF963A15
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
AND cjis_case_number = '2020CF963A15'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103527',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103527;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103527';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103527',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103527'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103527';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103527';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103527
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
and source_row.CHARGE_ID = 1103527
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103527
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103527
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103527'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103527'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103527
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103527
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103527
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103527', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103527',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103527',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103527';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103527',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103527';
        
END;
/

/***********************************************************
***** CHARGE 1103526 CJIS_CASE_NUMBER 2020CF963A14
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
AND cjis_case_number = '2020CF963A14'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103526',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103526;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103526';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103526',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103526'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103526';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103526';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103526
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
and source_row.CHARGE_ID = 1103526
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103526
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103526
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103526'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103526'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103526
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103526
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103526
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103526', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103526',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103526',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103526';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103526',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103526';
        
END;
/

/***********************************************************
***** CHARGE 1103525 CJIS_CASE_NUMBER 2020CF963A13
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
AND cjis_case_number = '2020CF963A13'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103525',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103525;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103525';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103525',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103525'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103525';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103525';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103525
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
and source_row.CHARGE_ID = 1103525
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103525
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103525
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103525'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103525'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103525
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103525
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103525
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103525', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103525',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103525',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103525';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103525',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103525';
        
END;
/

/***********************************************************
***** CHARGE 1103524 CJIS_CASE_NUMBER 2020CF963A12
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
AND cjis_case_number = '2020CF963A12'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103524',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103524;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103524';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103524',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103524'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103524';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103524';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103524
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
and source_row.CHARGE_ID = 1103524
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103524
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103524
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103524'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103524'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103524
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103524
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103524
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103524', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103524',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103524',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103524';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103524',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103524';
        
END;
/

/***********************************************************
***** CHARGE 1103523 CJIS_CASE_NUMBER 2020CF963A11
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
AND cjis_case_number = '2020CF963A11'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103523',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103523;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103523';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103523',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103523'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103523';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103523';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103523
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
and source_row.CHARGE_ID = 1103523
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103523
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103523
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103523'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103523'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103523
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103523
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103523
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103523', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103523',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103523',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103523';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103523',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103523';
        
END;
/

/***********************************************************
***** CHARGE 1103522 CJIS_CASE_NUMBER 2020CF963A10
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
AND cjis_case_number = '2020CF963A10'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103522',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1103522;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1103522';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103522',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103522'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103522';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103522';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1103522
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
and source_row.CHARGE_ID = 1103522
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103522
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1103522
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103522'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1103522'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103522
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1103522
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1103522
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103522', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1103522',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1103522',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1103522';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1103522',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1103522';
        
END;
/

/***********************************************************
***** CHARGE 1118177 CJIS_CASE_NUMBER 2020CF2868A3
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
AND cjis_case_number = '2020CF2868A3'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1118177',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1118177;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1118177';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1118177',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1118177'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1118177';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1118177';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1118177
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
and source_row.CHARGE_ID = 1118177
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1118177
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1118177
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 811004
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 811004
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 811004
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 811004
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1118177'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1118177'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1118177
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1118177
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1118177
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1118177', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1118177',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1118177',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1118177';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1118177',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1118177';
        
END;
/

/***********************************************************
***** CHARGE 1110486 CJIS_CASE_NUMBER 2020CF2212A3
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
AND cjis_case_number = '2020CF2212A3'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1110486',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1110486;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1110486';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1110486',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1110486'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1110486';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1110486';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1110486
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
and source_row.CHARGE_ID = 1110486
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1110486
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1110486
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 808676
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 808676
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 808676
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 808676
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1110486'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1110486'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1110486
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1110486
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1110486
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1110486', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1110486',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1110486',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1110486';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1110486',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1110486';
        
END;
/

/***********************************************************
***** CHARGE 915008 CJIS_CASE_NUMBER 2014MM1731A4
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
AND cjis_case_number = '2014MM1731A4'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '915008',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 915008;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '915008';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '915008',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '915008'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '915008';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '915008';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 915008
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
and source_row.CHARGE_ID = 915008
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 915008
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 915008
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '915008'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '915008'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 915008
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 915008
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 915008
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '915008', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915008',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '915008',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '915008';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '915008',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '915008';
        
END;
/

/***********************************************************
***** CHARGE 915006 CJIS_CASE_NUMBER 2014MM1731A2
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
AND cjis_case_number = '2014MM1731A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '915006',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 915006;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '915006';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '915006',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '915006'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '915006';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '915006';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 915006
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
and source_row.CHARGE_ID = 915006
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 915006
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 915006
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 673460
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '915006'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '915006'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 915006
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 915006
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 915006
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '915006', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '915006',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '915006',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '915006';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '915006',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '915006';
        
END;
/

/***********************************************************
***** CHARGE 612404 CJIS_CASE_NUMBER 2006MM7579A1
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
AND cjis_case_number = '2006MM7579A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '612404',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 612404;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '612404';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '612404',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '612404'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '612404';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '612404';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 612404
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
and source_row.CHARGE_ID = 612404
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 612404
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 612404
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 450281
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 450281
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 450281
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 450281
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '612404'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '612404'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 612404
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 612404
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 612404
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '612404', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '612404',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '612404',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '612404';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '612404',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '612404';
        
END;
/

/***********************************************************
***** CHARGE 598020 CJIS_CASE_NUMBER 2006CF2362A1
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
AND cjis_case_number = '2006CF2362A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '598020',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 598020;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '598020';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '598020',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '598020'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '598020';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '598020';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 598020
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
and source_row.CHARGE_ID = 598020
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 598020
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 598020
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 440375
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 440375
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 440375
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 440375
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '598020'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '598020'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 598020
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 598020
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 598020
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '598020', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '598020',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '598020',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '598020';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '598020',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '598020';
        
END;
/

/***********************************************************
***** CHARGE 1246299 CJIS_CASE_NUMBER 2026HH524A1
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
AND cjis_case_number = '2026HH524A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1246299',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1246299;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1246299';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1246299',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246299'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1246299';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246299';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1246299
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
and source_row.CHARGE_ID = 1246299
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1246299
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1246299
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895914
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895914
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895914
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895914
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246299'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246299'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246299
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246299
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246299
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246299', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1246299',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1246299',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1246299';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1246299',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1246299';
        
END;
/

/***********************************************************
***** CHARGE 1241367 CJIS_CASE_NUMBER 2026HH244A1
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
AND cjis_case_number = '2026HH244A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1241367',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1241367;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1241367';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1241367',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241367'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1241367';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241367';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1241367
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
and source_row.CHARGE_ID = 1241367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1241367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1241367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893115
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893115
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893115
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893115
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1241367'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1241367'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1241367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1241367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241367
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241367', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1241367',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1241367',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1241367';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1241367',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1241367';
        
END;
/

/***********************************************************
***** CHARGE 1102969 CJIS_CASE_NUMBER 2020MM644A1
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
AND cjis_case_number = '2020MM644A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1102969',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1102969;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1102969';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1102969',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1102969'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1102969';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1102969';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1102969
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
and source_row.CHARGE_ID = 1102969
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1102969
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1102969
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802433
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 802433
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802433
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 802433
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1102969'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1102969'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1102969
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1102969
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1102969
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1102969', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1102969',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1102969',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1102969';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1102969',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1102969';
        
END;
/

/***********************************************************
***** CHARGE 984150 CJIS_CASE_NUMBER 2016CF1152A1
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
AND cjis_case_number = '2016CF1152A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '984150',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 984150;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '984150';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '984150',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '984150'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '984150';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '984150';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 984150
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
and source_row.CHARGE_ID = 984150
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 984150
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 984150
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 724261
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 724261
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 724261
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 724261
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '984150'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '984150'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 984150
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 984150
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 984150
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '984150', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '984150',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '984150',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '984150';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '984150',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '984150';
        
END;
/

/***********************************************************
***** CHARGE 952737 CJIS_CASE_NUMBER 2015CF2136A1
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
AND cjis_case_number = '2015CF2136A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '952737',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 952737;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '952737';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '952737',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '952737'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '952737';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '952737';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 952737
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
and source_row.CHARGE_ID = 952737
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 952737
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 952737
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 700772
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 700772
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 700772
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 700772
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '952737'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '952737'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 952737
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 952737
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 952737
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '952737', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '952737',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '952737',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '952737';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '952737',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '952737';
        
END;
/

/***********************************************************
***** CHARGE 1245493 CJIS_CASE_NUMBER 2026CF1389A3
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
AND cjis_case_number = '2026CF1389A3'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245493',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1245493;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1245493';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245493',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245493'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1245493';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245493';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1245493
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
and source_row.CHARGE_ID = 1245493
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1245493
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1245493
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1245493'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1245493'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1245493
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1245493
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245493
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245493', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245493',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245493',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1245493';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1245493',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1245493';
        
END;
/

/***********************************************************
***** CHARGE 1245494 CJIS_CASE_NUMBER 2026CF1389A2
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
AND cjis_case_number = '2026CF1389A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245494',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1245494;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1245494';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245494',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245494'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1245494';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245494';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1245494
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
and source_row.CHARGE_ID = 1245494
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1245494
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1245494
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1245494'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1245494'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1245494
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1245494
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245494
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245494', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245494',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245494',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1245494';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1245494',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1245494';
        
END;
/

/***********************************************************
***** CHARGE 1245492 CJIS_CASE_NUMBER 2026CF1389A1
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
AND cjis_case_number = '2026CF1389A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245492',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1245492;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1245492';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245492',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245492'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1245492';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245492';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1245492
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
and source_row.CHARGE_ID = 1245492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1245492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1245492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895398
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1245492'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1245492'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1245492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1245492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245492
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245492', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1245492',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1245492',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1245492';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1245492',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1245492';
        
END;
/

/***********************************************************
***** CHARGE 1239000 CJIS_CASE_NUMBER 2026CF376A3
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
AND cjis_case_number = '2026CF376A3'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239000',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1239000;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1239000';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239000',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239000'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1239000';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239000';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1239000
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
and source_row.CHARGE_ID = 1239000
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1239000
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1239000
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1239000'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1239000'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1239000
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1239000
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239000
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239000', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239000',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239000',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1239000';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1239000',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1239000';
        
END;
/

/***********************************************************
***** CHARGE 1239001 CJIS_CASE_NUMBER 2026CF376A2
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
AND cjis_case_number = '2026CF376A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239001',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1239001;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1239001';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239001',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239001'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1239001';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239001';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1239001
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
and source_row.CHARGE_ID = 1239001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1239001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1239001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1239001'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1239001'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1239001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1239001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239001
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239001', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239001',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239001',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1239001';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1239001',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1239001';
        
END;
/

/***********************************************************
***** CHARGE 1239002 CJIS_CASE_NUMBER 2026CF376A1
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
AND cjis_case_number = '2026CF376A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239002',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1239002;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1239002';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239002',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239002'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1239002';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239002';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1239002
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
and source_row.CHARGE_ID = 1239002
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1239002
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1239002
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1239002'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1239002'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1239002
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1239002
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239002
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239002', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1239002',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1239002',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1239002';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1239002',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1239002';
        
END;
/

/***********************************************************
***** CHARGE 1104726 CJIS_CASE_NUMBER 2020CF1126A2
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
AND cjis_case_number = '2020CF1126A2'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1104726',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1104726;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1104726';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1104726',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1104726'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1104726';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1104726';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1104726
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
and source_row.CHARGE_ID = 1104726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1104726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1104726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1104726'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1104726'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1104726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1104726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1104726
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1104726', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104726',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1104726',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1104726';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1104726',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1104726';
        
END;
/

/***********************************************************
***** CHARGE 1104725 CJIS_CASE_NUMBER 2020CF1126A1
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
AND cjis_case_number = '2020CF1126A1'
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
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1104725',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = 1104725;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
       AND charge_id = '1104725';

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1104725',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1104725'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1104725';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1104725';


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
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
and source_row.CHARGE_ID = 1104725
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
and source_row.CHARGE_ID = 1104725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1104725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1104725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 803548
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1104725'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1104725'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1104725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1104725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'ReleaseBondDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1104725
AND cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1104725', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a57dab2e-8791-45b4-b0a1-909f209b17c4' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id       => '1104725',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
    p_charge_id    => '1104725',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
            AND charge_id = '1104725';

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
            p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
            p_charge_id    => '1104725',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4'
        AND charge_id = '1104725';
        
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='CHARGES_PROCESSED'
    WHERE cleanup_id = 'a57dab2e-8791-45b4-b0a1-909f209b17c4';
    
    JISREM.LOG
    (
        p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => 'a57dab2e-8791-45b4-b0a1-909f209b17c4',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

