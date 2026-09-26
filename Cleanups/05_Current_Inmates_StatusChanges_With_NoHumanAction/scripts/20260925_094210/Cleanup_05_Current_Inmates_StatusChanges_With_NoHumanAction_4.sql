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
    WHERE cleanup_name='20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_4';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_4] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('97695d81-bed1-46f7-b287-6187f513d45b','20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_4','Target current Inmates with changes to status, location, or bond amount that have no human activity in the audit trail after the first status, location, or bond amt change in the go live period.','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2026A4', '1227292', '277689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2026A5', '1227293', '277689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2027A2', '1227298', '277689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2027A4', '1227300', '277689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2054A2', '1227435', '78646', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF246A4', '1216071', '274757', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF246A7', '1216074', '274757', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2557A3', '1230657', '279181', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2627A3', '1231056', '279687', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2830A2', '1232344', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2830A6', '1232348', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2830A8', '1232350', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF283A2', '1216738', '278033', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2917A4', '1232878', '241974', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2917A6', '1232880', '241974', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2934B13', '1233400', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2934B3', '1233391', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2934B6', '1233394', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2934B7', '1233395', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2939A2', '1233033', '252306', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2939A3', '1233034', '252306', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2946A2', '1233094', '280168', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2974A32', '1240897', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF2974A33', '1240898', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF3193A4', '1234657', '252306', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF599A3', '1218090', '155506', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF664A1', '1218439', '278302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CF676A3', '1218504', '267704', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025CT165A3', '1216238', '168108', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025HH1057A1', '1233439', '127827', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025HH106A1', '1216764', '278080', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025HH1165A4', '1235126', '280023', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025HH74A3', '1216291', '255662', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025MM1843A2', '1231959', '207281', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2025MM2159A2', '1234637', '244579', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1183A4', '1244371', '145279', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF14A1', '1236685', '243836', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1672A1', '1247131', '248979', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1694A3', '1247360', '192786', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1709A2', '1247418', '264042', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1845A17', '1248423', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1845A36', '1248443', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1845A39', '1248446', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF1864A2', '1248535', '278219', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF523A1', '1239825', '204382', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF530A4', '1239879', '143959', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF551A12', '1240119', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF551A14', '1240121', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF551A20', '1240127', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF881A1', '1242690', '232816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF899A1', '1242791', '264199', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CF935A2', '1242974', '275940', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026CT1191A2', '1252768', '280007', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026HH605A3', '1248062', '257302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026MM1391A1', '1249697', '281390', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026MM554A1', '1241467', '199238', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2026MM865A1', '1244766', '241382', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2005MM8033A1', '575068', '34745', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2009CF2608A1', '716640', '98344', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2009CF4100A1', '729643', '101471', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2010CF1454A1', '741558', '98344', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2011MM4580A1', '789672', '220932', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2013CF1494A1', '865520', '202776', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2013CF1494A3', '865522', '202776', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2014CF2840A1', '924401', '237549', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2016CF3063A3', '997981', '247257', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2019CF2854A3', '1087035', '260219', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2019CF2857A1', '1087046', '260977', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2019CF3477A1', '1090813', '261627', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2019CF3817A2', '1093071', '259456', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2020CF1720A1', '1108168', '264005', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2020CF1766A3', '1108410', '170792', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2020CF2037A1', '1109648', '264154', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2020CF2720A1', '1114845', '105906', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2020CF3366A3', '1122053', '105906', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2020HH172A2', '1099081', '260219', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2020HH172A8', '1099087', '260219', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2021CF1046A1', '1129202', '266204', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2021CF1080A1', '1129647', '260795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2021CF3050A1', '1144307', '268080', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2021CF568A1', '1126282', '264614', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2022CF1537A1', '1155169', '256641', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2022CF1537A3', '1155170', '256641', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2022CF1599A5', '1155493', '232816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2022CF162A1', '1147613', '260977', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2022CF2314A4', '1159331', '261226', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2022CF856A4', '1151629', '269220', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF1135A2', '1175785', '272689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF189E14', '1176246', '272689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF189E15', '1176245', '272689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF196A12', '1169867', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF196A7', '1169862', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF196A8', '1169863', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF2216A1', '1183591', '258701', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF2320A1', '1184268', '273676', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF2547A3', '1185940', '273890', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF2547A4', '1185944', '273890', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023CF2806A1', '1187361', '235826', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023MM1146A1', '1179629', '257737', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('97695d81-bed1-46f7-b287-6187f513d45b', '2023MM2401A2', '1190769', '105578', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_4] started'
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocationBondAmount::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1227292 CJIS_CASE_NUMBER 2025CF2026A4
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
AND cjis_case_number = '2025CF2026A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227292',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1227292;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1227292';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227292',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227292'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1227292';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227292';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227292',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1227292
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
and source_row.CHARGE_ID = 1227292
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227292',
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
AND CHARGE_ID = 1227292
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227292', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227292',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227292',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1227292';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1227292',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1227292';
        
END;
/

/***********************************************************
***** CHARGE 1227293 CJIS_CASE_NUMBER 2025CF2026A5
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
AND cjis_case_number = '2025CF2026A5'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227293',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1227293;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1227293';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227293',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227293'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1227293';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227293';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227293',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1227293
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
and source_row.CHARGE_ID = 1227293
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227293',
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
AND CHARGE_ID = 1227293
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227293', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227293',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227293',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1227293';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1227293',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1227293';
        
END;
/

/***********************************************************
***** CHARGE 1227298 CJIS_CASE_NUMBER 2025CF2027A2
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
AND cjis_case_number = '2025CF2027A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227298',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1227298;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1227298';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227298',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227298'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1227298';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227298';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227298',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1227298
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
and source_row.CHARGE_ID = 1227298
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227298',
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
AND CHARGE_ID = 1227298
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227298', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227298',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227298',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1227298';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1227298',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1227298';
        
END;
/

/***********************************************************
***** CHARGE 1227300 CJIS_CASE_NUMBER 2025CF2027A4
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
AND cjis_case_number = '2025CF2027A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227300',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1227300;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1227300';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227300',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227300'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1227300';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227300';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227300',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1227300
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
and source_row.CHARGE_ID = 1227300
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227300',
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
AND CHARGE_ID = 1227300
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227300', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227300',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227300',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1227300';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1227300',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1227300';
        
END;
/

/***********************************************************
***** CHARGE 1227435 CJIS_CASE_NUMBER 2025CF2054A2
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
AND cjis_case_number = '2025CF2054A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227435',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1227435;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1227435';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227435',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227435'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1227435';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227435';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227435',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1227435
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
and source_row.CHARGE_ID = 1227435
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227435',
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
AND CHARGE_ID = 1227435
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227435', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1227435',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1227435',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1227435';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1227435',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1227435';
        
END;
/

/***********************************************************
***** CHARGE 1216071 CJIS_CASE_NUMBER 2025CF246A4
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
AND cjis_case_number = '2025CF246A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216071',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1216071;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1216071';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216071',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216071'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216071';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216071';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216071',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1216071
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
and source_row.CHARGE_ID = 1216071
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216071',
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
AND CHARGE_ID = 1216071
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216071', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216071',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216071',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1216071';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1216071',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1216071';
        
END;
/

/***********************************************************
***** CHARGE 1216074 CJIS_CASE_NUMBER 2025CF246A7
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
AND cjis_case_number = '2025CF246A7'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216074',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1216074;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1216074';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216074',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216074'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216074';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216074';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216074',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1216074
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
and source_row.CHARGE_ID = 1216074
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216074',
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
AND CHARGE_ID = 1216074
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216074', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216074',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216074',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1216074';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1216074',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1216074';
        
END;
/

/***********************************************************
***** CHARGE 1230657 CJIS_CASE_NUMBER 2025CF2557A3
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
AND cjis_case_number = '2025CF2557A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1230657',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1230657;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1230657';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1230657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230657'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1230657';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230657';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1230657',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1230657
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
and source_row.CHARGE_ID = 1230657
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1230657',
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
AND CHARGE_ID = 1230657
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230657', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1230657',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1230657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1230657';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1230657',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1230657';
        
END;
/

/***********************************************************
***** CHARGE 1231056 CJIS_CASE_NUMBER 2025CF2627A3
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
AND cjis_case_number = '2025CF2627A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1231056',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1231056;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1231056';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1231056',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231056'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1231056';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231056';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1231056',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1231056
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
and source_row.CHARGE_ID = 1231056
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1231056',
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
AND CHARGE_ID = 1231056
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231056', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1231056',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1231056',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1231056';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1231056',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1231056';
        
END;
/

/***********************************************************
***** CHARGE 1232344 CJIS_CASE_NUMBER 2025CF2830A2
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
AND cjis_case_number = '2025CF2830A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232344',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1232344;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1232344';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232344',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232344'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1232344';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232344';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232344',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1232344
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
and source_row.CHARGE_ID = 1232344
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232344',
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
AND CHARGE_ID = 1232344
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232344', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232344',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232344',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1232344';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1232344',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1232344';
        
END;
/

/***********************************************************
***** CHARGE 1232348 CJIS_CASE_NUMBER 2025CF2830A6
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
AND cjis_case_number = '2025CF2830A6'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232348',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1232348;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1232348';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232348',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232348'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1232348';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232348';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232348',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1232348
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
and source_row.CHARGE_ID = 1232348
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232348',
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
AND CHARGE_ID = 1232348
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232348', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232348',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232348',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1232348';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1232348',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1232348';
        
END;
/

/***********************************************************
***** CHARGE 1232350 CJIS_CASE_NUMBER 2025CF2830A8
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
AND cjis_case_number = '2025CF2830A8'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232350',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1232350;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1232350';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232350',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232350'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1232350';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232350';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232350',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1232350
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
and source_row.CHARGE_ID = 1232350
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232350',
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
AND CHARGE_ID = 1232350
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232350', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232350',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232350',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1232350';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1232350',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1232350';
        
END;
/

/***********************************************************
***** CHARGE 1216738 CJIS_CASE_NUMBER 2025CF283A2
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
AND cjis_case_number = '2025CF283A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216738',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1216738;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1216738';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216738',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216738'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '10000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216738';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216738';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216738',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1216738
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
and source_row.CHARGE_ID = 1216738
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216738',
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
AND CHARGE_ID = 1216738
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216738', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216738',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216738',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1216738';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1216738',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1216738';
        
END;
/

/***********************************************************
***** CHARGE 1232878 CJIS_CASE_NUMBER 2025CF2917A4
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
AND cjis_case_number = '2025CF2917A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232878',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1232878;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1232878';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232878',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232878'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1232878';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232878';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232878',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1232878
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
and source_row.CHARGE_ID = 1232878
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232878',
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
AND CHARGE_ID = 1232878
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232878', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232878',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232878',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1232878';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1232878',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1232878';
        
END;
/

/***********************************************************
***** CHARGE 1232880 CJIS_CASE_NUMBER 2025CF2917A6
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
AND cjis_case_number = '2025CF2917A6'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232880',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1232880;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1232880';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232880',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232880'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1232880';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232880';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232880',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1232880
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
and source_row.CHARGE_ID = 1232880
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232880',
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
AND CHARGE_ID = 1232880
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232880', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1232880',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1232880',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1232880';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1232880',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1232880';
        
END;
/

/***********************************************************
***** CHARGE 1233400 CJIS_CASE_NUMBER 2025CF2934B13
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
AND cjis_case_number = '2025CF2934B13'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233400',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233400;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233400';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233400',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233400'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233400';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233400';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233400',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233400
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
and source_row.CHARGE_ID = 1233400
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233400',
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
AND CHARGE_ID = 1233400
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233400', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233400',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233400',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233400';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233400',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233400';
        
END;
/

/***********************************************************
***** CHARGE 1233391 CJIS_CASE_NUMBER 2025CF2934B3
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
AND cjis_case_number = '2025CF2934B3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233391',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233391;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233391';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233391',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233391'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233391';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233391';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233391',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233391
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
and source_row.CHARGE_ID = 1233391
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233391',
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
AND CHARGE_ID = 1233391
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233391', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233391',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233391',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233391';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233391',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233391';
        
END;
/

/***********************************************************
***** CHARGE 1233394 CJIS_CASE_NUMBER 2025CF2934B6
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
AND cjis_case_number = '2025CF2934B6'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233394',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233394;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233394';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233394',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233394'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233394';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233394';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233394',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233394
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
and source_row.CHARGE_ID = 1233394
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233394',
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
AND CHARGE_ID = 1233394
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233394', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233394',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233394',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233394';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233394',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233394';
        
END;
/

/***********************************************************
***** CHARGE 1233395 CJIS_CASE_NUMBER 2025CF2934B7
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
AND cjis_case_number = '2025CF2934B7'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233395',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233395;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233395';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233395',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233395'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233395';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233395';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233395',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233395
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
and source_row.CHARGE_ID = 1233395
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233395',
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
AND CHARGE_ID = 1233395
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233395', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233395',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233395',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233395';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233395',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233395';
        
END;
/

/***********************************************************
***** CHARGE 1233033 CJIS_CASE_NUMBER 2025CF2939A2
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
AND cjis_case_number = '2025CF2939A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233033',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233033;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233033';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233033',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233033'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1233033';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233033';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233033',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233033
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
and source_row.CHARGE_ID = 1233033
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233033',
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
AND CHARGE_ID = 1233033
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233033', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233033',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233033',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233033';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233033',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233033';
        
END;
/

/***********************************************************
***** CHARGE 1233034 CJIS_CASE_NUMBER 2025CF2939A3
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
AND cjis_case_number = '2025CF2939A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233034',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233034;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233034';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233034',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233034'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1233034';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233034';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233034',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233034
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
and source_row.CHARGE_ID = 1233034
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233034',
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
AND CHARGE_ID = 1233034
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233034', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233034',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233034',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233034';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233034',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233034';
        
END;
/

/***********************************************************
***** CHARGE 1233094 CJIS_CASE_NUMBER 2025CF2946A2
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
AND cjis_case_number = '2025CF2946A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233094',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233094;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233094';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233094',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233094'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233094';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233094';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233094',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233094
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
and source_row.CHARGE_ID = 1233094
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233094',
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
AND CHARGE_ID = 1233094
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233094', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233094',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233094',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233094';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233094',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233094';
        
END;
/

/***********************************************************
***** CHARGE 1240897 CJIS_CASE_NUMBER 2025CF2974A32
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
AND cjis_case_number = '2025CF2974A32'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240897',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1240897;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1240897';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240897',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240897'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1240897';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240897';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240897',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1240897
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
and source_row.CHARGE_ID = 1240897
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240897',
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
AND CHARGE_ID = 1240897
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240897', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240897',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240897',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1240897';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1240897',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1240897';
        
END;
/

/***********************************************************
***** CHARGE 1240898 CJIS_CASE_NUMBER 2025CF2974A33
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
AND cjis_case_number = '2025CF2974A33'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240898',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1240898;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1240898';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240898',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240898'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1240898';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240898';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240898',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1240898
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
and source_row.CHARGE_ID = 1240898
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240898',
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
AND CHARGE_ID = 1240898
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240898', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240898',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240898',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1240898';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1240898',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1240898';
        
END;
/

/***********************************************************
***** CHARGE 1234657 CJIS_CASE_NUMBER 2025CF3193A4
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
AND cjis_case_number = '2025CF3193A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1234657',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1234657;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1234657';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1234657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234657'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1234657';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234657';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1234657',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1234657
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
and source_row.CHARGE_ID = 1234657
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1234657',
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
AND CHARGE_ID = 1234657
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234657', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1234657',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1234657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1234657';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1234657',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1234657';
        
END;
/

/***********************************************************
***** CHARGE 1218090 CJIS_CASE_NUMBER 2025CF599A3
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
AND cjis_case_number = '2025CF599A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218090',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1218090;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1218090';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218090',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218090'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218090';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218090';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218090',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1218090
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
and source_row.CHARGE_ID = 1218090
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218090',
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
AND CHARGE_ID = 1218090
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218090', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218090',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218090',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1218090';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1218090',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1218090';
        
END;
/

/***********************************************************
***** CHARGE 1218439 CJIS_CASE_NUMBER 2025CF664A1
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
AND cjis_case_number = '2025CF664A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218439',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1218439;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1218439';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218439',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218439'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218439';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218439';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218439',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1218439
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
and source_row.CHARGE_ID = 1218439
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218439',
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
AND CHARGE_ID = 1218439
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218439', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218439',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218439',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1218439';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1218439',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1218439';
        
END;
/

/***********************************************************
***** CHARGE 1218504 CJIS_CASE_NUMBER 2025CF676A3
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
AND cjis_case_number = '2025CF676A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218504',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1218504;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1218504';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218504',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218504'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1218504';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218504';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218504',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1218504
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
and source_row.CHARGE_ID = 1218504
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218504',
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
AND CHARGE_ID = 1218504
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218504', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1218504',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1218504',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1218504';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1218504',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1218504';
        
END;
/

/***********************************************************
***** CHARGE 1216238 CJIS_CASE_NUMBER 2025CT165A3
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
AND cjis_case_number = '2025CT165A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216238',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1216238;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1216238';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216238',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216238'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216238';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216238';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216238',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1216238
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
and source_row.CHARGE_ID = 1216238
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216238',
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
AND CHARGE_ID = 1216238
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216238', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216238',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216238',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1216238';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1216238',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1216238';
        
END;
/

/***********************************************************
***** CHARGE 1233439 CJIS_CASE_NUMBER 2025HH1057A1
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
AND cjis_case_number = '2025HH1057A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233439',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1233439;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1233439';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233439',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233439'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1233439';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233439';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233439',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1233439
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
and source_row.CHARGE_ID = 1233439
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233439',
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
AND CHARGE_ID = 1233439
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233439', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1233439',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1233439',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1233439';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1233439',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1233439';
        
END;
/

/***********************************************************
***** CHARGE 1216764 CJIS_CASE_NUMBER 2025HH106A1
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
AND cjis_case_number = '2025HH106A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216764',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1216764;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1216764';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216764',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216764'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '2500',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216764';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216764';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216764',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1216764
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
and source_row.CHARGE_ID = 1216764
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216764',
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
AND CHARGE_ID = 1216764
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216764', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216764',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216764',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1216764';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1216764',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1216764';
        
END;
/

/***********************************************************
***** CHARGE 1235126 CJIS_CASE_NUMBER 2025HH1165A4
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
AND cjis_case_number = '2025HH1165A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1235126',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1235126;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1235126';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1235126',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235126'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1235126';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235126';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1235126',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1235126
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
and source_row.CHARGE_ID = 1235126
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1235126',
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
AND CHARGE_ID = 1235126
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235126', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1235126',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1235126',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1235126';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1235126',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1235126';
        
END;
/

/***********************************************************
***** CHARGE 1216291 CJIS_CASE_NUMBER 2025HH74A3
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
AND cjis_case_number = '2025HH74A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216291',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1216291;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1216291';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216291',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216291'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1216291';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216291';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216291',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1216291
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
and source_row.CHARGE_ID = 1216291
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216291',
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
AND CHARGE_ID = 1216291
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216291', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1216291',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1216291',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1216291';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1216291',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1216291';
        
END;
/

/***********************************************************
***** CHARGE 1231959 CJIS_CASE_NUMBER 2025MM1843A2
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
AND cjis_case_number = '2025MM1843A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1231959',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1231959;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1231959';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1231959',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231959'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1231959';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231959';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1231959',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1231959
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
and source_row.CHARGE_ID = 1231959
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1231959',
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
AND CHARGE_ID = 1231959
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231959', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1231959',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1231959',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1231959';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1231959',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1231959';
        
END;
/

/***********************************************************
***** CHARGE 1234637 CJIS_CASE_NUMBER 2025MM2159A2
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
AND cjis_case_number = '2025MM2159A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1234637',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1234637;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1234637';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1234637',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234637'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'F',
    BOND_AMT = '',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1234637';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234637';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1234637',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1234637
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
and source_row.CHARGE_ID = 1234637
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1234637',
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
AND CHARGE_ID = 1234637
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234637', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1234637',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1234637',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1234637';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1234637',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1234637';
        
END;
/

/***********************************************************
***** CHARGE 1244371 CJIS_CASE_NUMBER 2026CF1183A4
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
AND cjis_case_number = '2026CF1183A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1244371',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1244371;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1244371';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1244371',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244371'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244371';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244371';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1244371',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1244371
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
and source_row.CHARGE_ID = 1244371
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1244371',
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
AND CHARGE_ID = 1244371
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244371', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1244371',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1244371',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1244371';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1244371',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1244371';
        
END;
/

/***********************************************************
***** CHARGE 1236685 CJIS_CASE_NUMBER 2026CF14A1
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
AND cjis_case_number = '2026CF14A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1236685',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1236685;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1236685';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1236685',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236685'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1236685';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236685';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1236685',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1236685
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
and source_row.CHARGE_ID = 1236685
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1236685',
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
AND CHARGE_ID = 1236685
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236685', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1236685',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1236685',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1236685';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1236685',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1236685';
        
END;
/

/***********************************************************
***** CHARGE 1247131 CJIS_CASE_NUMBER 2026CF1672A1
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
AND cjis_case_number = '2026CF1672A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247131',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1247131;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1247131';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247131',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247131'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1247131';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247131';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247131',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1247131
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
and source_row.CHARGE_ID = 1247131
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247131',
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
AND CHARGE_ID = 1247131
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247131', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247131',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247131',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1247131';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1247131',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1247131';
        
END;
/

/***********************************************************
***** CHARGE 1247360 CJIS_CASE_NUMBER 2026CF1694A3
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
AND cjis_case_number = '2026CF1694A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247360',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1247360;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1247360';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247360',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247360'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1247360';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247360';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247360',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1247360
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
and source_row.CHARGE_ID = 1247360
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247360',
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
AND CHARGE_ID = 1247360
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247360', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247360',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247360',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1247360';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1247360',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1247360';
        
END;
/

/***********************************************************
***** CHARGE 1247418 CJIS_CASE_NUMBER 2026CF1709A2
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
AND cjis_case_number = '2026CF1709A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247418',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1247418;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1247418';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247418',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247418'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1247418';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247418';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247418',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1247418
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
and source_row.CHARGE_ID = 1247418
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247418',
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
AND CHARGE_ID = 1247418
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247418', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1247418',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1247418',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1247418';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1247418',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1247418';
        
END;
/

/***********************************************************
***** CHARGE 1248423 CJIS_CASE_NUMBER 2026CF1845A17
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
AND cjis_case_number = '2026CF1845A17'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248423',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1248423;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1248423';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248423',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248423'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248423';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248423';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248423',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1248423
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
and source_row.CHARGE_ID = 1248423
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248423',
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
AND CHARGE_ID = 1248423
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248423', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248423',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248423',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1248423';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1248423',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1248423';
        
END;
/

/***********************************************************
***** CHARGE 1248443 CJIS_CASE_NUMBER 2026CF1845A36
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
AND cjis_case_number = '2026CF1845A36'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248443',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1248443;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1248443';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248443',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248443'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248443';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248443';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248443',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1248443
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
and source_row.CHARGE_ID = 1248443
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248443',
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
AND CHARGE_ID = 1248443
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248443', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248443',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248443',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1248443';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1248443',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1248443';
        
END;
/

/***********************************************************
***** CHARGE 1248446 CJIS_CASE_NUMBER 2026CF1845A39
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
AND cjis_case_number = '2026CF1845A39'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248446',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1248446;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1248446';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248446',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248446'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248446';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248446';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248446',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1248446
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
and source_row.CHARGE_ID = 1248446
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248446',
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
AND CHARGE_ID = 1248446
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248446', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248446',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248446',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1248446';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1248446',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1248446';
        
END;
/

/***********************************************************
***** CHARGE 1248535 CJIS_CASE_NUMBER 2026CF1864A2
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
AND cjis_case_number = '2026CF1864A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248535',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1248535;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1248535';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248535',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248535'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1248535';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248535';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248535',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1248535
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
and source_row.CHARGE_ID = 1248535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248535',
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
AND CHARGE_ID = 1248535
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248535', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248535',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248535',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1248535';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1248535',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1248535';
        
END;
/

/***********************************************************
***** CHARGE 1239825 CJIS_CASE_NUMBER 2026CF523A1
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
AND cjis_case_number = '2026CF523A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1239825',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1239825;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1239825';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1239825',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239825'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1239825';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239825';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1239825',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1239825
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
and source_row.CHARGE_ID = 1239825
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1239825',
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
AND CHARGE_ID = 1239825
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239825', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1239825',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1239825',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1239825';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1239825',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1239825';
        
END;
/

/***********************************************************
***** CHARGE 1239879 CJIS_CASE_NUMBER 2026CF530A4
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
AND cjis_case_number = '2026CF530A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1239879',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1239879;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1239879';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1239879',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239879'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1239879';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239879';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1239879',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1239879
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
and source_row.CHARGE_ID = 1239879
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1239879',
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
AND CHARGE_ID = 1239879
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239879', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1239879',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1239879',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1239879';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1239879',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1239879';
        
END;
/

/***********************************************************
***** CHARGE 1240119 CJIS_CASE_NUMBER 2026CF551A12
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
AND cjis_case_number = '2026CF551A12'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240119',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1240119;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1240119';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240119',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240119'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1240119';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240119';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240119',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1240119
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
and source_row.CHARGE_ID = 1240119
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240119',
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
AND CHARGE_ID = 1240119
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240119', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240119',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240119',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1240119';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1240119',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1240119';
        
END;
/

/***********************************************************
***** CHARGE 1240121 CJIS_CASE_NUMBER 2026CF551A14
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
AND cjis_case_number = '2026CF551A14'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240121',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1240121;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1240121';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240121',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240121'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1240121';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240121';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240121',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1240121
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
and source_row.CHARGE_ID = 1240121
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240121',
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
AND CHARGE_ID = 1240121
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240121', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240121',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240121',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1240121';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1240121',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1240121';
        
END;
/

/***********************************************************
***** CHARGE 1240127 CJIS_CASE_NUMBER 2026CF551A20
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
AND cjis_case_number = '2026CF551A20'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240127',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1240127;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1240127';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240127',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240127'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1240127';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240127';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240127',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1240127
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
and source_row.CHARGE_ID = 1240127
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240127',
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
AND CHARGE_ID = 1240127
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240127', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1240127',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1240127',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1240127';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1240127',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1240127';
        
END;
/

/***********************************************************
***** CHARGE 1242690 CJIS_CASE_NUMBER 2026CF881A1
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
AND cjis_case_number = '2026CF881A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242690',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1242690;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1242690';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242690'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1242690';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242690';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242690',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1242690
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
and source_row.CHARGE_ID = 1242690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242690',
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
AND CHARGE_ID = 1242690
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242690', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242690',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1242690';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1242690',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1242690';
        
END;
/

/***********************************************************
***** CHARGE 1242791 CJIS_CASE_NUMBER 2026CF899A1
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
AND cjis_case_number = '2026CF899A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242791',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1242791;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1242791';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242791',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242791'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1242791';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242791';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242791',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1242791
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
and source_row.CHARGE_ID = 1242791
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242791',
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
AND CHARGE_ID = 1242791
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242791', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242791',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242791',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1242791';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1242791',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1242791';
        
END;
/

/***********************************************************
***** CHARGE 1242974 CJIS_CASE_NUMBER 2026CF935A2
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
AND cjis_case_number = '2026CF935A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242974',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1242974;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1242974';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242974',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242974'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1242974';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242974';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242974',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1242974
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
and source_row.CHARGE_ID = 1242974
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242974',
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
AND CHARGE_ID = 1242974
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242974', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1242974',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1242974',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1242974';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1242974',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1242974';
        
END;
/

/***********************************************************
***** CHARGE 1252768 CJIS_CASE_NUMBER 2026CT1191A2
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
AND cjis_case_number = '2026CT1191A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1252768',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1252768;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1252768';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1252768',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252768'
;

UPDATE JISJDW.CHARGE
SET STATUS = '',
    BOND_AMT = '',
    LOCATION = ''
WHERE CHARGE_ID = '1252768';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252768';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1252768',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1252768
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
and source_row.CHARGE_ID = 1252768
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1252768',
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
AND CHARGE_ID = 1252768
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1252768', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1252768',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1252768',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1252768';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1252768',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1252768';
        
END;
/

/***********************************************************
***** CHARGE 1248062 CJIS_CASE_NUMBER 2026HH605A3
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
AND cjis_case_number = '2026HH605A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248062',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1248062;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1248062';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248062',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248062'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '150',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1248062';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248062';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248062',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1248062
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
and source_row.CHARGE_ID = 1248062
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248062',
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
AND CHARGE_ID = 1248062
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248062', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1248062',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1248062',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1248062';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1248062',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1248062';
        
END;
/

/***********************************************************
***** CHARGE 1249697 CJIS_CASE_NUMBER 2026MM1391A1
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
AND cjis_case_number = '2026MM1391A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1249697',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1249697;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1249697';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1249697',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249697'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1249697';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249697';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1249697',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1249697
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
and source_row.CHARGE_ID = 1249697
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1249697',
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
AND CHARGE_ID = 1249697
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249697', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1249697',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1249697',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1249697';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1249697',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1249697';
        
END;
/

/***********************************************************
***** CHARGE 1241467 CJIS_CASE_NUMBER 2026MM554A1
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
AND cjis_case_number = '2026MM554A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1241467',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1241467;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1241467';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1241467',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241467'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '100',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1241467';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241467';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1241467',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1241467
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
and source_row.CHARGE_ID = 1241467
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1241467',
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
AND CHARGE_ID = 1241467
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241467', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1241467',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1241467',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1241467';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1241467',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1241467';
        
END;
/

/***********************************************************
***** CHARGE 1244766 CJIS_CASE_NUMBER 2026MM865A1
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
AND cjis_case_number = '2026MM865A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1244766',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1244766;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1244766';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1244766',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244766'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '250',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1244766';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244766';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1244766',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1244766
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
and source_row.CHARGE_ID = 1244766
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1244766',
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
AND CHARGE_ID = 1244766
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244766', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1244766',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1244766',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1244766';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1244766',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1244766';
        
END;
/

/***********************************************************
***** CHARGE 575068 CJIS_CASE_NUMBER 2005MM8033A1
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
AND cjis_case_number = '2005MM8033A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '575068',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 575068;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '575068';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '575068',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '575068'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '575068';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '575068';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '575068',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 575068
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
and source_row.CHARGE_ID = 575068
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '575068',
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
AND CHARGE_ID = 575068
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '575068', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '575068',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '575068',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '575068';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '575068',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '575068';
        
END;
/

/***********************************************************
***** CHARGE 716640 CJIS_CASE_NUMBER 2009CF2608A1
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
AND cjis_case_number = '2009CF2608A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '716640',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 716640;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '716640';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '716640',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '716640'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '716640';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '716640';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '716640',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 716640
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
and source_row.CHARGE_ID = 716640
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '716640',
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
AND CHARGE_ID = 716640
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '716640', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '716640',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '716640',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '716640';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '716640',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '716640';
        
END;
/

/***********************************************************
***** CHARGE 729643 CJIS_CASE_NUMBER 2009CF4100A1
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
AND cjis_case_number = '2009CF4100A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '729643',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 729643;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '729643';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '729643',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '729643'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '729643';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '729643';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '729643',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 729643
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
and source_row.CHARGE_ID = 729643
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '729643',
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
AND CHARGE_ID = 729643
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '729643', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '729643',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '729643',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '729643';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '729643',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '729643';
        
END;
/

/***********************************************************
***** CHARGE 741558 CJIS_CASE_NUMBER 2010CF1454A1
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
AND cjis_case_number = '2010CF1454A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '741558',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 741558;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '741558';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '741558',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '741558'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '741558';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '741558';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '741558',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 741558
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
and source_row.CHARGE_ID = 741558
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '741558',
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
AND CHARGE_ID = 741558
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '741558', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '741558',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '741558',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '741558';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '741558',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '741558';
        
END;
/

/***********************************************************
***** CHARGE 789672 CJIS_CASE_NUMBER 2011MM4580A1
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
AND cjis_case_number = '2011MM4580A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '789672',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 789672;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '789672';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '789672',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '789672'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '789672';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '789672';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '789672',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 789672
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
and source_row.CHARGE_ID = 789672
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '789672',
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
AND CHARGE_ID = 789672
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '789672', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '789672',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '789672',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '789672';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '789672',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '789672';
        
END;
/

/***********************************************************
***** CHARGE 865520 CJIS_CASE_NUMBER 2013CF1494A1
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
AND cjis_case_number = '2013CF1494A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '865520',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 865520;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '865520';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '865520',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '865520'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '865520';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '865520';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '865520',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 865520
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
and source_row.CHARGE_ID = 865520
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '865520',
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
AND CHARGE_ID = 865520
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '865520', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '865520',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '865520',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '865520';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '865520',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '865520';
        
END;
/

/***********************************************************
***** CHARGE 865522 CJIS_CASE_NUMBER 2013CF1494A3
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
AND cjis_case_number = '2013CF1494A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '865522',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 865522;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '865522';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '865522',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '865522'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '865522';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '865522';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '865522',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 865522
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
and source_row.CHARGE_ID = 865522
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '865522',
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
AND CHARGE_ID = 865522
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '865522', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '865522',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '865522',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '865522';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '865522',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '865522';
        
END;
/

/***********************************************************
***** CHARGE 924401 CJIS_CASE_NUMBER 2014CF2840A1
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
AND cjis_case_number = '2014CF2840A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '924401',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 924401;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '924401';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '924401',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '924401'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '924401';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '924401';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '924401',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 924401
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
and source_row.CHARGE_ID = 924401
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '924401',
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
AND CHARGE_ID = 924401
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '924401', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '924401',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '924401',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '924401';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '924401',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '924401';
        
END;
/

/***********************************************************
***** CHARGE 997981 CJIS_CASE_NUMBER 2016CF3063A3
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
AND cjis_case_number = '2016CF3063A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '997981',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 997981;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '997981';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '997981',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '997981'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '500',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '997981';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '997981';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '997981',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 997981
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
and source_row.CHARGE_ID = 997981
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '997981',
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
AND CHARGE_ID = 997981
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '997981', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '997981',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '997981',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '997981';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '997981',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '997981';
        
END;
/

/***********************************************************
***** CHARGE 1087035 CJIS_CASE_NUMBER 2019CF2854A3
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
AND cjis_case_number = '2019CF2854A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1087035',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1087035;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1087035';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1087035',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1087035'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1087035';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1087035';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1087035',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1087035
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
and source_row.CHARGE_ID = 1087035
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1087035',
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
AND CHARGE_ID = 1087035
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1087035', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1087035',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1087035',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1087035';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1087035',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1087035';
        
END;
/

/***********************************************************
***** CHARGE 1087046 CJIS_CASE_NUMBER 2019CF2857A1
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
AND cjis_case_number = '2019CF2857A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1087046',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1087046;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1087046';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1087046',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1087046'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1087046';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1087046';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1087046',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1087046
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
and source_row.CHARGE_ID = 1087046
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1087046',
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
AND CHARGE_ID = 1087046
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1087046', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1087046',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1087046',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1087046';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1087046',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1087046';
        
END;
/

/***********************************************************
***** CHARGE 1090813 CJIS_CASE_NUMBER 2019CF3477A1
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
AND cjis_case_number = '2019CF3477A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1090813',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1090813;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1090813';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1090813',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1090813'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1090813';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1090813';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1090813',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1090813
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
and source_row.CHARGE_ID = 1090813
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1090813',
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
AND CHARGE_ID = 1090813
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1090813', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1090813',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1090813',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1090813';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1090813',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1090813';
        
END;
/

/***********************************************************
***** CHARGE 1093071 CJIS_CASE_NUMBER 2019CF3817A2
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
AND cjis_case_number = '2019CF3817A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1093071',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1093071;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1093071';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1093071',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1093071'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1093071';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1093071';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1093071',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1093071
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
and source_row.CHARGE_ID = 1093071
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1093071',
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
AND CHARGE_ID = 1093071
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1093071', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1093071',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1093071',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1093071';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1093071',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1093071';
        
END;
/

/***********************************************************
***** CHARGE 1108168 CJIS_CASE_NUMBER 2020CF1720A1
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
AND cjis_case_number = '2020CF1720A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1108168',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1108168;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1108168';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1108168',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108168'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1108168';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108168';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1108168',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1108168
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
and source_row.CHARGE_ID = 1108168
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1108168',
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
AND CHARGE_ID = 1108168
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1108168', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1108168',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1108168',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1108168';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1108168',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1108168';
        
END;
/

/***********************************************************
***** CHARGE 1108410 CJIS_CASE_NUMBER 2020CF1766A3
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
AND cjis_case_number = '2020CF1766A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1108410',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1108410;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1108410';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1108410',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108410'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1108410';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108410';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1108410',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1108410
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
and source_row.CHARGE_ID = 1108410
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1108410',
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
AND CHARGE_ID = 1108410
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1108410', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1108410',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1108410',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1108410';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1108410',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1108410';
        
END;
/

/***********************************************************
***** CHARGE 1109648 CJIS_CASE_NUMBER 2020CF2037A1
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
AND cjis_case_number = '2020CF2037A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1109648',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1109648;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1109648';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1109648',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1109648'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '10000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1109648';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1109648';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1109648',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1109648
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
and source_row.CHARGE_ID = 1109648
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1109648',
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
AND CHARGE_ID = 1109648
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1109648', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1109648',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1109648',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1109648';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1109648',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1109648';
        
END;
/

/***********************************************************
***** CHARGE 1114845 CJIS_CASE_NUMBER 2020CF2720A1
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
AND cjis_case_number = '2020CF2720A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1114845',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1114845;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1114845';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1114845',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1114845'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1114845';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1114845';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1114845',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1114845
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
and source_row.CHARGE_ID = 1114845
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1114845',
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
AND CHARGE_ID = 1114845
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1114845', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1114845',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1114845',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1114845';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1114845',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1114845';
        
END;
/

/***********************************************************
***** CHARGE 1122053 CJIS_CASE_NUMBER 2020CF3366A3
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
AND cjis_case_number = '2020CF3366A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1122053',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1122053;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1122053';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1122053',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122053'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1122053';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122053';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1122053',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1122053
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
and source_row.CHARGE_ID = 1122053
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1122053',
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
AND CHARGE_ID = 1122053
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122053', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1122053',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1122053',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1122053';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1122053',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1122053';
        
END;
/

/***********************************************************
***** CHARGE 1099081 CJIS_CASE_NUMBER 2020HH172A2
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
AND cjis_case_number = '2020HH172A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1099081',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1099081;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1099081';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1099081',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1099081'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1099081';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1099081';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1099081',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1099081
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
and source_row.CHARGE_ID = 1099081
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1099081',
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
AND CHARGE_ID = 1099081
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1099081', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1099081',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1099081',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1099081';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1099081',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1099081';
        
END;
/

/***********************************************************
***** CHARGE 1099087 CJIS_CASE_NUMBER 2020HH172A8
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
AND cjis_case_number = '2020HH172A8'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1099087',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1099087;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1099087';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1099087',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1099087'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1099087';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1099087';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1099087',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1099087
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
and source_row.CHARGE_ID = 1099087
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1099087',
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
AND CHARGE_ID = 1099087
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1099087', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1099087',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1099087',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1099087';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1099087',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1099087';
        
END;
/

/***********************************************************
***** CHARGE 1129202 CJIS_CASE_NUMBER 2021CF1046A1
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
AND cjis_case_number = '2021CF1046A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1129202',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1129202;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1129202';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1129202',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1129202'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1129202';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1129202';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1129202',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1129202
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
and source_row.CHARGE_ID = 1129202
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1129202',
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
AND CHARGE_ID = 1129202
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1129202', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1129202',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1129202',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1129202';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1129202',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1129202';
        
END;
/

/***********************************************************
***** CHARGE 1129647 CJIS_CASE_NUMBER 2021CF1080A1
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
AND cjis_case_number = '2021CF1080A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1129647',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1129647;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1129647';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1129647',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1129647'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1129647';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1129647';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1129647',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1129647
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
and source_row.CHARGE_ID = 1129647
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1129647',
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
AND CHARGE_ID = 1129647
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1129647', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1129647',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1129647',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1129647';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1129647',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1129647';
        
END;
/

/***********************************************************
***** CHARGE 1144307 CJIS_CASE_NUMBER 2021CF3050A1
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
AND cjis_case_number = '2021CF3050A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1144307',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1144307;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1144307';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1144307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144307'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1144307';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144307';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1144307',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1144307
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
and source_row.CHARGE_ID = 1144307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1144307',
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
AND CHARGE_ID = 1144307
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1144307', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1144307',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1144307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1144307';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1144307',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1144307';
        
END;
/

/***********************************************************
***** CHARGE 1126282 CJIS_CASE_NUMBER 2021CF568A1
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
AND cjis_case_number = '2021CF568A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1126282',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1126282;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1126282';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1126282',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1126282'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1126282';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1126282';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1126282',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1126282
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
and source_row.CHARGE_ID = 1126282
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1126282',
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
AND CHARGE_ID = 1126282
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1126282', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1126282',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1126282',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1126282';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1126282',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1126282';
        
END;
/

/***********************************************************
***** CHARGE 1155169 CJIS_CASE_NUMBER 2022CF1537A1
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
AND cjis_case_number = '2022CF1537A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155169',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1155169;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1155169';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155169',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155169'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1155169';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155169';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155169',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1155169
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
and source_row.CHARGE_ID = 1155169
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155169',
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
AND CHARGE_ID = 1155169
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1155169', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155169',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155169',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1155169';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1155169',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1155169';
        
END;
/

/***********************************************************
***** CHARGE 1155170 CJIS_CASE_NUMBER 2022CF1537A3
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
AND cjis_case_number = '2022CF1537A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155170',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1155170;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1155170';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155170',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155170'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1155170';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155170';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155170',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1155170
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
and source_row.CHARGE_ID = 1155170
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155170',
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
AND CHARGE_ID = 1155170
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1155170', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155170',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155170',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1155170';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1155170',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1155170';
        
END;
/

/***********************************************************
***** CHARGE 1155493 CJIS_CASE_NUMBER 2022CF1599A5
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
AND cjis_case_number = '2022CF1599A5'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155493',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1155493;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1155493';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155493',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155493'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1155493';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155493';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155493',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1155493
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
and source_row.CHARGE_ID = 1155493
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155493',
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
AND CHARGE_ID = 1155493
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1155493', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1155493',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1155493',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1155493';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1155493',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1155493';
        
END;
/

/***********************************************************
***** CHARGE 1147613 CJIS_CASE_NUMBER 2022CF162A1
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
AND cjis_case_number = '2022CF162A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1147613',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1147613;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1147613';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1147613',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1147613'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1147613';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1147613';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1147613',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1147613
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
and source_row.CHARGE_ID = 1147613
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1147613',
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
AND CHARGE_ID = 1147613
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1147613', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1147613',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1147613',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1147613';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1147613',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1147613';
        
END;
/

/***********************************************************
***** CHARGE 1159331 CJIS_CASE_NUMBER 2022CF2314A4
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
AND cjis_case_number = '2022CF2314A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1159331',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1159331;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1159331';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1159331',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1159331'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1159331';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1159331';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1159331',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1159331
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
and source_row.CHARGE_ID = 1159331
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1159331',
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
AND CHARGE_ID = 1159331
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1159331', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1159331',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1159331',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1159331';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1159331',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1159331';
        
END;
/

/***********************************************************
***** CHARGE 1151629 CJIS_CASE_NUMBER 2022CF856A4
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
AND cjis_case_number = '2022CF856A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1151629',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1151629;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1151629';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1151629',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1151629'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1151629';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1151629';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1151629',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1151629
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
and source_row.CHARGE_ID = 1151629
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1151629',
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
AND CHARGE_ID = 1151629
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1151629', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1151629',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1151629',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1151629';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1151629',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1151629';
        
END;
/

/***********************************************************
***** CHARGE 1175785 CJIS_CASE_NUMBER 2023CF1135A2
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
AND cjis_case_number = '2023CF1135A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1175785',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1175785;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1175785';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1175785',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175785'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1175785';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175785';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1175785',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1175785
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
and source_row.CHARGE_ID = 1175785
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1175785',
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
AND CHARGE_ID = 1175785
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1175785', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1175785',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1175785',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1175785';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1175785',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1175785';
        
END;
/

/***********************************************************
***** CHARGE 1176246 CJIS_CASE_NUMBER 2023CF189E14
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
AND cjis_case_number = '2023CF189E14'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1176246',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1176246;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1176246';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1176246',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176246'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '500',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176246';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176246';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1176246',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1176246
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
and source_row.CHARGE_ID = 1176246
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1176246',
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
AND CHARGE_ID = 1176246
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176246', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1176246',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1176246',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1176246';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1176246',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1176246';
        
END;
/

/***********************************************************
***** CHARGE 1176245 CJIS_CASE_NUMBER 2023CF189E15
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
AND cjis_case_number = '2023CF189E15'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1176245',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1176245;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1176245';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1176245',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176245'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '1000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176245';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176245';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1176245',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1176245
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
and source_row.CHARGE_ID = 1176245
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1176245',
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
AND CHARGE_ID = 1176245
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176245', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1176245',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1176245',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1176245';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1176245',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1176245';
        
END;
/

/***********************************************************
***** CHARGE 1169867 CJIS_CASE_NUMBER 2023CF196A12
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
AND cjis_case_number = '2023CF196A12'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169867',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1169867;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1169867';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169867',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169867'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1169867';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169867';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169867',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1169867
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
and source_row.CHARGE_ID = 1169867
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169867',
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
AND CHARGE_ID = 1169867
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169867', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169867',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169867',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1169867';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1169867',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1169867';
        
END;
/

/***********************************************************
***** CHARGE 1169862 CJIS_CASE_NUMBER 2023CF196A7
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
AND cjis_case_number = '2023CF196A7'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169862',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1169862;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1169862';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169862',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169862'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1169862';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169862';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169862',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1169862
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
and source_row.CHARGE_ID = 1169862
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169862',
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
AND CHARGE_ID = 1169862
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169862', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169862',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169862',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1169862';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1169862',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1169862';
        
END;
/

/***********************************************************
***** CHARGE 1169863 CJIS_CASE_NUMBER 2023CF196A8
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
AND cjis_case_number = '2023CF196A8'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169863',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1169863;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1169863';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169863',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169863'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1169863';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169863';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169863',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1169863
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
and source_row.CHARGE_ID = 1169863
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169863',
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
AND CHARGE_ID = 1169863
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169863', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1169863',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1169863',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1169863';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1169863',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1169863';
        
END;
/

/***********************************************************
***** CHARGE 1183591 CJIS_CASE_NUMBER 2023CF2216A1
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
AND cjis_case_number = '2023CF2216A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1183591',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1183591;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1183591';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1183591',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1183591'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1183591';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1183591';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1183591',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1183591
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
and source_row.CHARGE_ID = 1183591
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1183591',
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
AND CHARGE_ID = 1183591
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1183591', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1183591',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1183591',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1183591';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1183591',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1183591';
        
END;
/

/***********************************************************
***** CHARGE 1184268 CJIS_CASE_NUMBER 2023CF2320A1
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
AND cjis_case_number = '2023CF2320A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1184268',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1184268;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1184268';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1184268',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1184268'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1184268';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1184268';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1184268',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1184268
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
and source_row.CHARGE_ID = 1184268
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1184268',
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
AND CHARGE_ID = 1184268
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1184268', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1184268',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1184268',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1184268';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1184268',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1184268';
        
END;
/

/***********************************************************
***** CHARGE 1185940 CJIS_CASE_NUMBER 2023CF2547A3
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
AND cjis_case_number = '2023CF2547A3'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1185940',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1185940;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1185940';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1185940',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185940'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '25000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1185940';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185940';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1185940',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1185940
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
and source_row.CHARGE_ID = 1185940
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1185940',
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
AND CHARGE_ID = 1185940
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1185940', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1185940',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1185940',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1185940';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1185940',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1185940';
        
END;
/

/***********************************************************
***** CHARGE 1185944 CJIS_CASE_NUMBER 2023CF2547A4
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
AND cjis_case_number = '2023CF2547A4'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1185944',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1185944;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1185944';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1185944',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185944'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '25000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1185944';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185944';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1185944',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1185944
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
and source_row.CHARGE_ID = 1185944
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1185944',
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
AND CHARGE_ID = 1185944
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1185944', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1185944',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1185944',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1185944';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1185944',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1185944';
        
END;
/

/***********************************************************
***** CHARGE 1187361 CJIS_CASE_NUMBER 2023CF2806A1
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
AND cjis_case_number = '2023CF2806A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1187361',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1187361;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1187361';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1187361',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1187361'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1187361';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1187361';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1187361',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1187361
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
and source_row.CHARGE_ID = 1187361
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1187361',
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
AND CHARGE_ID = 1187361
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1187361', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1187361',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1187361',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1187361';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1187361',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1187361';
        
END;
/

/***********************************************************
***** CHARGE 1179629 CJIS_CASE_NUMBER 2023MM1146A1
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
AND cjis_case_number = '2023MM1146A1'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1179629',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1179629;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1179629';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1179629',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1179629'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1179629';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1179629';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1179629',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1179629
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
and source_row.CHARGE_ID = 1179629
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1179629',
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
AND CHARGE_ID = 1179629
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1179629', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1179629',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1179629',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1179629';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1179629',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1179629';
        
END;
/

/***********************************************************
***** CHARGE 1190769 CJIS_CASE_NUMBER 2023MM2401A2
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
AND cjis_case_number = '2023MM2401A2'
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
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1190769',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = 1190769;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
       AND charge_id = '1190769';

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1190769',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190769'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1190769';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190769';


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1190769',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
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
and source_row.CHARGE_ID = 1190769
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
and source_row.CHARGE_ID = 1190769
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1190769',
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
AND CHARGE_ID = 1190769
AND cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1190769', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '97695d81-bed1-46f7-b287-6187f513d45b' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '97695d81-bed1-46f7-b287-6187f513d45b',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id       => '1190769',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
    p_charge_id    => '1190769',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
            AND charge_id = '1190769';

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
            p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
            p_charge_id    => '1190769',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b'
        AND charge_id = '1190769';
        
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='CHARGES_PROCESSED'
    WHERE cleanup_id = '97695d81-bed1-46f7-b287-6187f513d45b';
    
    JISREM.LOG
    (
        p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => '97695d81-bed1-46f7-b287-6187f513d45b',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

