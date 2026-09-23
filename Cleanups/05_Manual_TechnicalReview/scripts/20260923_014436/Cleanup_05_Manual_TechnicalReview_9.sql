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
    WHERE cleanup_name='20260923_014436_Cleanup_05_Manual_TechnicalReview_9';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_9] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357','20260923_014436_Cleanup_05_Manual_TechnicalReview_9','TODO','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2159A5', '1251261', '282273', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2159A6', '1251262', '282273', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2159A7', '1251263', '282273', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2159A8', '1251264', '282273', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2159A9', '1251265', '282273', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2195A1', '1251518', '282369', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026HH772A1', '1251527', '282369', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2212A2', '1251965', '282397', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2240A1', '1251784', '282415', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026MM1617A1', '1251813', '282418', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF904A1', '1220222', '28353', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF904A2', '1220224', '28353', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026MM1175A1', '1247337', '28353', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026MM1175A2', '1247338', '28353', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF2275A1', '1228870', '31578', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1616A1', '1246822', '3179', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1616A2', '1246823', '3179', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2023CF3290A1', '1190209', '33345', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2023CF3290A2', '1190208', '33345', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2023CF3290A3', '1190207', '33345', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2023CF3290A4', '1190205', '33345', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2023CF3290A5', '1190206', '33345', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1207A1', '1244532', '34704', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2004CF2290A1', '525242', '34790', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2004CF2797A1', '529054', '34790', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2004CF2797A2', '529056', '34790', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2004CF2797A3', '529057', '34790', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2007CF1615A1', '634875', '34790', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2007CF1615A2', '634874', '34790', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026MM1197A1', '1247583', '39916', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026MM1375A1', '1249616', '39916', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF2560A1', '1207723', '44431', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF716A1', '1218775', '45206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF716A2', '1219761', '45206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF716A3', '1218776', '45206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF716A4', '1219762', '45206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF716A5', '1219764', '45206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF716A6', '1219763', '45206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1909A1', '1249016', '45568', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1909A2', '1249017', '45568', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1909A3', '1249018', '45568', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF591A2', '1240345', '58858', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF3644A1', '1214623', '60714', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1501A1', '1246142', '61278', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1501A2', '1246144', '61278', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1501A3', '1246143', '61278', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1501A4', '1246145', '61278', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2005CF2912A1', '564385', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2005CF2912A2', '564386', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2005CF2912A3', '564387', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2009MM4057A1', '717112', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2010MM2391A1', '742309', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2010MM3880A1', '750892', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2010MM3880A2', '750893', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2012MM2202A1', '814350', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2013CF160A2', '849451', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2014MM1998A1', '917325', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2016MM910A2', '981832', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF1985A1', '1204115', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024MM81A1', '1193139', '61516', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2006CF4680A1', '616944', '61931', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2021CF2165A1', '1138587', '64646', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2017CF801A1', '1009736', '65121', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF1409A1', '1200791', '65577', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF1409A2', '1200792', '65577', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF1409A3', '1200794', '65577', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF1409A4', '1200795', '65577', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2024CF1409A5', '1200796', '65577', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2014CF3464A1', '930289', '68598', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026MM38A1', '1236904', '7728', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF702A1', '1218683', '81297', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF616A1', '1240521', '81297', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2260A1', '1251920', '85585', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2260A2', '1251921', '85585', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2260A3', '1251922', '85585', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF2260A4', '1251923', '85585', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF1453A1', '1223796', '89539', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2025CF297A1', '1216399', '89540', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2022CF909A1', '1151861', '9072', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2022CF909A2', '1155466', '9072', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1472A2', '1245984', '97496', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1472A3', '1245985', '97496', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF1472A4', '1245987', '97496', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CF936A1', '1242977', '98137', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CT916A1', '1248694', '99436', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('a2b01364-ee55-43dc-97f1-0d3f6c729357', '2026CT916A2', '1248695', '99436', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_9] started'
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[86] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocation::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1251261 CJIS_CASE_NUMBER 2026CF2159A5
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251261';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251261',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251261
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251261
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251261',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251261'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251261';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251261';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251261',
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
AND CHARGE_ID = 1251261
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251261', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251261',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251261',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251261';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251261',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251261';
        
END;
/

