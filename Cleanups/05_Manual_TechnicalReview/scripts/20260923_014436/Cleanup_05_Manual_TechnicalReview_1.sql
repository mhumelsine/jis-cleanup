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
    WHERE cleanup_name='20260923_014436_Cleanup_05_Manual_TechnicalReview_1';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_1] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e','20260923_014436_Cleanup_05_Manual_TechnicalReview_1','TODO','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF1924A1', '1226764', '101294', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026MM1359A1', '1249507', '10244', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026MM1359A2', '1249508', '10244', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026MM1359A3', '1249509', '10244', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF3055A1', '1163834', '105600', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF3055A2', '1163835', '105600', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF3055A4', '1163836', '105600', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2023CF227A1', '1170135', '105600', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026MM648A1', '1242878', '108409', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026MM648A2', '1242879', '108409', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF1317A1', '1245100', '115653', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026MM2159A1', '1253087', '117750', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF2192A1', '1228295', '119759', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF3223A1', '1234779', '119759', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2661A1', '1141964', '121333', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2013CF2966A2', '879690', '121339', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF3098A2', '1144665', '122031', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF3103A2', '1144678', '122031', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF940A2', '1152084', '122031', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF798A1', '1241644', '123842', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF809A1', '1241684', '125101', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF809A2', '1241685', '125101', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2012CF3095A1', '832095', '129452', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2012CF3095A3', '838014', '129452', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2012CF3095A4', '838015', '129452', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2012CF3395A1', '835996', '129452', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2012CF3395A2', '835997', '129452', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2004CF1646A1', '520289', '130251', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025MM1658A1', '1230280', '132884', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF1314A1', '1153966', '136493', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF1926A2', '1157135', '136493', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF1926A3', '1157136', '136493', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2013CF2638A1', '875186', '137716', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2013CF2638A2', '875187', '137716', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2020CF2469A2', '1113715', '137716', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026MM1624A1', '1251935', '138047', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF940A1', '1242987', '139283', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF940A2', '1242988', '139283', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2020CF1244A1', '1105507', '143311', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2020CF1244A3', '1107822', '143311', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2020CF1569A1', '1107296', '143311', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2020CF1569A2', '1107297', '143311', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF3457A1', '1166428', '143311', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF791A1', '1241597', '145529', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF791A2', '1241598', '145529', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2015CF1345A1', '945202', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2020CF2868A1', '1118175', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2020CF963A1', '1103513', '145539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF2261A1', '1251926', '148409', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF2980A1', '1233312', '149029', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF2980A2', '1233315', '149029', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF2980A3', '1233314', '149029', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF28A1', '1146927', '149030', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF1491A1', '1246099', '149304', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF1491A2', '1246100', '149304', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF3209A1', '1164671', '150898', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF1360A1', '1131870', '151194', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF1360A2', '1131869', '151194', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CT2007A1', '1235175', '151645', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A1', '1143805', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A2', '1143806', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A3', '1143807', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A4', '1143811', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A5', '1143808', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A6', '1143809', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A7', '1143812', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2021CF2971A8', '1148495', '153741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF1961A2', '1249746', '156527', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF1961A3', '1249748', '156527', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CF1961A4', '1251924', '156527', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF681A1', '1150519', '158759', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A1', '1213359', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A13', '1213364', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A14', '1213365', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A2', '1213360', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A3', '1213362', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A4', '1213363', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A5', '1213374', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF3410A6', '1213361', '159800', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CT512A1', '1243836', '160317', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF20A1', '1214796', '160374', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF20A2', '1214795', '160374', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026CT502A1', '1243735', '161047', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2019CF3697A1', '1092240', '161384', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2019CF3698A1', '1092242', '161384', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2019CF3698A2', '1095256', '161384', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026HH225A1', '1241024', '161384', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF2519A1', '1207498', '161858', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF2519A2', '1207499', '161858', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF2164A1', '1158379', '162754', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF2164A2', '1158381', '162754', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF2164A3', '1158382', '162754', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF2164A4', '1158383', '162754', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2022CF2164A5', '1158380', '162754', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026HH627A1', '1248635', '162754', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF2855A1', '1232567', '162864', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2025CF2855A2', '1232568', '162864', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2024CF1643A1', '1202190', '163298', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026HH1996A1', '1253077', '163298', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('17a262d2-60a9-41d8-9fe8-4fa87264283e', '2026HH1996A2', '1253078', '163298', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_1] started'
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocation::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1226764 CJIS_CASE_NUMBER 2025CF1924A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1226764';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1226764',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226764
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226764
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1226764',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226764'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1226764';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226764';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1226764',
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
AND CHARGE_ID = 1226764
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1226764', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1226764',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1226764',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1226764';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1226764',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1226764';
        
END;
/

