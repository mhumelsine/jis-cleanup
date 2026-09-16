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
    WHERE cleanup_name='20260916_100908_Cleanup_03_DocketsWithoutStatusChanges_12';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260916_100908_Cleanup_03_DocketsWithoutStatusChanges_12] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7','20260916_100908_Cleanup_03_DocketsWithoutStatusChanges_12','Removes docket entries that do not status changes','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF3309A3', '1212662', '262515', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2020CT156A1', '1098549', '262781', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1275A1', '1244869', '262818', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1275A2', '1244870', '262818', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF1497A1', '1201315', '262892', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF1497A2', '1201316', '262892', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF404A1', '1239178', '262983', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF404A4', '1239180', '262983', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF404A5', '1239179', '262983', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1841A1', '1248377', '263409', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1841A2', '1248376', '263409', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1841A3', '1248378', '263409', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CT904A1', '1248626', '263409', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2625A1', '1231022', '263453', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2625A2', '1231021', '263453', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2020CF1411A1', '1106360', '263521', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1696A1', '1247367', '263573', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF2958A1', '1210243', '263824', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF2958A2', '1210244', '263824', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024HH1134A1', '1213921', '263824', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024HH1134A2', '1213922', '263824', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2020CF1720A2', '1108959', '264005', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026MM1271A1', '1248357', '264042', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2117A1', '1227798', '264168', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2117A2', '1227797', '264168', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF857A1', '1242304', '264268', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF147A1', '1237447', '264348', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2020CF2244A1', '1110600', '264363', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH473A1', '1245565', '264363', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2020CT1258A1', '1113342', '264490', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH664A1', '1249534', '264490', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH664A2', '1249535', '264490', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH664A3', '1249536', '264490', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH664A4', '1249537', '264490', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH664A5', '1249538', '264490', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1901A1', '1248799', '264676', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1901A2', '1248797', '264676', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1901A3', '1248798', '264676', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2020CF2669A1', '1114573', '264693', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2020CF2669A2', '1114574', '264693', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF3004A1', '1210577', '264937', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025MM1983A1', '1233179', '264970', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2760A1', '1231818', '265347', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2760A2', '1231819', '265347', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2760A3', '1231820', '265347', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH211A1', '1240625', '265347', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH211A2', '1240626', '265347', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH211A3', '1240627', '265347', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF224A1', '1193709', '265360', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF224A2', '1193707', '265360', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF224A3', '1193708', '265360', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF3348A1', '1235622', '265512', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF901A1', '1242798', '265652', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF451A1', '1125458', '265688', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF451A2', '1125457', '265688', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF689A1', '1127152', '265688', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF689A2', '1127153', '265688', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH31A1', '1237193', '265804', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH31A2', '1237201', '265804', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF1055A1', '1198789', '266009', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1968A1', '1249796', '266112', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF963A1', '1130364', '266127', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF963A2', '1128657', '266127', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF963A4', '1128658', '266127', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024CF2605A1', '1208013', '266181', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF536A1', '1239924', '266526', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF536A2', '1239922', '266526', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF536A3', '1239923', '266526', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF1439A1', '1132393', '266559', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2024HH512A1', '1202476', '266641', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2563A1', '1230679', '266676', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2563A2', '1230680', '266676', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2025CF2563A3', '1230681', '266676', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026MM96A1', '1237804', '267099', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH375A1', '1244307', '267657', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF2720A1', '1142304', '267758', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF2720A2', '1142306', '267758', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026CF1780A1', '1247767', '267980', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF3050A1', '1144307', '268080', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2021CF3050A3', '1144308', '268080', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2022MM190A1', '1148319', '268690', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2026HH450A1', '1245295', '268695', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B10', '1176120', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B11', '1176121', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B12', '1176122', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B13', '1176205', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B14', '1176123', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B15', '1176124', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B16', '1176206', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B17', '1176207', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B18', '1176208', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B19', '1176209', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B20', '1176210', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B21', '1176211', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B22', '1176212', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B23', '1176213', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B24', '1176214', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B25', '1176215', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B26', '1224286', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('68866252-c8e6-43cf-9ade-fce91966c0d7', '2023CF189B27', '1224283', '269073', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260916_100908_Cleanup_03_DocketsWithoutStatusChanges_12] started'
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[2] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1212662 CJIS_CASE_NUMBER 2024CF3309A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1212662';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1212662',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212662
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212662
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1212662',
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
AND CHARGE_ID = 1212662
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1212662', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1212662',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1212662',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1212662';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1212662',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1212662';
END;
/