/***********************************************************
***** CHARGE 1251262 CJIS_CASE_NUMBER 2026CF2159A6
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251262';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251262',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251262
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251262
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251262',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251262'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251262';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251262';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251262',
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
AND CHARGE_ID = 1251262
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251262', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251262',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251262',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251262';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251262',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251262';
        
END;
/

/***********************************************************
***** CHARGE 1251263 CJIS_CASE_NUMBER 2026CF2159A7
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251263';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251263',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251263
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251263
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251263',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251263'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251263';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251263';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251263',
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
AND CHARGE_ID = 1251263
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251263', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251263',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251263',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251263';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251263',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251263';
        
END;
/

/***********************************************************
***** CHARGE 1251264 CJIS_CASE_NUMBER 2026CF2159A8
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251264';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251264',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251264
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251264
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251264',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251264'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251264';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251264';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251264',
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
AND CHARGE_ID = 1251264
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251264', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251264',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251264',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251264';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251264',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251264';
        
END;
/

/***********************************************************
***** CHARGE 1251265 CJIS_CASE_NUMBER 2026CF2159A9
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251265';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251265',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251265
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251265
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251265',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251265'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251265';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251265';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251265',
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
AND CHARGE_ID = 1251265
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251265', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251265',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251265',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251265';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251265',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251265';
        
END;
/

/***********************************************************
***** CHARGE 1251518 CJIS_CASE_NUMBER 2026CF2195A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251518';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251518',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251518
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251518
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251518',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251518'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251518';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251518';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251518',
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
AND CHARGE_ID = 1251518
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251518', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251518',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251518',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251518';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251518',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251518';
        
END;
/

/***********************************************************
***** CHARGE 1251527 CJIS_CASE_NUMBER 2026HH772A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251527';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251527',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251527
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251527
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251527',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251527'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1251527';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251527';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251527',
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
AND CHARGE_ID = 1251527
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251527', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251527',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251527',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251527';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251527',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251527';
        
END;
/

/***********************************************************
***** CHARGE 1251965 CJIS_CASE_NUMBER 2026CF2212A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251965';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251965',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251965
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251965
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251965',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251965'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'N',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1251965';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251965';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251965',
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
AND CHARGE_ID = 1251965
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251965', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251965',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251965',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251965';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251965',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251965';
        
END;
/

/***********************************************************
***** CHARGE 1251784 CJIS_CASE_NUMBER 2026CF2240A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251784';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251784',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251784
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251784
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251784',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251784'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251784';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251784';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251784',
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
AND CHARGE_ID = 1251784
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251784', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251784',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251784',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251784';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251784',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251784';
        
END;
/

/***********************************************************
***** CHARGE 1251813 CJIS_CASE_NUMBER 2026MM1617A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251813';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251813',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251813
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251813
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251813',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251813'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1251813';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251813';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251813',
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
AND CHARGE_ID = 1251813
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251813', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251813',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251813',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251813';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251813',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251813';
        
END;
/

/***********************************************************
***** CHARGE 1220222 CJIS_CASE_NUMBER 2025CF904A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1220222';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1220222',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1220222
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1220222
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1220222',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1220222'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1220222';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1220222';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1220222',
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
AND CHARGE_ID = 1220222
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1220222', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1220222',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1220222',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1220222';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1220222',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1220222';
        
END;
/

/***********************************************************
***** CHARGE 1220224 CJIS_CASE_NUMBER 2025CF904A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1220224';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1220224',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1220224
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1220224
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1220224',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1220224'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1220224';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1220224';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1220224',
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
AND CHARGE_ID = 1220224
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1220224', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1220224',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1220224',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1220224';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1220224',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1220224';
        
END;
/

/***********************************************************
***** CHARGE 1247337 CJIS_CASE_NUMBER 2026MM1175A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1247337';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1247337',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247337
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247337
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247337',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247337'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1247337';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247337';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247337',
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
AND CHARGE_ID = 1247337
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247337', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247337',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1247337',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1247337';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1247337',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1247337';
        
END;
/

/***********************************************************
***** CHARGE 1247338 CJIS_CASE_NUMBER 2026MM1175A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1247338';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1247338',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247338
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247338
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247338',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247338'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1247338';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247338';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247338',
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
AND CHARGE_ID = 1247338
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247338', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247338',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1247338',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1247338';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1247338',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1247338';
        
END;
/

/***********************************************************
***** CHARGE 1228870 CJIS_CASE_NUMBER 2025CF2275A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1228870';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1228870',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228870
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228870
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1228870',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228870'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1228870';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228870';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1228870',
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
AND CHARGE_ID = 1228870
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228870', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1228870',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1228870',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1228870';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1228870',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1228870';
        
END;
/

/***********************************************************
***** CHARGE 1246822 CJIS_CASE_NUMBER 2026CF1616A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1246822';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246822',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246822
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246822
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246822',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246822'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246822';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246822';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246822',
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
AND CHARGE_ID = 1246822
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246822', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246822',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246822',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1246822';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1246822',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1246822';
        
END;
/

/***********************************************************
***** CHARGE 1246823 CJIS_CASE_NUMBER 2026CF1616A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1246823';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246823',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246823
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246823
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246823',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246823'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246823';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246823';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246823',
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
AND CHARGE_ID = 1246823
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246823', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246823',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246823',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1246823';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1246823',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1246823';
        
END;
/

/***********************************************************
***** CHARGE 1190209 CJIS_CASE_NUMBER 2023CF3290A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1190209';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190209',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190209
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190209
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190209',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190209'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1190209';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190209';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190209',
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
AND CHARGE_ID = 1190209
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1190209', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190209',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190209',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1190209';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1190209',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1190209';
        
END;
/

/***********************************************************
***** CHARGE 1190208 CJIS_CASE_NUMBER 2023CF3290A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1190208';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190208',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190208
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190208
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190208',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190208'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1190208';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190208';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190208',
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
AND CHARGE_ID = 1190208
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1190208', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190208',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190208',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1190208';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1190208',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1190208';
        
END;
/

/***********************************************************
***** CHARGE 1190207 CJIS_CASE_NUMBER 2023CF3290A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1190207';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190207',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190207
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190207
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190207',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190207'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1190207';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190207';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190207',
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
AND CHARGE_ID = 1190207
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1190207', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190207',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190207',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1190207';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1190207',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1190207';
        
END;
/

/***********************************************************
***** CHARGE 1190205 CJIS_CASE_NUMBER 2023CF3290A4
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1190205';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190205',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190205
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190205
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190205',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190205'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1190205';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190205';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190205',
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
AND CHARGE_ID = 1190205
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1190205', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190205',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190205',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1190205';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1190205',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1190205';
        
END;
/

/***********************************************************
***** CHARGE 1190206 CJIS_CASE_NUMBER 2023CF3290A5
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1190206';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190206',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190206
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1190206
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190206',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190206'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1190206';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1190206';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190206',
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
AND CHARGE_ID = 1190206
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1190206', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1190206',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1190206',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1190206';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1190206',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1190206';
        
END;
/

/***********************************************************
***** CHARGE 1244532 CJIS_CASE_NUMBER 2026CF1207A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1244532';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1244532',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244532
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244532
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1244532',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244532'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1244532';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244532';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1244532',
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
AND CHARGE_ID = 1244532
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244532', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1244532',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1244532',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1244532';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1244532',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1244532';
        
END;
/

/***********************************************************
***** CHARGE 525242 CJIS_CASE_NUMBER 2004CF2290A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '525242';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '525242',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 525242
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 525242
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '525242',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '525242'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '525242';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '525242';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '525242',
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
AND CHARGE_ID = 525242
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '525242', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '525242',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '525242',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '525242';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '525242',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '525242';
        
END;
/

/***********************************************************
***** CHARGE 529054 CJIS_CASE_NUMBER 2004CF2797A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '529054';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '529054',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 529054
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 529054
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529054',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '529054'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '529054';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '529054';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529054',
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
AND CHARGE_ID = 529054
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '529054', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529054',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '529054',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '529054';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '529054',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '529054';
        
END;
/

/***********************************************************
***** CHARGE 529056 CJIS_CASE_NUMBER 2004CF2797A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '529056';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '529056',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 529056
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 529056
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529056',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '529056'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '529056';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '529056';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529056',
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
AND CHARGE_ID = 529056
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '529056', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529056',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '529056',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '529056';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '529056',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '529056';
        
END;
/

/***********************************************************
***** CHARGE 529057 CJIS_CASE_NUMBER 2004CF2797A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '529057';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '529057',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 529057
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 529057
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529057',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '529057'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '529057';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '529057';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529057',
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
AND CHARGE_ID = 529057
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '529057', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '529057',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '529057',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '529057';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '529057',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '529057';
        
END;
/

/***********************************************************
***** CHARGE 634875 CJIS_CASE_NUMBER 2007CF1615A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '634875';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '634875',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 634875
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 634875
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '634875',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '634875'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '634875';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '634875';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '634875',
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
AND CHARGE_ID = 634875
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '634875', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '634875',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '634875',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '634875';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '634875',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '634875';
        
END;
/

/***********************************************************
***** CHARGE 634874 CJIS_CASE_NUMBER 2007CF1615A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '634874';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '634874',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 634874
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 634874
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '634874',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '634874'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '634874';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '634874';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '634874',
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
AND CHARGE_ID = 634874
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '634874', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '634874',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '634874',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '634874';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '634874',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '634874';
        
END;
/

/***********************************************************
***** CHARGE 1247583 CJIS_CASE_NUMBER 2026MM1197A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1247583';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1247583',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247583
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247583
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247583',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247583'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1247583';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247583';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247583',
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
AND CHARGE_ID = 1247583
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247583', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1247583',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1247583',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1247583';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1247583',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1247583';
        
END;
/

/***********************************************************
***** CHARGE 1249616 CJIS_CASE_NUMBER 2026MM1375A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1249616';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249616',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249616
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249616
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249616',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249616'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1249616';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249616';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249616',
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
AND CHARGE_ID = 1249616
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249616', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249616',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249616',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1249616';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1249616',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1249616';
        
END;
/

/***********************************************************
***** CHARGE 1207723 CJIS_CASE_NUMBER 2024CF2560A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1207723';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1207723',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207723
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207723
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1207723',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207723'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1207723';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207723';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1207723',
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
AND CHARGE_ID = 1207723
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1207723', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1207723',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1207723',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1207723';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1207723',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1207723';
        
END;
/

/***********************************************************
***** CHARGE 1218775 CJIS_CASE_NUMBER 2025CF716A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1218775';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1218775',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218775
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218775
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218775',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218775'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1218775';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218775';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218775',
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
AND CHARGE_ID = 1218775
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218775', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218775',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1218775',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1218775';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1218775',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1218775';
        
END;
/

/***********************************************************
***** CHARGE 1219761 CJIS_CASE_NUMBER 2025CF716A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1219761';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219761',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219761
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219761
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219761',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219761'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1219761';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219761';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219761',
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
AND CHARGE_ID = 1219761
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1219761', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219761',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219761',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1219761';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1219761',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1219761';
        
END;
/

/***********************************************************
***** CHARGE 1218776 CJIS_CASE_NUMBER 2025CF716A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1218776';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1218776',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218776
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218776
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218776',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218776'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1218776';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218776';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218776',
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
AND CHARGE_ID = 1218776
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218776', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218776',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1218776',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1218776';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1218776',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1218776';
        
END;
/

/***********************************************************
***** CHARGE 1219762 CJIS_CASE_NUMBER 2025CF716A4
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1219762';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219762',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219762
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219762
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219762',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219762'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1219762';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219762';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219762',
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
AND CHARGE_ID = 1219762
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1219762', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219762',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219762',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1219762';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1219762',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1219762';
        
END;
/

/***********************************************************
***** CHARGE 1219764 CJIS_CASE_NUMBER 2025CF716A5
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1219764';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219764',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219764
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219764
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219764',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219764'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1219764';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219764';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219764',
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
AND CHARGE_ID = 1219764
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1219764', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219764',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219764',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1219764';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1219764',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1219764';
        
END;
/

/***********************************************************
***** CHARGE 1219763 CJIS_CASE_NUMBER 2025CF716A6
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1219763';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219763',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219763
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219763
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219763',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219763'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1219763';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219763';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219763',
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
AND CHARGE_ID = 1219763
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1219763', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1219763',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1219763',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1219763';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1219763',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1219763';
        
END;
/

/***********************************************************
***** CHARGE 1249016 CJIS_CASE_NUMBER 2026CF1909A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1249016';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249016',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249016
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249016
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249016',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249016'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'C',
    LOCATION = 'CAP.'
WHERE CHARGE_ID = '1249016';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249016';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249016',
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
AND CHARGE_ID = 1249016
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249016', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249016',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249016',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1249016';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1249016',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1249016';
        
END;
/

/***********************************************************
***** CHARGE 1249017 CJIS_CASE_NUMBER 2026CF1909A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1249017';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249017',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249017
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249017
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249017',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249017'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'C',
    LOCATION = 'CAP.'
WHERE CHARGE_ID = '1249017';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249017';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249017',
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
AND CHARGE_ID = 1249017
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249017', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249017',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249017',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1249017';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1249017',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1249017';
        
END;
/

/***********************************************************
***** CHARGE 1249018 CJIS_CASE_NUMBER 2026CF1909A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1249018';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249018',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249018',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249018'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'C',
    LOCATION = 'CAP.'
WHERE CHARGE_ID = '1249018';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249018';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249018',
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
AND CHARGE_ID = 1249018
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249018', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1249018',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1249018',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1249018';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1249018',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1249018';
        
END;
/

/***********************************************************
***** CHARGE 1240345 CJIS_CASE_NUMBER 2026CF591A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1240345';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1240345',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240345
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240345
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1240345',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240345'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1240345';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240345';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1240345',
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
AND CHARGE_ID = 1240345
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240345', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1240345',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1240345',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1240345';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1240345',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1240345';
        
END;
/

/***********************************************************
***** CHARGE 1214623 CJIS_CASE_NUMBER 2024CF3644A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1214623';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1214623',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214623
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214623
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1214623',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214623'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1214623';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214623';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1214623',
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
AND CHARGE_ID = 1214623
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1214623', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1214623',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1214623',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1214623';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1214623',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1214623';
        
END;
/

/***********************************************************
***** CHARGE 1246142 CJIS_CASE_NUMBER 2026CF1501A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1246142';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246142',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246142
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246142
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246142',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246142'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1246142';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246142';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246142',
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
AND CHARGE_ID = 1246142
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246142', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246142',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246142',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1246142';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1246142',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1246142';
        
END;
/

/***********************************************************
***** CHARGE 1246144 CJIS_CASE_NUMBER 2026CF1501A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1246144';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246144',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246144
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246144
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246144',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246144'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1246144';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246144';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246144',
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
AND CHARGE_ID = 1246144
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246144', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246144',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246144',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1246144';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1246144',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1246144';
        
END;
/

/***********************************************************
***** CHARGE 1246143 CJIS_CASE_NUMBER 2026CF1501A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1246143';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246143',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246143
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246143
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246143',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246143'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1246143';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246143';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246143',
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
AND CHARGE_ID = 1246143
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246143', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246143',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246143',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1246143';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1246143',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1246143';
        
END;
/

/***********************************************************
***** CHARGE 1246145 CJIS_CASE_NUMBER 2026CF1501A4
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1246145';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246145',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246145
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246145
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246145',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246145'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1246145';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246145';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246145',
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
AND CHARGE_ID = 1246145
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246145', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1246145',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1246145',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1246145';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1246145',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1246145';
        
END;
/

/***********************************************************
***** CHARGE 564385 CJIS_CASE_NUMBER 2005CF2912A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '564385';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '564385',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 564385
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 564385
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564385',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '564385'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '564385';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '564385';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564385',
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
AND CHARGE_ID = 564385
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '564385', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564385',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '564385',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '564385';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '564385',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '564385';
        
END;
/

/***********************************************************
***** CHARGE 564386 CJIS_CASE_NUMBER 2005CF2912A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '564386';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '564386',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 564386
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 564386
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564386',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '564386'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '564386';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '564386';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564386',
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
AND CHARGE_ID = 564386
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '564386', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564386',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '564386',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '564386';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '564386',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '564386';
        
END;
/

/***********************************************************
***** CHARGE 564387 CJIS_CASE_NUMBER 2005CF2912A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '564387';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '564387',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 564387
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 564387
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564387',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '564387'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '564387';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '564387';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564387',
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
AND CHARGE_ID = 564387
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '564387', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '564387',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '564387',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '564387';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '564387',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '564387';
        
END;
/

/***********************************************************
***** CHARGE 717112 CJIS_CASE_NUMBER 2009MM4057A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '717112';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '717112',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 717112
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 717112
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '717112',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '717112'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '717112';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '717112';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '717112',
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
AND CHARGE_ID = 717112
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '717112', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '717112',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '717112',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '717112';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '717112',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '717112';
        
END;
/

/***********************************************************
***** CHARGE 742309 CJIS_CASE_NUMBER 2010MM2391A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '742309';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '742309',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 742309
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 742309
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '742309',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '742309'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '742309';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '742309';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '742309',
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
AND CHARGE_ID = 742309
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '742309', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '742309',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '742309',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '742309';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '742309',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '742309';
        
END;
/

/***********************************************************
***** CHARGE 750892 CJIS_CASE_NUMBER 2010MM3880A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '750892';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '750892',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 750892
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 750892
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '750892',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '750892'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '750892';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '750892';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '750892',
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
AND CHARGE_ID = 750892
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '750892', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '750892',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '750892',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '750892';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '750892',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '750892';
        
END;
/

/***********************************************************
***** CHARGE 750893 CJIS_CASE_NUMBER 2010MM3880A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '750893';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '750893',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 750893
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 750893
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '750893',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '750893'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '750893';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '750893';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '750893',
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
AND CHARGE_ID = 750893
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '750893', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '750893',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '750893',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '750893';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '750893',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '750893';
        
END;
/

/***********************************************************
***** CHARGE 814350 CJIS_CASE_NUMBER 2012MM2202A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '814350';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '814350',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 814350
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 814350
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '814350',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '814350'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '814350';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '814350';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '814350',
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
AND CHARGE_ID = 814350
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '814350', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '814350',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '814350',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '814350';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '814350',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '814350';
        
END;
/

/***********************************************************
***** CHARGE 849451 CJIS_CASE_NUMBER 2013CF160A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '849451';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '849451',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 849451
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 849451
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '849451',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '849451'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '849451';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '849451';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '849451',
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
AND CHARGE_ID = 849451
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '849451', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '849451',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '849451',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '849451';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '849451',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '849451';
        
END;
/

/***********************************************************
***** CHARGE 917325 CJIS_CASE_NUMBER 2014MM1998A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '917325';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '917325',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 917325
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 917325
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '917325',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '917325'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '917325';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '917325';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '917325',
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
AND CHARGE_ID = 917325
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '917325', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '917325',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '917325',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '917325';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '917325',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '917325';
        
END;
/

/***********************************************************
***** CHARGE 981832 CJIS_CASE_NUMBER 2016MM910A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '981832';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '981832',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 981832
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 981832
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '981832',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '981832'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '981832';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '981832';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '981832',
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
AND CHARGE_ID = 981832
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '981832', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '981832',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '981832',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '981832';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '981832',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '981832';
        
END;
/

/***********************************************************
***** CHARGE 1204115 CJIS_CASE_NUMBER 2024CF1985A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1204115';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1204115',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1204115
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1204115
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1204115',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204115'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1204115';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204115';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1204115',
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
AND CHARGE_ID = 1204115
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1204115', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1204115',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1204115',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1204115';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1204115',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1204115';
        
END;
/

/***********************************************************
***** CHARGE 1193139 CJIS_CASE_NUMBER 2024MM81A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1193139';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1193139',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193139
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1193139
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1193139',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1193139'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1193139';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1193139';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1193139',
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
AND CHARGE_ID = 1193139
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1193139', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1193139',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1193139',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1193139';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1193139',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1193139';
        
END;
/

/***********************************************************
***** CHARGE 616944 CJIS_CASE_NUMBER 2006CF4680A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '616944';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '616944',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 616944
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 616944
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '616944',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '616944'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDWD'
WHERE CHARGE_ID = '616944';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '616944';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '616944',
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
AND CHARGE_ID = 616944
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '616944', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '616944',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '616944',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '616944';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '616944',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '616944';
        
END;
/

/***********************************************************
***** CHARGE 1138587 CJIS_CASE_NUMBER 2021CF2165A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1138587';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1138587',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1138587
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1138587
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1138587',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1138587'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1138587';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1138587';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1138587',
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
AND CHARGE_ID = 1138587
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1138587', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1138587',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1138587',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1138587';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1138587',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1138587';
        
END;
/

/***********************************************************
***** CHARGE 1009736 CJIS_CASE_NUMBER 2017CF801A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1009736';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1009736',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1009736
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1009736
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1009736',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1009736'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1009736';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1009736';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1009736',
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
AND CHARGE_ID = 1009736
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1009736', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1009736',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1009736',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1009736';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1009736',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1009736';
        
END;
/

/***********************************************************
***** CHARGE 1200791 CJIS_CASE_NUMBER 2024CF1409A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1200791';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200791',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200791
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200791
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200791',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200791'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1200791';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200791';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200791',
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
AND CHARGE_ID = 1200791
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1200791', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200791',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200791',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1200791';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1200791',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1200791';
        
END;
/

/***********************************************************
***** CHARGE 1200792 CJIS_CASE_NUMBER 2024CF1409A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1200792';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200792',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200792
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200792
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200792',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200792'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1200792';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200792';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200792',
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
AND CHARGE_ID = 1200792
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1200792', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200792',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200792',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1200792';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1200792',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1200792';
        
END;
/

/***********************************************************
***** CHARGE 1200794 CJIS_CASE_NUMBER 2024CF1409A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1200794';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200794',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200794
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200794
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200794',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200794'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1200794';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200794';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200794',
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
AND CHARGE_ID = 1200794
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1200794', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200794',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200794',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1200794';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1200794',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1200794';
        
END;
/

/***********************************************************
***** CHARGE 1200795 CJIS_CASE_NUMBER 2024CF1409A4
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1200795';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200795',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200795
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200795
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200795',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200795'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1200795';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200795';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200795',
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
AND CHARGE_ID = 1200795
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1200795', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200795',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200795',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1200795';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1200795',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1200795';
        
END;
/

/***********************************************************
***** CHARGE 1200796 CJIS_CASE_NUMBER 2024CF1409A5
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1200796';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1200796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200796',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200796'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1200796';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1200796';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200796',
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
AND CHARGE_ID = 1200796
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1200796', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1200796',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1200796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1200796';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1200796',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1200796';
        
END;
/

/***********************************************************
***** CHARGE 930289 CJIS_CASE_NUMBER 2014CF3464A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '930289';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '930289',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 930289
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 930289
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '930289',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '930289'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '930289';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '930289';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '930289',
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
AND CHARGE_ID = 930289
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '930289', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '930289',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '930289',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '930289';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '930289',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '930289';
        
END;
/

/***********************************************************
***** CHARGE 1236904 CJIS_CASE_NUMBER 2026MM38A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1236904';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1236904',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1236904
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1236904
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1236904',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236904'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1236904';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236904';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1236904',
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
AND CHARGE_ID = 1236904
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236904', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1236904',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1236904',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1236904';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1236904',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1236904';
        
END;
/

/***********************************************************
***** CHARGE 1218683 CJIS_CASE_NUMBER 2025CF702A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1218683';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1218683',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218683
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218683',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218683'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1218683';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218683';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218683',
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
AND CHARGE_ID = 1218683
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218683', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1218683',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1218683',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1218683';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1218683',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1218683';
        
END;
/

/***********************************************************
***** CHARGE 1240521 CJIS_CASE_NUMBER 2026CF616A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1240521';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1240521',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240521
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240521
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1240521',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240521'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1240521';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240521';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1240521',
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
AND CHARGE_ID = 1240521
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240521', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1240521',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1240521',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1240521';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1240521',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1240521';
        
END;
/

/***********************************************************
***** CHARGE 1251920 CJIS_CASE_NUMBER 2026CF2260A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251920';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251920',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251920
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251920
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251920',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251920'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251920';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251920';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251920',
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
AND CHARGE_ID = 1251920
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251920', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251920',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251920',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251920';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251920',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251920';
        
END;
/

/***********************************************************
***** CHARGE 1251921 CJIS_CASE_NUMBER 2026CF2260A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251921';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251921',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251921
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251921
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251921',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251921'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251921';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251921';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251921',
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
AND CHARGE_ID = 1251921
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251921', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251921',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251921',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251921';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251921',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251921';
        
END;
/

/***********************************************************
***** CHARGE 1251922 CJIS_CASE_NUMBER 2026CF2260A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251922';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251922',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251922'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251922';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251922';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251922',
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
AND CHARGE_ID = 1251922
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251922', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251922',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251922';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251922',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251922';
        
END;
/

/***********************************************************
***** CHARGE 1251923 CJIS_CASE_NUMBER 2026CF2260A4
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1251923';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251923',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251923
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251923
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251923',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251923'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251923';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251923';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251923',
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
AND CHARGE_ID = 1251923
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251923', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1251923',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1251923',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1251923';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1251923',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1251923';
        
END;
/

/***********************************************************
***** CHARGE 1223796 CJIS_CASE_NUMBER 2025CF1453A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1223796';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1223796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1223796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1223796
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1223796',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1223796'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1223796';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1223796';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1223796',
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
AND CHARGE_ID = 1223796
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1223796', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1223796',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1223796',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1223796';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1223796',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1223796';
        
END;
/

/***********************************************************
***** CHARGE 1216399 CJIS_CASE_NUMBER 2025CF297A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1216399';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1216399',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216399
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216399
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1216399',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216399'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1216399';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216399';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1216399',
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
AND CHARGE_ID = 1216399
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216399', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1216399',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1216399',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1216399';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1216399',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1216399';
        
END;
/

/***********************************************************
***** CHARGE 1151861 CJIS_CASE_NUMBER 2022CF909A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1151861';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1151861',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1151861
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1151861
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1151861',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1151861'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1151861';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1151861';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1151861',
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
AND CHARGE_ID = 1151861
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1151861', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1151861',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1151861',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1151861';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1151861',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1151861';
        
END;
/

/***********************************************************
***** CHARGE 1155466 CJIS_CASE_NUMBER 2022CF909A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1155466';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1155466',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1155466
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1155466
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1155466',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155466'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1155466';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1155466';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1155466',
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
AND CHARGE_ID = 1155466
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1155466', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1155466',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1155466',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1155466';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1155466',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1155466';
        
END;
/

/***********************************************************
***** CHARGE 1245984 CJIS_CASE_NUMBER 2026CF1472A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1245984';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1245984',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245984
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245984
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245984',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245984'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1245984';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245984';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245984',
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
AND CHARGE_ID = 1245984
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245984', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245984',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1245984',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1245984';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1245984',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1245984';
        
END;
/

/***********************************************************
***** CHARGE 1245985 CJIS_CASE_NUMBER 2026CF1472A3
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1245985';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1245985',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245985
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245985
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245985',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245985'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1245985';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245985';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245985',
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
AND CHARGE_ID = 1245985
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245985', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245985',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1245985',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1245985';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1245985',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1245985';
        
END;
/

/***********************************************************
***** CHARGE 1245987 CJIS_CASE_NUMBER 2026CF1472A4
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1245987';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1245987',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245987
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245987
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245987',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245987'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1245987';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245987';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245987',
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
AND CHARGE_ID = 1245987
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245987', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1245987',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1245987',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1245987';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1245987',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1245987';
        
END;
/

/***********************************************************
***** CHARGE 1242977 CJIS_CASE_NUMBER 2026CF936A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1242977';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1242977',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242977
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242977
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1242977',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242977'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1242977';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242977';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1242977',
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
AND CHARGE_ID = 1242977
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242977', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1242977',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1242977',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1242977';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1242977',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1242977';
        
END;
/

/***********************************************************
***** CHARGE 1248694 CJIS_CASE_NUMBER 2026CT916A1
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1248694';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1248694',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248694
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248694
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1248694',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248694'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'F',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1248694';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248694';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1248694',
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
AND CHARGE_ID = 1248694
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248694', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1248694',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1248694',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1248694';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1248694',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1248694';
        
END;
/

/***********************************************************
***** CHARGE 1248695 CJIS_CASE_NUMBER 2026CT916A2
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
       WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
       AND charge_id = '1248695';

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1248695',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248695
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248695
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1248695',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248695'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'F',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1248695';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248695';


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1248695',
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
AND CHARGE_ID = 1248695
AND cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248695', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'a2b01364-ee55-43dc-97f1-0d3f6c729357' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id       => '1248695',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
    p_charge_id    => '1248695',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
            AND charge_id = '1248695';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
            p_charge_id    => '1248695',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'a2b01364-ee55-43dc-97f1-0d3f6c729357'
        AND charge_id = '1248695';
        
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
        p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => 'a2b01364-ee55-43dc-97f1-0d3f6c729357',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