/***********************************************************
***** CHARGE 1249507 CJIS_CASE_NUMBER 2026MM1359A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1249507';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249507',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249507
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249507
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249507',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249507'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1249507';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249507';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249507',
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
AND CHARGE_ID = 1249507
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249507', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249507',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249507',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1249507';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1249507',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1249507';
        
END;
/

/***********************************************************
***** CHARGE 1249508 CJIS_CASE_NUMBER 2026MM1359A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1249508';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249508',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249508
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249508
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249508',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249508'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1249508';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249508';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249508',
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
AND CHARGE_ID = 1249508
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249508', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249508',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249508',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1249508';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1249508',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1249508';
        
END;
/

/***********************************************************
***** CHARGE 1249509 CJIS_CASE_NUMBER 2026MM1359A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1249509';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249509',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249509
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249509
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249509',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249509'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1249509';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249509';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249509',
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
AND CHARGE_ID = 1249509
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249509', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249509',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249509',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1249509';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1249509',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1249509';
        
END;
/

/***********************************************************
***** CHARGE 1163834 CJIS_CASE_NUMBER 2022CF3055A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1163834';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1163834',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163834
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163834
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163834',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163834'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1163834';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163834';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163834',
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
AND CHARGE_ID = 1163834
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1163834', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163834',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1163834',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1163834';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1163834',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1163834';
        
END;
/

/***********************************************************
***** CHARGE 1163835 CJIS_CASE_NUMBER 2022CF3055A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1163835';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1163835',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163835
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163835
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163835',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163835'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1163835';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163835';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163835',
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
AND CHARGE_ID = 1163835
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1163835', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163835',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1163835',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1163835';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1163835',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1163835';
        
END;
/

/***********************************************************
***** CHARGE 1163836 CJIS_CASE_NUMBER 2022CF3055A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1163836';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1163836',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163836
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163836
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163836',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163836'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1163836';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163836';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163836',
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
AND CHARGE_ID = 1163836
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1163836', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1163836',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1163836',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1163836';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1163836',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1163836';
        
END;
/

/***********************************************************
***** CHARGE 1170135 CJIS_CASE_NUMBER 2023CF227A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1170135';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1170135',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170135
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170135
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1170135',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170135'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1170135';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170135';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1170135',
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
AND CHARGE_ID = 1170135
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170135', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1170135',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1170135',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1170135';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1170135',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1170135';
        
END;
/

/***********************************************************
***** CHARGE 1242878 CJIS_CASE_NUMBER 2026MM648A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1242878';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242878',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242878
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242878
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242878',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242878'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1242878';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242878';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242878',
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
AND CHARGE_ID = 1242878
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242878', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242878',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242878',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1242878';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1242878',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1242878';
        
END;
/

/***********************************************************
***** CHARGE 1242879 CJIS_CASE_NUMBER 2026MM648A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1242879';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242879',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242879
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242879
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242879',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242879'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1242879';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242879';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242879',
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
AND CHARGE_ID = 1242879
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242879', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242879',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242879',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1242879';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1242879',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1242879';
        
END;
/

/***********************************************************
***** CHARGE 1245100 CJIS_CASE_NUMBER 2026CF1317A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1245100';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1245100',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245100
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245100
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1245100',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245100'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1245100';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245100';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1245100',
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
AND CHARGE_ID = 1245100
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245100', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1245100',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1245100',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1245100';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1245100',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1245100';
        
END;
/

/***********************************************************
***** CHARGE 1253087 CJIS_CASE_NUMBER 2026MM2159A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1253087';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1253087',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1253087
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1253087
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253087',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1253087'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1253087';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1253087';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253087',
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
AND CHARGE_ID = 1253087
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1253087', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253087',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1253087',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1253087';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1253087',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1253087';
        
END;
/

/***********************************************************
***** CHARGE 1228295 CJIS_CASE_NUMBER 2025CF2192A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1228295';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1228295',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228295
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228295
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1228295',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228295'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1228295';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228295';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1228295',
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
AND CHARGE_ID = 1228295
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228295', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1228295',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1228295',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1228295';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1228295',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1228295';
        
END;
/

/***********************************************************
***** CHARGE 1234779 CJIS_CASE_NUMBER 2025CF3223A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1234779';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1234779',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234779
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234779
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1234779',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234779'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1234779';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234779';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1234779',
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
AND CHARGE_ID = 1234779
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234779', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1234779',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1234779',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1234779';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1234779',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1234779';
        
END;
/

/***********************************************************
***** CHARGE 1141964 CJIS_CASE_NUMBER 2021CF2661A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1141964';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1141964',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1141964
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1141964
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1141964',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1141964'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1141964';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1141964';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1141964',
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
AND CHARGE_ID = 1141964
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1141964', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1141964',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1141964',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1141964';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1141964',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1141964';
        
END;
/

/***********************************************************
***** CHARGE 879690 CJIS_CASE_NUMBER 2013CF2966A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '879690';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '879690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 879690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 879690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '879690',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '879690'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '879690';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '879690';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '879690',
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
AND CHARGE_ID = 879690
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '879690', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '879690',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '879690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '879690';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '879690',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '879690';
        
END;
/

/***********************************************************
***** CHARGE 1144665 CJIS_CASE_NUMBER 2021CF3098A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1144665';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1144665',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1144665
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1144665
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1144665',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144665'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1144665';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144665';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1144665',
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
AND CHARGE_ID = 1144665
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1144665', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1144665',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1144665',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1144665';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1144665',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1144665';
        
END;
/

/***********************************************************
***** CHARGE 1144678 CJIS_CASE_NUMBER 2021CF3103A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1144678';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1144678',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1144678
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1144678
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1144678',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144678'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1144678';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1144678';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1144678',
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
AND CHARGE_ID = 1144678
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1144678', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1144678',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1144678',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1144678';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1144678',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1144678';
        
END;
/

/***********************************************************
***** CHARGE 1152084 CJIS_CASE_NUMBER 2022CF940A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1152084';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1152084',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1152084
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1152084
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1152084',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1152084'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1152084';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1152084';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1152084',
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
AND CHARGE_ID = 1152084
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1152084', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1152084',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1152084',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1152084';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1152084',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1152084';
        
END;
/

/***********************************************************
***** CHARGE 1241644 CJIS_CASE_NUMBER 2026CF798A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1241644';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241644',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241644
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241644
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241644',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241644'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1241644';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241644';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241644',
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
AND CHARGE_ID = 1241644
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241644', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241644',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241644',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1241644';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1241644',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1241644';
        
END;
/

/***********************************************************
***** CHARGE 1241684 CJIS_CASE_NUMBER 2026CF809A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1241684';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241684',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241684
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241684
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241684',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241684'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1241684';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241684';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241684',
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
AND CHARGE_ID = 1241684
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241684', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241684',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241684',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1241684';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1241684',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1241684';
        
END;
/

/***********************************************************
***** CHARGE 1241685 CJIS_CASE_NUMBER 2026CF809A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1241685';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241685',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241685
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241685
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241685',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241685'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1241685';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241685';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241685',
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
AND CHARGE_ID = 1241685
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241685', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241685',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241685',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1241685';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1241685',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1241685';
        
END;
/

/***********************************************************
***** CHARGE 832095 CJIS_CASE_NUMBER 2012CF3095A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '832095';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '832095',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 832095
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 832095
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '832095',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '832095'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '832095';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '832095';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '832095',
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
AND CHARGE_ID = 832095
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '832095', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '832095',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '832095',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '832095';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '832095',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '832095';
        
END;
/

/***********************************************************
***** CHARGE 838014 CJIS_CASE_NUMBER 2012CF3095A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '838014';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '838014',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 838014
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 838014
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '838014',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '838014'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '838014';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '838014';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '838014',
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
AND CHARGE_ID = 838014
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '838014', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '838014',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '838014',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '838014';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '838014',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '838014';
        
END;
/

/***********************************************************
***** CHARGE 838015 CJIS_CASE_NUMBER 2012CF3095A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '838015';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '838015',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 838015
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 838015
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '838015',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '838015'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '838015';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '838015';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '838015',
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
AND CHARGE_ID = 838015
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '838015', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '838015',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '838015',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '838015';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '838015',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '838015';
        
END;
/

/***********************************************************
***** CHARGE 835996 CJIS_CASE_NUMBER 2012CF3395A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '835996';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '835996',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 835996
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 835996
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '835996',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '835996'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '835996';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '835996';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '835996',
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
AND CHARGE_ID = 835996
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '835996', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '835996',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '835996',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '835996';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '835996',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '835996';
        
END;
/

/***********************************************************
***** CHARGE 835997 CJIS_CASE_NUMBER 2012CF3395A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '835997';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '835997',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 835997
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 835997
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '835997',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '835997'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '835997';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '835997';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '835997',
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
AND CHARGE_ID = 835997
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '835997', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '835997',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '835997',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '835997';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '835997',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '835997';
        
END;
/

/***********************************************************
***** CHARGE 520289 CJIS_CASE_NUMBER 2004CF1646A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '520289';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '520289',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 520289
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 520289
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '520289',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '520289'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '520289';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '520289';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '520289',
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
AND CHARGE_ID = 520289
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '520289', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '520289',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '520289',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '520289';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '520289',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '520289';
        
END;
/

/***********************************************************
***** CHARGE 1230280 CJIS_CASE_NUMBER 2025MM1658A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1230280';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1230280',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230280
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230280
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1230280',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230280'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1230280';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230280';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1230280',
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
AND CHARGE_ID = 1230280
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230280', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1230280',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1230280',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1230280';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1230280',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1230280';
        
END;
/

/***********************************************************
***** CHARGE 1153966 CJIS_CASE_NUMBER 2022CF1314A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1153966';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1153966',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1153966
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1153966
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1153966',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1153966'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1153966';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1153966';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1153966',
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
AND CHARGE_ID = 1153966
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1153966', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1153966',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1153966',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1153966';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1153966',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1153966';
        
END;
/

/***********************************************************
***** CHARGE 1157135 CJIS_CASE_NUMBER 2022CF1926A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1157135';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1157135',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157135
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157135
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1157135',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157135'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1157135';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157135';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1157135',
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
AND CHARGE_ID = 1157135
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1157135', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1157135',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1157135',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1157135';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1157135',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1157135';
        
END;
/

/***********************************************************
***** CHARGE 1157136 CJIS_CASE_NUMBER 2022CF1926A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1157136';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1157136',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157136
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1157136
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1157136',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157136'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1157136';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1157136';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1157136',
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
AND CHARGE_ID = 1157136
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1157136', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1157136',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1157136',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1157136';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1157136',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1157136';
        
END;
/

/***********************************************************
***** CHARGE 875186 CJIS_CASE_NUMBER 2013CF2638A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '875186';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '875186',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 875186
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 875186
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '875186',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '875186'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '875186';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '875186';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '875186',
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
AND CHARGE_ID = 875186
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '875186', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '875186',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '875186',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '875186';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '875186',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '875186';
        
END;
/

/***********************************************************
***** CHARGE 875187 CJIS_CASE_NUMBER 2013CF2638A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '875187';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '875187',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 875187
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 875187
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '875187',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '875187'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '875187';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '875187';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '875187',
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
AND CHARGE_ID = 875187
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '875187', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '875187',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '875187',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '875187';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '875187',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '875187';
        
END;
/

/***********************************************************
***** CHARGE 1113715 CJIS_CASE_NUMBER 2020CF2469A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1113715';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1113715',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1113715
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1113715
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1113715',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1113715'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1113715';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1113715';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1113715',
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
AND CHARGE_ID = 1113715
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1113715', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1113715',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1113715',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1113715';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1113715',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1113715';
        
END;
/

/***********************************************************
***** CHARGE 1251935 CJIS_CASE_NUMBER 2026MM1624A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1251935';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1251935',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251935
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251935
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251935',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251935'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'W',
    LOCATION = 'WARR'
WHERE CHARGE_ID = '1251935';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251935';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251935',
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
AND CHARGE_ID = 1251935
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251935', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251935',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1251935',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1251935';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1251935',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1251935';
        
END;
/

/***********************************************************
***** CHARGE 1242987 CJIS_CASE_NUMBER 2026CF940A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1242987';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242987',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242987
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242987
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242987',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242987'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1242987';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242987';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242987',
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
AND CHARGE_ID = 1242987
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242987', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242987',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242987',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1242987';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1242987',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1242987';
        
END;
/

/***********************************************************
***** CHARGE 1242988 CJIS_CASE_NUMBER 2026CF940A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1242988';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242988',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242988
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242988
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242988',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242988'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1242988';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242988';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242988',
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
AND CHARGE_ID = 1242988
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242988', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1242988',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1242988',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1242988';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1242988',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1242988';
        
END;
/

/***********************************************************
***** CHARGE 1105507 CJIS_CASE_NUMBER 2020CF1244A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1105507';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1105507',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1105507
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1105507
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1105507',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1105507'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1105507';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1105507';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1105507',
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
AND CHARGE_ID = 1105507
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1105507', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1105507',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1105507',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1105507';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1105507',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1105507';
        
END;
/

/***********************************************************
***** CHARGE 1107822 CJIS_CASE_NUMBER 2020CF1244A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1107822';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1107822',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1107822
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1107822
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107822',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1107822'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1107822';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1107822';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107822',
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
AND CHARGE_ID = 1107822
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1107822', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107822',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1107822',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1107822';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1107822',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1107822';
        
END;
/

/***********************************************************
***** CHARGE 1107296 CJIS_CASE_NUMBER 2020CF1569A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1107296';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1107296',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1107296
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1107296
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107296',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1107296'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1107296';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1107296';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107296',
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
AND CHARGE_ID = 1107296
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1107296', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107296',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1107296',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1107296';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1107296',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1107296';
        
END;
/

/***********************************************************
***** CHARGE 1107297 CJIS_CASE_NUMBER 2020CF1569A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1107297';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1107297',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1107297
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1107297
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107297',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1107297'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1107297';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1107297';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107297',
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
AND CHARGE_ID = 1107297
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1107297', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1107297',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1107297',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1107297';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1107297',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1107297';
        
END;
/

/***********************************************************
***** CHARGE 1166428 CJIS_CASE_NUMBER 2022CF3457A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1166428';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1166428',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1166428
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1166428
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1166428',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1166428'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1166428';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1166428';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1166428',
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
AND CHARGE_ID = 1166428
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1166428', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1166428',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1166428',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1166428';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1166428',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1166428';
        
END;
/

/***********************************************************
***** CHARGE 1241597 CJIS_CASE_NUMBER 2026CF791A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1241597';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241597',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241597
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241597
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241597',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241597'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1241597';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241597';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241597',
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
AND CHARGE_ID = 1241597
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241597', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241597',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241597',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1241597';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1241597',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1241597';
        
END;
/

/***********************************************************
***** CHARGE 1241598 CJIS_CASE_NUMBER 2026CF791A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1241598';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241598',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241598
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241598
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241598',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241598'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1241598';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241598';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241598',
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
AND CHARGE_ID = 1241598
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241598', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241598',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241598',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1241598';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1241598',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1241598';
        
END;
/

/***********************************************************
***** CHARGE 945202 CJIS_CASE_NUMBER 2015CF1345A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '945202';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '945202',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 945202
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 945202
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '945202',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '945202'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '945202';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '945202';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '945202',
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
AND CHARGE_ID = 945202
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '945202', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '945202',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '945202',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '945202';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '945202',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '945202';
        
END;
/

/***********************************************************
***** CHARGE 1118175 CJIS_CASE_NUMBER 2020CF2868A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1118175';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1118175',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1118175
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1118175
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1118175',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1118175'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1118175';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1118175';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1118175',
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
AND CHARGE_ID = 1118175
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1118175', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1118175',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1118175',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1118175';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1118175',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1118175';
        
END;
/

/***********************************************************
***** CHARGE 1103513 CJIS_CASE_NUMBER 2020CF963A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1103513';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1103513',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1103513
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1103513
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1103513',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103513'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1103513';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1103513';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1103513',
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
AND CHARGE_ID = 1103513
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1103513', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1103513',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1103513',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1103513';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1103513',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1103513';
        
END;
/

/***********************************************************
***** CHARGE 1251926 CJIS_CASE_NUMBER 2026CF2261A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1251926';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1251926',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251926
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251926
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251926',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251926'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1251926';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251926';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251926',
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
AND CHARGE_ID = 1251926
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251926', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251926',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1251926',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1251926';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1251926',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1251926';
        
END;
/

/***********************************************************
***** CHARGE 1233312 CJIS_CASE_NUMBER 2025CF2980A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1233312';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1233312',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233312
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233312
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233312',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233312'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1233312';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233312';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233312',
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
AND CHARGE_ID = 1233312
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233312', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233312',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1233312',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1233312';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1233312',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1233312';
        
END;
/

/***********************************************************
***** CHARGE 1233315 CJIS_CASE_NUMBER 2025CF2980A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1233315';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1233315',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233315
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233315
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233315',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233315'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1233315';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233315';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233315',
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
AND CHARGE_ID = 1233315
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233315', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233315',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1233315',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1233315';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1233315',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1233315';
        
END;
/

/***********************************************************
***** CHARGE 1233314 CJIS_CASE_NUMBER 2025CF2980A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1233314';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1233314',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233314
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233314
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233314',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233314'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1233314';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233314';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233314',
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
AND CHARGE_ID = 1233314
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233314', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1233314',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1233314',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1233314';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1233314',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1233314';
        
END;
/

/***********************************************************
***** CHARGE 1146927 CJIS_CASE_NUMBER 2022CF28A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1146927';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1146927',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1146927
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1146927
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1146927',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1146927'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'W',
    LOCATION = 'WARR'
WHERE CHARGE_ID = '1146927';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1146927';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1146927',
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
AND CHARGE_ID = 1146927
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1146927', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1146927',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1146927',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1146927';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1146927',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1146927';
        
END;
/

/***********************************************************
***** CHARGE 1246099 CJIS_CASE_NUMBER 2026CF1491A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1246099';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1246099',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246099
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246099
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1246099',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246099'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246099';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246099';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1246099',
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
AND CHARGE_ID = 1246099
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246099', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1246099',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1246099',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1246099';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1246099',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1246099';
        
END;
/

/***********************************************************
***** CHARGE 1246100 CJIS_CASE_NUMBER 2026CF1491A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1246100';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1246100',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246100
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246100
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1246100',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246100'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246100';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246100';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1246100',
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
AND CHARGE_ID = 1246100
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246100', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1246100',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1246100',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1246100';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1246100',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1246100';
        
END;
/

/***********************************************************
***** CHARGE 1164671 CJIS_CASE_NUMBER 2022CF3209A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1164671';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1164671',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1164671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1164671
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1164671',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1164671'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1164671';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1164671';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1164671',
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
AND CHARGE_ID = 1164671
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1164671', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1164671',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1164671',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1164671';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1164671',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1164671';
        
END;
/

/***********************************************************
***** CHARGE 1131870 CJIS_CASE_NUMBER 2021CF1360A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1131870';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1131870',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1131870
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1131870
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1131870',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1131870'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1131870';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1131870';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1131870',
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
AND CHARGE_ID = 1131870
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1131870', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1131870',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1131870',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1131870';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1131870',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1131870';
        
END;
/

/***********************************************************
***** CHARGE 1131869 CJIS_CASE_NUMBER 2021CF1360A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1131869';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1131869',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1131869
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1131869
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1131869',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1131869'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1131869';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1131869';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1131869',
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
AND CHARGE_ID = 1131869
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1131869', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1131869',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1131869',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1131869';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1131869',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1131869';
        
END;
/

/***********************************************************
***** CHARGE 1235175 CJIS_CASE_NUMBER 2025CT2007A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1235175';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1235175',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235175
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235175
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1235175',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235175'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'C',
    LOCATION = 'CAP.'
WHERE CHARGE_ID = '1235175';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235175';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1235175',
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
AND CHARGE_ID = 1235175
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235175', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1235175',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1235175',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1235175';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1235175',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1235175';
        
END;
/

/***********************************************************
***** CHARGE 1143805 CJIS_CASE_NUMBER 2021CF2971A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1143805';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143805',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143805
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143805
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143805',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143805'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1143805';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143805';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143805',
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
AND CHARGE_ID = 1143805
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143805', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143805',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143805',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1143805';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1143805',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1143805';
        
END;
/

/***********************************************************
***** CHARGE 1143806 CJIS_CASE_NUMBER 2021CF2971A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1143806';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143806',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143806
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143806
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143806',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143806'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1143806';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143806';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143806',
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
AND CHARGE_ID = 1143806
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143806', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143806',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143806',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1143806';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1143806',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1143806';
        
END;
/

/***********************************************************
***** CHARGE 1143807 CJIS_CASE_NUMBER 2021CF2971A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1143807';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143807',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143807
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143807
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143807',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143807'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1143807';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143807';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143807',
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
AND CHARGE_ID = 1143807
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143807', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143807',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143807',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1143807';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1143807',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1143807';
        
END;
/

/***********************************************************
***** CHARGE 1143811 CJIS_CASE_NUMBER 2021CF2971A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1143811';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143811',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143811
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143811
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143811',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143811'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1143811';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143811';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143811',
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
AND CHARGE_ID = 1143811
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143811', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143811',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143811',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1143811';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1143811',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1143811';
        
END;
/

/***********************************************************
***** CHARGE 1143808 CJIS_CASE_NUMBER 2021CF2971A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1143808';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143808',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143808
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143808
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143808',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143808'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1143808';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143808';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143808',
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
AND CHARGE_ID = 1143808
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143808', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143808',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143808',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1143808';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1143808',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1143808';
        
END;
/

/***********************************************************
***** CHARGE 1143809 CJIS_CASE_NUMBER 2021CF2971A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1143809';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143809',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143809
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143809
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143809',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143809'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1143809';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143809';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143809',
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
AND CHARGE_ID = 1143809
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143809', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143809',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143809',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1143809';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1143809',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1143809';
        
END;
/

/***********************************************************
***** CHARGE 1143812 CJIS_CASE_NUMBER 2021CF2971A7
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1143812';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143812',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143812
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143812
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143812',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143812'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1143812';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143812';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143812',
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
AND CHARGE_ID = 1143812
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143812', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1143812',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1143812',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1143812';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1143812',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1143812';
        
END;
/

/***********************************************************
***** CHARGE 1148495 CJIS_CASE_NUMBER 2021CF2971A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1148495';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1148495',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1148495
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1148495
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1148495',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1148495'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1148495';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1148495';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1148495',
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
AND CHARGE_ID = 1148495
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1148495', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1148495',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1148495',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1148495';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1148495',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1148495';
        
END;
/

/***********************************************************
***** CHARGE 1249746 CJIS_CASE_NUMBER 2026CF1961A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1249746';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249746',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249746
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249746
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249746',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249746'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1249746';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249746';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249746',
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
AND CHARGE_ID = 1249746
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249746', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249746',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249746',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1249746';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1249746',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1249746';
        
END;
/

/***********************************************************
***** CHARGE 1249748 CJIS_CASE_NUMBER 2026CF1961A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1249748';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249748',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249748
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249748
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249748',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249748'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1249748';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249748';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249748',
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
AND CHARGE_ID = 1249748
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249748', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1249748',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1249748',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1249748';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1249748',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1249748';
        
END;
/

/***********************************************************
***** CHARGE 1251924 CJIS_CASE_NUMBER 2026CF1961A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1251924';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1251924',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251924
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251924
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251924',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251924'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1251924';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251924';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251924',
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
AND CHARGE_ID = 1251924
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251924', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1251924',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1251924',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1251924';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1251924',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1251924';
        
END;
/

/***********************************************************
***** CHARGE 1150519 CJIS_CASE_NUMBER 2022CF681A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1150519';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1150519',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1150519
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1150519
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1150519',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1150519'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1150519';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1150519';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1150519',
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
AND CHARGE_ID = 1150519
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1150519', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1150519',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1150519',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1150519';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1150519',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1150519';
        
END;
/

/***********************************************************
***** CHARGE 1213359 CJIS_CASE_NUMBER 2024CF3410A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213359';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213359',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213359
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213359
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213359',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213359'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213359';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213359';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213359',
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
AND CHARGE_ID = 1213359
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213359', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213359',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213359',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213359';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213359',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213359';
        
END;
/

/***********************************************************
***** CHARGE 1213364 CJIS_CASE_NUMBER 2024CF3410A13
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213364';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213364',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213364
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213364
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213364',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213364'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1213364';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213364';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213364',
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
AND CHARGE_ID = 1213364
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213364', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213364',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213364',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213364';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213364',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213364';
        
END;
/

/***********************************************************
***** CHARGE 1213365 CJIS_CASE_NUMBER 2024CF3410A14
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213365';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213365',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213365
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213365
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213365',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213365'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1213365';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213365';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213365',
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
AND CHARGE_ID = 1213365
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213365', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213365',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213365',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213365';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213365',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213365';
        
END;
/

/***********************************************************
***** CHARGE 1213360 CJIS_CASE_NUMBER 2024CF3410A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213360';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213360',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213360
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213360
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213360',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213360'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213360';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213360';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213360',
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
AND CHARGE_ID = 1213360
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213360', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213360',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213360',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213360';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213360',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213360';
        
END;
/

/***********************************************************
***** CHARGE 1213362 CJIS_CASE_NUMBER 2024CF3410A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213362';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213362',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213362
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213362
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213362',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213362'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1213362';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213362';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213362',
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
AND CHARGE_ID = 1213362
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213362', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213362',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213362',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213362';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213362',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213362';
        
END;
/

/***********************************************************
***** CHARGE 1213363 CJIS_CASE_NUMBER 2024CF3410A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213363';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213363',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213363
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213363
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213363',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213363'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1213363';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213363';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213363',
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
AND CHARGE_ID = 1213363
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213363', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213363',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213363',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213363';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213363',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213363';
        
END;
/

/***********************************************************
***** CHARGE 1213374 CJIS_CASE_NUMBER 2024CF3410A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213374';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213374',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213374
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213374
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213374',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213374'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1213374';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213374';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213374',
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
AND CHARGE_ID = 1213374
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213374', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213374',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213374',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213374';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213374',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213374';
        
END;
/

/***********************************************************
***** CHARGE 1213361 CJIS_CASE_NUMBER 2024CF3410A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1213361';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213361',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213361
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213361
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213361',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213361'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1213361';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213361';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213361',
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
AND CHARGE_ID = 1213361
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213361', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1213361',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1213361',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1213361';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1213361',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1213361';
        
END;
/

/***********************************************************
***** CHARGE 1243836 CJIS_CASE_NUMBER 2026CT512A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1243836';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1243836',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243836
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243836
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1243836',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243836'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1243836';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243836';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1243836',
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
AND CHARGE_ID = 1243836
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243836', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1243836',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1243836',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1243836';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1243836',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1243836';
        
END;
/

/***********************************************************
***** CHARGE 1214796 CJIS_CASE_NUMBER 2025CF20A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1214796';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1214796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1214796',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214796'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1214796';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214796';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1214796',
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
AND CHARGE_ID = 1214796
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1214796', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1214796',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1214796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1214796';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1214796',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1214796';
        
END;
/

/***********************************************************
***** CHARGE 1214795 CJIS_CASE_NUMBER 2025CF20A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1214795';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1214795',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214795
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214795
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1214795',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214795'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1214795';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214795';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1214795',
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
AND CHARGE_ID = 1214795
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1214795', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1214795',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1214795',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1214795';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1214795',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1214795';
        
END;
/

/***********************************************************
***** CHARGE 1243735 CJIS_CASE_NUMBER 2026CT502A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1243735';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1243735',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243735
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243735
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1243735',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243735'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1243735';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243735';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1243735',
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
AND CHARGE_ID = 1243735
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243735', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1243735',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1243735',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1243735';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1243735',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1243735';
        
END;
/

/***********************************************************
***** CHARGE 1092240 CJIS_CASE_NUMBER 2019CF3697A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1092240';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1092240',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1092240
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1092240
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1092240',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1092240'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1092240';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1092240';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1092240',
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
AND CHARGE_ID = 1092240
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1092240', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1092240',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1092240',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1092240';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1092240',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1092240';
        
END;
/

/***********************************************************
***** CHARGE 1092242 CJIS_CASE_NUMBER 2019CF3698A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1092242';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1092242',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1092242
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1092242
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1092242',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1092242'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1092242';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1092242';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1092242',
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
AND CHARGE_ID = 1092242
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1092242', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1092242',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1092242',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1092242';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1092242',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1092242';
        
END;
/

/***********************************************************
***** CHARGE 1095256 CJIS_CASE_NUMBER 2019CF3698A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1095256';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1095256',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095256
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095256
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1095256',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095256'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '1095256';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095256';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1095256',
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
AND CHARGE_ID = 1095256
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1095256', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1095256',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1095256',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1095256';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1095256',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1095256';
        
END;
/

/***********************************************************
***** CHARGE 1241024 CJIS_CASE_NUMBER 2026HH225A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1241024';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241024',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241024
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241024
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241024',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241024'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1241024';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241024';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241024',
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
AND CHARGE_ID = 1241024
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241024', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1241024',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1241024',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1241024';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1241024',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1241024';
        
END;
/

/***********************************************************
***** CHARGE 1207498 CJIS_CASE_NUMBER 2024CF2519A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1207498';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1207498',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207498
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207498
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1207498',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207498'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1207498';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207498';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1207498',
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
AND CHARGE_ID = 1207498
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1207498', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1207498',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1207498',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1207498';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1207498',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1207498';
        
END;
/

/***********************************************************
***** CHARGE 1207499 CJIS_CASE_NUMBER 2024CF2519A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1207499';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1207499',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207499
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207499
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1207499',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207499'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1207499';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207499';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1207499',
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
AND CHARGE_ID = 1207499
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1207499', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1207499',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1207499',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1207499';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1207499',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1207499';
        
END;
/

/***********************************************************
***** CHARGE 1158379 CJIS_CASE_NUMBER 2022CF2164A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1158379';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158379',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158379
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158379
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158379',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158379'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1158379';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158379';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158379',
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
AND CHARGE_ID = 1158379
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1158379', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158379',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158379',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1158379';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1158379',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1158379';
        
END;
/

/***********************************************************
***** CHARGE 1158381 CJIS_CASE_NUMBER 2022CF2164A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1158381';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158381',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158381
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158381
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158381',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158381'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1158381';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158381';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158381',
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
AND CHARGE_ID = 1158381
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1158381', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158381',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158381',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1158381';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1158381',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1158381';
        
END;
/

/***********************************************************
***** CHARGE 1158382 CJIS_CASE_NUMBER 2022CF2164A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1158382';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158382',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158382
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158382
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158382',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158382'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1158382';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158382';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158382',
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
AND CHARGE_ID = 1158382
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1158382', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158382',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158382',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1158382';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1158382',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1158382';
        
END;
/

/***********************************************************
***** CHARGE 1158383 CJIS_CASE_NUMBER 2022CF2164A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1158383';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158383',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158383
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158383
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158383',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158383'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1158383';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158383';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158383',
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
AND CHARGE_ID = 1158383
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1158383', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158383',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158383',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1158383';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1158383',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1158383';
        
END;
/

/***********************************************************
***** CHARGE 1158380 CJIS_CASE_NUMBER 2022CF2164A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1158380';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158380',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158380
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1158380
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158380',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158380'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1158380';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1158380';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158380',
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
AND CHARGE_ID = 1158380
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1158380', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1158380',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1158380',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1158380';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1158380',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1158380';
        
END;
/

/***********************************************************
***** CHARGE 1248635 CJIS_CASE_NUMBER 2026HH627A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1248635';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1248635',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248635
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248635
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1248635',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248635'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1248635';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248635';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1248635',
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
AND CHARGE_ID = 1248635
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248635', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1248635',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1248635',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1248635';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1248635',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1248635';
        
END;
/

/***********************************************************
***** CHARGE 1232567 CJIS_CASE_NUMBER 2025CF2855A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1232567';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1232567',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232567
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232567
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1232567',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232567'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1232567';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232567';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1232567',
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
AND CHARGE_ID = 1232567
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232567', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1232567',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1232567',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1232567';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1232567',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1232567';
        
END;
/

/***********************************************************
***** CHARGE 1232568 CJIS_CASE_NUMBER 2025CF2855A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1232568';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1232568',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232568
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232568
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1232568',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232568'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1232568';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232568';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1232568',
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
AND CHARGE_ID = 1232568
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232568', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1232568',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1232568',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1232568';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1232568',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1232568';
        
END;
/

/***********************************************************
***** CHARGE 1202190 CJIS_CASE_NUMBER 2024CF1643A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1202190';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1202190',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202190
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202190
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1202190',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202190'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1202190';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202190';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1202190',
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
AND CHARGE_ID = 1202190
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1202190', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1202190',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1202190',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1202190';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1202190',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1202190';
        
END;
/

/***********************************************************
***** CHARGE 1253077 CJIS_CASE_NUMBER 2026HH1996A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1253077';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1253077',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1253077
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1253077
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253077',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1253077'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1253077';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1253077';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253077',
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
AND CHARGE_ID = 1253077
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1253077', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253077',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1253077',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1253077';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1253077',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1253077';
        
END;
/

/***********************************************************
***** CHARGE 1253078 CJIS_CASE_NUMBER 2026HH1996A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
       AND charge_id = '1253078';

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1253078',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1253078
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1253078
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253078',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1253078'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1253078';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1253078';


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253078',
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
AND CHARGE_ID = 1253078
AND cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1253078', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '17a262d2-60a9-41d8-9fe8-4fa87264283e' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id       => '1253078',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
    p_charge_id    => '1253078',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
            AND charge_id = '1253078';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
            p_charge_id    => '1253078',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '17a262d2-60a9-41d8-9fe8-4fa87264283e'
        AND charge_id = '1253078';
        
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='CHARGES_PROCESSED'
    WHERE cleanup_id=CLEANUP_ID;
    
    JISREM.LOG
    (
        p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => '17a262d2-60a9-41d8-9fe8-4fa87264283e',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