/***********************************************************
***** CHARGE 1098549 CJIS_CASE_NUMBER 2020CT156A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1098549';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1098549',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1098549
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1098549
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1098549',
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
AND CHARGE_ID = 1098549
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1098549', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1098549',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1098549',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1098549';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1098549',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1098549';
END;
/

/***********************************************************
***** CHARGE 1244869 CJIS_CASE_NUMBER 2026CF1275A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1244869';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1244869',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244869
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244869
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1244869',
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
AND CHARGE_ID = 1244869
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244869', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1244869',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1244869',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1244869';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1244869',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1244869';
END;
/

/***********************************************************
***** CHARGE 1244870 CJIS_CASE_NUMBER 2026CF1275A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1244870';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1244870',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244870
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244870
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1244870',
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
AND CHARGE_ID = 1244870
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244870', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1244870',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1244870',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1244870';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1244870',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1244870';
END;
/

/***********************************************************
***** CHARGE 1201315 CJIS_CASE_NUMBER 2024CF1497A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1201315';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1201315',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201315
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201315
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1201315',
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
AND CHARGE_ID = 1201315
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1201315', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1201315',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1201315',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1201315';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1201315',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1201315';
END;
/

/***********************************************************
***** CHARGE 1201316 CJIS_CASE_NUMBER 2024CF1497A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1201316';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1201316',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201316
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201316
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1201316',
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
AND CHARGE_ID = 1201316
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1201316', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1201316',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1201316',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1201316';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1201316',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1201316';
END;
/

/***********************************************************
***** CHARGE 1239178 CJIS_CASE_NUMBER 2026CF404A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1239178';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239178',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239178
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239178
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239178',
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
AND CHARGE_ID = 1239178
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239178', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239178',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239178',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1239178';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1239178',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1239178';
END;
/

/***********************************************************
***** CHARGE 1239180 CJIS_CASE_NUMBER 2026CF404A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1239180';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239180',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239180
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239180
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239180',
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
AND CHARGE_ID = 1239180
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239180', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239180',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239180',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1239180';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1239180',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1239180';
END;
/

/***********************************************************
***** CHARGE 1239179 CJIS_CASE_NUMBER 2026CF404A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1239179';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239179',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239179
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239179
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239179',
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
AND CHARGE_ID = 1239179
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239179', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239179',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239179',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1239179';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1239179',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1239179';
END;
/

/***********************************************************
***** CHARGE 1248377 CJIS_CASE_NUMBER 2026CF1841A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248377';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248377',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248377
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248377
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248377',
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
AND CHARGE_ID = 1248377
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248377', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248377',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248377',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248377';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248377',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248377';
END;
/

/***********************************************************
***** CHARGE 1248376 CJIS_CASE_NUMBER 2026CF1841A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248376';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248376',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248376
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248376
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248376',
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
AND CHARGE_ID = 1248376
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248376', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248376',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248376',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248376';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248376',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248376';
END;
/

/***********************************************************
***** CHARGE 1248378 CJIS_CASE_NUMBER 2026CF1841A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248378';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248378',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248378
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248378
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248378',
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
AND CHARGE_ID = 1248378
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248378', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248378',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248378',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248378';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248378',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248378';
END;
/

/***********************************************************
***** CHARGE 1248626 CJIS_CASE_NUMBER 2026CT904A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248626';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248626',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248626
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248626
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248626',
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
AND CHARGE_ID = 1248626
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248626', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248626',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248626',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248626';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248626',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248626';
END;
/

/***********************************************************
***** CHARGE 1231022 CJIS_CASE_NUMBER 2025CF2625A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1231022';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231022',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231022
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231022
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231022',
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
AND CHARGE_ID = 1231022
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231022', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231022',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231022',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1231022';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1231022',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1231022';
END;
/

/***********************************************************
***** CHARGE 1231021 CJIS_CASE_NUMBER 2025CF2625A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1231021';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231021',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231021
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231021
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231021',
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
AND CHARGE_ID = 1231021
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231021', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231021',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231021',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1231021';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1231021',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1231021';
END;
/

/***********************************************************
***** CHARGE 1106360 CJIS_CASE_NUMBER 2020CF1411A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1106360';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1106360',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1106360
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1106360
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1106360',
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
AND CHARGE_ID = 1106360
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1106360', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1106360',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1106360',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1106360';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1106360',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1106360';
END;
/

/***********************************************************
***** CHARGE 1247367 CJIS_CASE_NUMBER 2026CF1696A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1247367';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1247367',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247367
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1247367',
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
AND CHARGE_ID = 1247367
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247367', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1247367',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1247367',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1247367';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1247367',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1247367';
END;
/

/***********************************************************
***** CHARGE 1210243 CJIS_CASE_NUMBER 2024CF2958A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1210243';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1210243',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210243
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210243
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1210243',
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
AND CHARGE_ID = 1210243
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1210243', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1210243',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1210243',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1210243';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1210243',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1210243';
END;
/

/***********************************************************
***** CHARGE 1210244 CJIS_CASE_NUMBER 2024CF2958A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1210244';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1210244',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210244
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210244
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1210244',
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
AND CHARGE_ID = 1210244
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1210244', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1210244',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1210244',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1210244';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1210244',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1210244';
END;
/

/***********************************************************
***** CHARGE 1213921 CJIS_CASE_NUMBER 2024HH1134A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1213921';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1213921',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213921
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213921
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1213921',
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
AND CHARGE_ID = 1213921
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213921', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1213921',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1213921',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1213921';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1213921',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1213921';
END;
/

/***********************************************************
***** CHARGE 1213922 CJIS_CASE_NUMBER 2024HH1134A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1213922';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1213922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1213922',
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
AND CHARGE_ID = 1213922
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213922', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1213922',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1213922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1213922';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1213922',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1213922';
END;
/

/***********************************************************
***** CHARGE 1108959 CJIS_CASE_NUMBER 2020CF1720A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1108959';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1108959',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1108959
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1108959
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1108959',
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
AND CHARGE_ID = 1108959
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1108959', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1108959',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1108959',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1108959';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1108959',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1108959';
END;
/

/***********************************************************
***** CHARGE 1248357 CJIS_CASE_NUMBER 2026MM1271A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248357';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248357',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248357
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248357
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248357',
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
AND CHARGE_ID = 1248357
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248357', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248357',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248357',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248357';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248357',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248357';
END;
/

/***********************************************************
***** CHARGE 1227798 CJIS_CASE_NUMBER 2025CF2117A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1227798';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1227798',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227798
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227798
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1227798',
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
AND CHARGE_ID = 1227798
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227798', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1227798',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1227798',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1227798';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1227798',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1227798';
END;
/

/***********************************************************
***** CHARGE 1227797 CJIS_CASE_NUMBER 2025CF2117A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1227797';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1227797',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227797
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227797
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1227797',
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
AND CHARGE_ID = 1227797
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227797', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1227797',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1227797',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1227797';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1227797',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1227797';
END;
/

/***********************************************************
***** CHARGE 1242304 CJIS_CASE_NUMBER 2026CF857A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1242304';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1242304',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242304
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242304
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1242304',
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
AND CHARGE_ID = 1242304
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242304', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1242304',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1242304',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1242304';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1242304',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1242304';
END;
/

/***********************************************************
***** CHARGE 1237447 CJIS_CASE_NUMBER 2026CF147A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1237447';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237447',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237447
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237447
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237447',
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
AND CHARGE_ID = 1237447
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1237447', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237447',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237447',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1237447';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1237447',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1237447';
END;
/

/***********************************************************
***** CHARGE 1110600 CJIS_CASE_NUMBER 2020CF2244A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1110600';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1110600',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1110600
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1110600
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1110600',
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
AND CHARGE_ID = 1110600
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1110600', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1110600',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1110600',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1110600';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1110600',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1110600';
END;
/

/***********************************************************
***** CHARGE 1245565 CJIS_CASE_NUMBER 2026HH473A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1245565';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1245565',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245565
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245565
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1245565',
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
AND CHARGE_ID = 1245565
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245565', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1245565',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1245565',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1245565';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1245565',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1245565';
END;
/

/***********************************************************
***** CHARGE 1113342 CJIS_CASE_NUMBER 2020CT1258A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1113342';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1113342',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1113342
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1113342
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1113342',
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
AND CHARGE_ID = 1113342
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1113342', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1113342',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1113342',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1113342';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1113342',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1113342';
END;
/

/***********************************************************
***** CHARGE 1249534 CJIS_CASE_NUMBER 2026HH664A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1249534';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249534',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249534
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249534
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249534',
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
AND CHARGE_ID = 1249534
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249534', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249534',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249534',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1249534';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1249534',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1249534';
END;
/

/***********************************************************
***** CHARGE 1249535 CJIS_CASE_NUMBER 2026HH664A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1249535';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249535',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249535
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249535',
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
AND CHARGE_ID = 1249535
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249535', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249535',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249535',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1249535';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1249535',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1249535';
END;
/

/***********************************************************
***** CHARGE 1249536 CJIS_CASE_NUMBER 2026HH664A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1249536';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249536',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249536
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249536
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249536',
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
AND CHARGE_ID = 1249536
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249536', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249536',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249536',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1249536';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1249536',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1249536';
END;
/

/***********************************************************
***** CHARGE 1249537 CJIS_CASE_NUMBER 2026HH664A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1249537';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249537',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249537
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249537
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249537',
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
AND CHARGE_ID = 1249537
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249537', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249537',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249537',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1249537';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1249537',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1249537';
END;
/

/***********************************************************
***** CHARGE 1249538 CJIS_CASE_NUMBER 2026HH664A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1249538';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249538',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249538
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249538
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249538',
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
AND CHARGE_ID = 1249538
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249538', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249538',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249538',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1249538';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1249538',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1249538';
END;
/

/***********************************************************
***** CHARGE 1248799 CJIS_CASE_NUMBER 2026CF1901A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248799';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248799',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248799
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248799
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248799',
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
AND CHARGE_ID = 1248799
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248799', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248799',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248799',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248799';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248799',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248799';
END;
/

/***********************************************************
***** CHARGE 1248797 CJIS_CASE_NUMBER 2026CF1901A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248797';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248797',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248797
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248797
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248797',
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
AND CHARGE_ID = 1248797
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248797', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248797',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248797',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248797';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248797',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248797';
END;
/

/***********************************************************
***** CHARGE 1248798 CJIS_CASE_NUMBER 2026CF1901A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1248798';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248798',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248798
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248798
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248798',
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
AND CHARGE_ID = 1248798
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248798', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1248798',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1248798',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1248798';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1248798',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1248798';
END;
/

/***********************************************************
***** CHARGE 1114573 CJIS_CASE_NUMBER 2020CF2669A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1114573';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1114573',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1114573
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1114573
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1114573',
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
AND CHARGE_ID = 1114573
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1114573', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1114573',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1114573',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1114573';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1114573',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1114573';
END;
/

/***********************************************************
***** CHARGE 1114574 CJIS_CASE_NUMBER 2020CF2669A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1114574';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1114574',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1114574
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1114574
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1114574',
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
AND CHARGE_ID = 1114574
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1114574', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1114574',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1114574',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1114574';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1114574',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1114574';
END;
/

/***********************************************************
***** CHARGE 1210577 CJIS_CASE_NUMBER 2024CF3004A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1210577';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1210577',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210577
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210577
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1210577',
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
AND CHARGE_ID = 1210577
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1210577', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1210577',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1210577',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1210577';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1210577',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1210577';
END;
/

/***********************************************************
***** CHARGE 1233179 CJIS_CASE_NUMBER 2025MM1983A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1233179';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1233179',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233179
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233179
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1233179',
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
AND CHARGE_ID = 1233179
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233179', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1233179',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1233179',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1233179';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1233179',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1233179';
END;
/

/***********************************************************
***** CHARGE 1231818 CJIS_CASE_NUMBER 2025CF2760A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1231818';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231818',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231818
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231818
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231818',
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
AND CHARGE_ID = 1231818
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231818', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231818',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231818',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1231818';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1231818',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1231818';
END;
/

/***********************************************************
***** CHARGE 1231819 CJIS_CASE_NUMBER 2025CF2760A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1231819';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231819',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231819
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231819
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231819',
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
AND CHARGE_ID = 1231819
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231819', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231819',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231819',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1231819';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1231819',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1231819';
END;
/

/***********************************************************
***** CHARGE 1231820 CJIS_CASE_NUMBER 2025CF2760A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1231820';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231820',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231820
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231820
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231820',
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
AND CHARGE_ID = 1231820
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231820', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1231820',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1231820',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1231820';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1231820',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1231820';
END;
/

/***********************************************************
***** CHARGE 1240625 CJIS_CASE_NUMBER 2026HH211A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1240625';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1240625',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240625
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240625
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1240625',
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
AND CHARGE_ID = 1240625
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240625', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1240625',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1240625',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1240625';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1240625',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1240625';
END;
/

/***********************************************************
***** CHARGE 1240626 CJIS_CASE_NUMBER 2026HH211A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1240626';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1240626',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240626
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240626
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1240626',
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
AND CHARGE_ID = 1240626
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240626', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1240626',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1240626',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1240626';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1240626',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1240626';
END;
/

/***********************************************************
***** CHARGE 1240627 CJIS_CASE_NUMBER 2026HH211A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1240627';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1240627',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240627
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240627
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1240627',
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
AND CHARGE_ID = 1240627
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240627', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1240627',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1240627',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1240627';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1240627',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1240627';
END;
/

/***********************************************************
***** CHARGE 1193709 CJIS_CASE_NUMBER 2024CF224A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1193709';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1193709',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193709
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193709
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1193709',
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
AND CHARGE_ID = 1193709
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1193709', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1193709',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1193709',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1193709';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1193709',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1193709';
END;
/

/***********************************************************
***** CHARGE 1193707 CJIS_CASE_NUMBER 2024CF224A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1193707';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1193707',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193707
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193707
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1193707',
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
AND CHARGE_ID = 1193707
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1193707', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1193707',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1193707',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1193707';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1193707',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1193707';
END;
/

/***********************************************************
***** CHARGE 1193708 CJIS_CASE_NUMBER 2024CF224A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1193708';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1193708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193708
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193708
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1193708',
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
AND CHARGE_ID = 1193708
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1193708', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1193708',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1193708',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1193708';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1193708',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1193708';
END;
/

/***********************************************************
***** CHARGE 1235622 CJIS_CASE_NUMBER 2025CF3348A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1235622';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1235622',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235622
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235622
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1235622',
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
AND CHARGE_ID = 1235622
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235622', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1235622',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1235622',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1235622';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1235622',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1235622';
END;
/

/***********************************************************
***** CHARGE 1242798 CJIS_CASE_NUMBER 2026CF901A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1242798';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1242798',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242798
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242798
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1242798',
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
AND CHARGE_ID = 1242798
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242798', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1242798',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1242798',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1242798';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1242798',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1242798';
END;
/

/***********************************************************
***** CHARGE 1125458 CJIS_CASE_NUMBER 2021CF451A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1125458';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1125458',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1125458
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1125458
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1125458',
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
AND CHARGE_ID = 1125458
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1125458', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1125458',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1125458',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1125458';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1125458',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1125458';
END;
/

/***********************************************************
***** CHARGE 1125457 CJIS_CASE_NUMBER 2021CF451A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1125457';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1125457',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1125457
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1125457
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1125457',
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
AND CHARGE_ID = 1125457
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1125457', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1125457',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1125457',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1125457';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1125457',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1125457';
END;
/

/***********************************************************
***** CHARGE 1127152 CJIS_CASE_NUMBER 2021CF689A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1127152';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1127152',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1127152
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1127152
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1127152',
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
AND CHARGE_ID = 1127152
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1127152', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1127152',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1127152',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1127152';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1127152',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1127152';
END;
/

/***********************************************************
***** CHARGE 1127153 CJIS_CASE_NUMBER 2021CF689A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1127153';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1127153',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1127153
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1127153
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1127153',
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
AND CHARGE_ID = 1127153
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1127153', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1127153',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1127153',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1127153';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1127153',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1127153';
END;
/

/***********************************************************
***** CHARGE 1237193 CJIS_CASE_NUMBER 2026HH31A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1237193';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237193',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237193
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237193
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237193',
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
AND CHARGE_ID = 1237193
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1237193', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237193',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237193',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1237193';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1237193',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1237193';
END;
/

/***********************************************************
***** CHARGE 1237201 CJIS_CASE_NUMBER 2026HH31A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1237201';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237201',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237201
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237201
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237201',
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
AND CHARGE_ID = 1237201
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1237201', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237201',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237201',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1237201';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1237201',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1237201';
END;
/

/***********************************************************
***** CHARGE 1198789 CJIS_CASE_NUMBER 2024CF1055A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1198789';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1198789',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1198789
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1198789
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1198789',
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
AND CHARGE_ID = 1198789
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1198789', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1198789',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1198789',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1198789';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1198789',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1198789';
END;
/

/***********************************************************
***** CHARGE 1249796 CJIS_CASE_NUMBER 2026CF1968A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1249796';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249796',
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
AND CHARGE_ID = 1249796
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249796', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1249796',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1249796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1249796';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1249796',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1249796';
END;
/

/***********************************************************
***** CHARGE 1130364 CJIS_CASE_NUMBER 2021CF963A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1130364';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1130364',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1130364
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1130364
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1130364',
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
AND CHARGE_ID = 1130364
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1130364', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1130364',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1130364',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1130364';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1130364',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1130364';
END;
/

/***********************************************************
***** CHARGE 1128657 CJIS_CASE_NUMBER 2021CF963A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1128657';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1128657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1128657
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1128657
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1128657',
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
AND CHARGE_ID = 1128657
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1128657', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1128657',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1128657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1128657';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1128657',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1128657';
END;
/

/***********************************************************
***** CHARGE 1128658 CJIS_CASE_NUMBER 2021CF963A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1128658';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1128658',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1128658
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1128658
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1128658',
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
AND CHARGE_ID = 1128658
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1128658', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1128658',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1128658',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1128658';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1128658',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1128658';
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
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1208013';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1208013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
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
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1208013', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1208013',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1208013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1208013';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1208013',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1208013';
END;
/

/***********************************************************
***** CHARGE 1239924 CJIS_CASE_NUMBER 2026CF536A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1239924';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239924',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239924
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239924
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239924',
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
AND CHARGE_ID = 1239924
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239924', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239924',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239924',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1239924';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1239924',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1239924';
END;
/

/***********************************************************
***** CHARGE 1239922 CJIS_CASE_NUMBER 2026CF536A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1239922';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239922',
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
AND CHARGE_ID = 1239922
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239922', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239922',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1239922';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1239922',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1239922';
END;
/

/***********************************************************
***** CHARGE 1239923 CJIS_CASE_NUMBER 2026CF536A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1239923';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239923',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239923
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239923
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239923',
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
AND CHARGE_ID = 1239923
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239923', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1239923',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1239923',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1239923';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1239923',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1239923';
END;
/

/***********************************************************
***** CHARGE 1132393 CJIS_CASE_NUMBER 2021CF1439A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1132393';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1132393',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1132393
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1132393
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1132393',
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
AND CHARGE_ID = 1132393
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1132393', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1132393',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1132393',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1132393';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1132393',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1132393';
END;
/

/***********************************************************
***** CHARGE 1202476 CJIS_CASE_NUMBER 2024HH512A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1202476';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1202476',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202476
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202476
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1202476',
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
AND CHARGE_ID = 1202476
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1202476', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1202476',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1202476',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1202476';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1202476',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1202476';
END;
/

/***********************************************************
***** CHARGE 1230679 CJIS_CASE_NUMBER 2025CF2563A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1230679';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1230679',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230679
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230679
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1230679',
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
AND CHARGE_ID = 1230679
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230679', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1230679',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1230679',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1230679';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1230679',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1230679';
END;
/

/***********************************************************
***** CHARGE 1230680 CJIS_CASE_NUMBER 2025CF2563A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1230680';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1230680',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230680
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230680
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1230680',
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
AND CHARGE_ID = 1230680
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230680', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1230680',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1230680',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1230680';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1230680',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1230680';
END;
/

/***********************************************************
***** CHARGE 1230681 CJIS_CASE_NUMBER 2025CF2563A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1230681';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1230681',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230681
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230681
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1230681',
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
AND CHARGE_ID = 1230681
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230681', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1230681',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1230681',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1230681';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1230681',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1230681';
END;
/

/***********************************************************
***** CHARGE 1237804 CJIS_CASE_NUMBER 2026MM96A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1237804';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237804',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237804
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237804
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237804',
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
AND CHARGE_ID = 1237804
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1237804', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1237804',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1237804',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1237804';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1237804',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1237804';
END;
/

/***********************************************************
***** CHARGE 1244307 CJIS_CASE_NUMBER 2026HH375A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1244307';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1244307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1244307',
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
AND CHARGE_ID = 1244307
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244307', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1244307',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1244307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1244307';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1244307',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1244307';
END;
/

/***********************************************************
***** CHARGE 1142304 CJIS_CASE_NUMBER 2021CF2720A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1142304';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1142304',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1142304
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1142304
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1142304',
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
AND CHARGE_ID = 1142304
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1142304', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1142304',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1142304',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1142304';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1142304',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1142304';
END;
/

/***********************************************************
***** CHARGE 1142306 CJIS_CASE_NUMBER 2021CF2720A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1142306';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1142306',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1142306
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1142306
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1142306',
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
AND CHARGE_ID = 1142306
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1142306', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1142306',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1142306',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1142306';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1142306',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1142306';
END;
/

/***********************************************************
***** CHARGE 1247767 CJIS_CASE_NUMBER 2026CF1780A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1247767';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1247767',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247767
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247767
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1247767',
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
AND CHARGE_ID = 1247767
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247767', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1247767',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1247767',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1247767';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1247767',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1247767';
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
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1144307';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1144307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
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
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1144307', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1144307',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1144307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1144307';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1144307',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1144307';
END;
/

/***********************************************************
***** CHARGE 1144308 CJIS_CASE_NUMBER 2021CF3050A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1144308';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1144308',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1144308
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1144308
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1144308',
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
AND CHARGE_ID = 1144308
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1144308', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1144308',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1144308',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1144308';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1144308',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1144308';
END;
/

/***********************************************************
***** CHARGE 1148319 CJIS_CASE_NUMBER 2022MM190A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1148319';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1148319',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1148319
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1148319
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1148319',
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
AND CHARGE_ID = 1148319
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1148319', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1148319',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1148319',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1148319';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1148319',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1148319';
END;
/

/***********************************************************
***** CHARGE 1245295 CJIS_CASE_NUMBER 2026HH450A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1245295';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1245295',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245295
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245295
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1245295',
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
AND CHARGE_ID = 1245295
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245295', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1245295',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1245295',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1245295';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1245295',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1245295';
END;
/

/***********************************************************
***** CHARGE 1176120 CJIS_CASE_NUMBER 2023CF189B10
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176120';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176120',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176120
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176120
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176120',
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
AND CHARGE_ID = 1176120
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176120', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176120',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176120',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176120';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176120',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176120';
END;
/

/***********************************************************
***** CHARGE 1176121 CJIS_CASE_NUMBER 2023CF189B11
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176121';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176121',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176121
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176121
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176121',
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
AND CHARGE_ID = 1176121
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176121', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176121',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176121',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176121';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176121',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176121';
END;
/

/***********************************************************
***** CHARGE 1176122 CJIS_CASE_NUMBER 2023CF189B12
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176122';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176122',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176122
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176122
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176122',
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
AND CHARGE_ID = 1176122
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176122', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176122',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176122',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176122';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176122',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176122';
END;
/

/***********************************************************
***** CHARGE 1176205 CJIS_CASE_NUMBER 2023CF189B13
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176205';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176205',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176205
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176205
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176205',
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
AND CHARGE_ID = 1176205
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176205', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176205',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176205',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176205';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176205',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176205';
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
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176123';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176123',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
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
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176123', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176123',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176123',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176123';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176123',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176123';
END;
/

/***********************************************************
***** CHARGE 1176124 CJIS_CASE_NUMBER 2023CF189B15
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176124';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176124',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176124
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176124
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176124',
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
AND CHARGE_ID = 1176124
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176124', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176124',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176124',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176124';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176124',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176124';
END;
/

/***********************************************************
***** CHARGE 1176206 CJIS_CASE_NUMBER 2023CF189B16
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176206';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176206',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176206
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176206
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176206',
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
AND CHARGE_ID = 1176206
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176206', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176206',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176206',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176206';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176206',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176206';
END;
/

/***********************************************************
***** CHARGE 1176207 CJIS_CASE_NUMBER 2023CF189B17
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176207';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176207',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176207
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176207
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176207',
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
AND CHARGE_ID = 1176207
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176207', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176207',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176207',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176207';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176207',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176207';
END;
/

/***********************************************************
***** CHARGE 1176208 CJIS_CASE_NUMBER 2023CF189B18
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176208';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176208',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176208
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176208
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176208',
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
AND CHARGE_ID = 1176208
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176208', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176208',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176208',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176208';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176208',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176208';
END;
/

/***********************************************************
***** CHARGE 1176209 CJIS_CASE_NUMBER 2023CF189B19
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176209';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176209',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176209
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176209
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176209',
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
AND CHARGE_ID = 1176209
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176209', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176209',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176209',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176209';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176209',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176209';
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
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176210';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176210',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
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
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176210', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176210',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176210',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176210';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176210',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176210';
END;
/

/***********************************************************
***** CHARGE 1176211 CJIS_CASE_NUMBER 2023CF189B21
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176211';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176211',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176211
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176211
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176211',
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
AND CHARGE_ID = 1176211
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176211', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176211',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176211',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176211';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176211',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176211';
END;
/

/***********************************************************
***** CHARGE 1176212 CJIS_CASE_NUMBER 2023CF189B22
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176212';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176212',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176212
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176212
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176212',
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
AND CHARGE_ID = 1176212
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176212', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176212',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176212',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176212';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176212',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176212';
END;
/

/***********************************************************
***** CHARGE 1176213 CJIS_CASE_NUMBER 2023CF189B23
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176213';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176213
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176213
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176213',
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
AND CHARGE_ID = 1176213
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176213', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176213',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176213';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176213',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176213';
END;
/

/***********************************************************
***** CHARGE 1176214 CJIS_CASE_NUMBER 2023CF189B24
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176214';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176214',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176214
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176214
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176214',
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
AND CHARGE_ID = 1176214
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176214', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176214',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176214',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176214';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176214',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176214';
END;
/

/***********************************************************
***** CHARGE 1176215 CJIS_CASE_NUMBER 2023CF189B25
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1176215';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176215',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176215
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176215
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176215',
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
AND CHARGE_ID = 1176215
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176215', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1176215',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1176215',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1176215';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1176215',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1176215';
END;
/

/***********************************************************
***** CHARGE 1224286 CJIS_CASE_NUMBER 2023CF189B26
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1224286';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1224286',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1224286
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1224286
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1224286',
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
AND CHARGE_ID = 1224286
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1224286', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1224286',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1224286',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1224286';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1224286',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1224286';
END;
/

/***********************************************************
***** CHARGE 1224283 CJIS_CASE_NUMBER 2023CF189B27
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   SAVEPOINT before_record;
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
       AND charge_id = '1224283';

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1224283',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1224283
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1224283
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1224283',
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
AND CHARGE_ID = 1224283
AND cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1224283', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '68866252-c8e6-43cf-9ade-fce91966c0d7' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '68866252-c8e6-43cf-9ade-fce91966c0d7',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id       => '1224283',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
    p_charge_id    => '1224283',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
            AND charge_id = '1224283';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
            p_charge_id    => '1224283',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '68866252-c8e6-43cf-9ade-fce91966c0d7'
        AND charge_id = '1224283';
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='COMPLETED'
    WHERE cleanup_id=CLEANUP_ID;
    
    COMMIT;
    
    JISREM.LOG
    (
        p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
        p_step_name  => 'TRANSACTION',
        p_message    => 'Cleanup transaction committed'
    );
    
 ELSE
    ROLLBACK;
    
    JISREM.LOG
    (
        p_cleanup_id => '68866252-c8e6-43cf-9ade-fce91966c0d7',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true transaction rolled back'
    );
 END IF;
END;
/

