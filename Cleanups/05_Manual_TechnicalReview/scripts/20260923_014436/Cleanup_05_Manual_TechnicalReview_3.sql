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
    WHERE cleanup_name='20260923_014436_Cleanup_05_Manual_TechnicalReview_3';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_3] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050','20260923_014436_Cleanup_05_Manual_TechnicalReview_3','TODO','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF2756A2', '1161910', '195443', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF2756A3', '1161911', '195443', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF2756A4', '1161912', '195443', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF2756A5', '1161913', '195443', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2019CF3457A1', '1090615', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2020CF1783A1', '1108444', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2020CF1783A2', '1108445', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF3084A1', '1163953', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF3084A2', '1163954', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF3084A3', '1163955', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2024CF1652A1', '1202255', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2024CF1652A2', '1202256', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2024CF761A1', '1196954', '199275', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2021CF3232A1', '1145451', '199686', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2022CF2820A1', '1162263', '199686', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1398A1', '1245548', '200795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF82A1', '1237057', '200795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2018CF882A1', '1045263', '201033', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF561A1', '1240193', '201033', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF564A1', '1240210', '201033', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF633A2', '1240621', '201033', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026MM1840A1', '1252113', '201379', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026MM1840A2', '1252114', '201379', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF1913A1', '1226550', '202372', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF1913A2', '1226551', '202372', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1769A1', '1247725', '202795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF928A1', '1242936', '202795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF928A2', '1242937', '202795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF928A3', '1242938', '202795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF928A4', '1242939', '202795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF928A5', '1242940', '202795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF928A6', '1242941', '202795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2023CF2058A1', '1182566', '204050', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2016CF1912A1', '990341', '204370', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1746A1', '1247591', '206674', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026MM1211A1', '1247679', '208914', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026MM1211A2', '1247680', '208914', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026MM1211A3', '1247681', '208914', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF2152A1', '1251215', '210373', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF2152A2', '1251212', '210373', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF2152A3', '1251213', '210373', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF2152A4', '1251214', '210373', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF2152A5', '1251216', '210373', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2013MM1358A1', '861372', '212395', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2015MM1121A1', '944399', '212395', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026MM1141A1', '1246981', '212395', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2019CF4212A1', '1095767', '217903', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2019CF4212A2', '1095768', '217903', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2019CF4212A3', '1095769', '217903', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2019CF4212A4', '1095770', '217903', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2019CF4212A5', '1095771', '217903', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1785A1', '1247792', '220172', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2730A1', '1231651', '220982', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2730A2', '1231652', '220982', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF3010A1', '1233461', '220982', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2279A1', '1228914', '221020', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF3402A1', '1235967', '221329', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF946A1', '1243017', '221513', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF946A2', '1243018', '221513', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF946A3', '1243019', '221513', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CT364A1', '1241552', '221513', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CT364A2', '1241553', '221513', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A1', '1215650', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A2', '1215653', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A3', '1215651', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A4', '1215654', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A5', '1215652', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A6', '1215656', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A7', '1215657', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF172A8', '1215655', '222910', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2023CT160A1', '1170112', '224859', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2024CT204A1', '1194368', '224859', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2024CF1464A1', '1201128', '225147', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2024CF1464A2', '1201129', '225147', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2024CF1464A3', '1201130', '225147', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF1690A1', '1225206', '225147', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF1690A2', '1225207', '225147', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026HH568A1', '1247336', '225147', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026HH568A2', '1247342', '225147', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1689A1', '1247299', '226092', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1689A2', '1247300', '226092', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF3476A1', '1236326', '226415', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1628A1', '1246904', '226901', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1651A1', '1247019', '226901', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF908A1', '1242821', '227129', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1892A2', '1248725', '228625', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2026CF1892A3', '1248726', '228625', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF1497A1', '1224031', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2618A1', '1230991', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2618A2', '1230992', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2618A3', '1230993', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2618A4', '1230994', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2618A5', '1230995', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2658A1', '1231305', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2658A2', '1231306', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2658A3', '1231307', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2720A1', '1231605', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2025CF2720A2', '1231606', '229206', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2013CF2697A1', '875730', '229261', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('93f9ea89-6fe1-401d-8bf7-a402de2be050', '2013CF2697A2', '916392', '229261', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_3] started'
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocation::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1161910 CJIS_CASE_NUMBER 2022CF2756A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1161910';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161910',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161910
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161910
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161910',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161910'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1161910';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161910';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161910',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1161910
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1161910', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161910',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161910',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1161910';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1161910',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1161910';
        
END;
/

/***********************************************************
***** CHARGE 1161911 CJIS_CASE_NUMBER 2022CF2756A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1161911';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161911',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161911
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161911
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161911',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161911'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1161911';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161911';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161911',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1161911
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1161911', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161911',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161911',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1161911';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1161911',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1161911';
        
END;
/

/***********************************************************
***** CHARGE 1161912 CJIS_CASE_NUMBER 2022CF2756A4
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1161912';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161912',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161912
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161912
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161912',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161912'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1161912';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161912';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161912',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1161912
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1161912', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161912',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161912',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1161912';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1161912',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1161912';
        
END;
/

/***********************************************************
***** CHARGE 1161913 CJIS_CASE_NUMBER 2022CF2756A5
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1161913';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161913
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1161913
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161913',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161913'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1161913';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1161913';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161913',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1161913
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1161913', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1161913',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1161913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1161913';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1161913',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1161913';
        
END;
/

/***********************************************************
***** CHARGE 1090615 CJIS_CASE_NUMBER 2019CF3457A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1090615';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1090615',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1090615
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1090615
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1090615',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1090615'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1090615';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1090615';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1090615',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1090615
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1090615', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1090615',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1090615',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1090615';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1090615',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1090615';
        
END;
/

/***********************************************************
***** CHARGE 1108444 CJIS_CASE_NUMBER 2020CF1783A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1108444';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1108444',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1108444
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1108444
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1108444',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108444'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1108444';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108444';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1108444',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1108444
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1108444', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1108444',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1108444',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1108444';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1108444',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1108444';
        
END;
/

/***********************************************************
***** CHARGE 1108445 CJIS_CASE_NUMBER 2020CF1783A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1108445';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1108445',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1108445
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1108445
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1108445',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108445'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1108445';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1108445';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1108445',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1108445
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1108445', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1108445',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1108445',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1108445';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1108445',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1108445';
        
END;
/

/***********************************************************
***** CHARGE 1163953 CJIS_CASE_NUMBER 2022CF3084A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1163953';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1163953',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163953
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163953
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163953',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163953'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1163953';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163953';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163953',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1163953
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1163953', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163953',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1163953',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1163953';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1163953',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1163953';
        
END;
/

/***********************************************************
***** CHARGE 1163954 CJIS_CASE_NUMBER 2022CF3084A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1163954';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1163954',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163954
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163954
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163954',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163954'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1163954';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163954';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163954',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1163954
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1163954', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163954',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1163954',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1163954';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1163954',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1163954';
        
END;
/

/***********************************************************
***** CHARGE 1163955 CJIS_CASE_NUMBER 2022CF3084A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1163955';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1163955',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163955
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1163955
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163955',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163955'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1163955';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1163955';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163955',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1163955
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1163955', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1163955',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1163955',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1163955';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1163955',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1163955';
        
END;
/

/***********************************************************
***** CHARGE 1202255 CJIS_CASE_NUMBER 2024CF1652A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1202255';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1202255',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202255
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202255
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1202255',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202255'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1202255';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202255';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1202255',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1202255
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1202255', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1202255',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1202255',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1202255';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1202255',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1202255';
        
END;
/

/***********************************************************
***** CHARGE 1202256 CJIS_CASE_NUMBER 2024CF1652A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1202256';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1202256',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202256
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202256
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1202256',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202256'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1202256';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202256';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1202256',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1202256
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1202256', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1202256',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1202256',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1202256';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1202256',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1202256';
        
END;
/

/***********************************************************
***** CHARGE 1196954 CJIS_CASE_NUMBER 2024CF761A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1196954';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1196954',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1196954
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1196954
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1196954',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1196954'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1196954';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1196954';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1196954',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1196954
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1196954', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1196954',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1196954',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1196954';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1196954',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1196954';
        
END;
/

/***********************************************************
***** CHARGE 1145451 CJIS_CASE_NUMBER 2021CF3232A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1145451';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1145451',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1145451
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1145451
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1145451',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1145451'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1145451';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1145451';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1145451',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1145451
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1145451', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1145451',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1145451',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1145451';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1145451',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1145451';
        
END;
/

/***********************************************************
***** CHARGE 1162263 CJIS_CASE_NUMBER 2022CF2820A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1162263';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1162263',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1162263
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1162263
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1162263',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1162263'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1162263';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1162263';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1162263',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1162263
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1162263', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1162263',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1162263',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1162263';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1162263',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1162263';
        
END;
/

/***********************************************************
***** CHARGE 1245548 CJIS_CASE_NUMBER 2026CF1398A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1245548';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1245548',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245548
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245548
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1245548',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245548'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1245548';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245548';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1245548',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245548
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245548', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1245548',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1245548',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1245548';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1245548',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1245548';
        
END;
/

/***********************************************************
***** CHARGE 1237057 CJIS_CASE_NUMBER 2026CF82A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1237057';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1237057',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237057
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237057
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1237057',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1237057'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1237057';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1237057';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1237057',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1237057
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1237057', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1237057',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1237057',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1237057';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1237057',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1237057';
        
END;
/

/***********************************************************
***** CHARGE 1045263 CJIS_CASE_NUMBER 2018CF882A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1045263';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1045263',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1045263
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1045263
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1045263',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1045263'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1045263';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1045263';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1045263',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1045263
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1045263', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1045263',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1045263',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1045263';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1045263',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1045263';
        
END;
/

/***********************************************************
***** CHARGE 1240193 CJIS_CASE_NUMBER 2026CF561A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1240193';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1240193',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240193
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240193
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240193',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240193'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1240193';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240193';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240193',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240193
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240193', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240193',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1240193',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1240193';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1240193',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1240193';
        
END;
/

/***********************************************************
***** CHARGE 1240210 CJIS_CASE_NUMBER 2026CF564A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1240210';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1240210',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240210
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240210
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240210',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240210'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1240210';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240210';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240210',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240210
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240210', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240210',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1240210',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1240210';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1240210',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1240210';
        
END;
/

/***********************************************************
***** CHARGE 1240621 CJIS_CASE_NUMBER 2026CF633A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1240621';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1240621',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240621
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240621
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240621',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240621'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1240621';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240621';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240621',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240621
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240621', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1240621',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1240621',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1240621';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1240621',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1240621';
        
END;
/

/***********************************************************
***** CHARGE 1252113 CJIS_CASE_NUMBER 2026MM1840A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1252113';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1252113',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252113
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252113
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1252113',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252113'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1252113';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252113';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1252113',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1252113
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1252113', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1252113',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1252113',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1252113';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1252113',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1252113';
        
END;
/

/***********************************************************
***** CHARGE 1252114 CJIS_CASE_NUMBER 2026MM1840A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1252114';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1252114',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252114
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252114
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1252114',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252114'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1252114';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252114';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1252114',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1252114
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1252114', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1252114',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1252114',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1252114';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1252114',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1252114';
        
END;
/

/***********************************************************
***** CHARGE 1226550 CJIS_CASE_NUMBER 2025CF1913A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1226550';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1226550',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226550
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226550
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1226550',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226550'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1226550';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226550';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1226550',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1226550
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1226550', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1226550',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1226550',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1226550';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1226550',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1226550';
        
END;
/

/***********************************************************
***** CHARGE 1226551 CJIS_CASE_NUMBER 2025CF1913A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1226551';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1226551',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226551
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226551
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1226551',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226551'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1226551';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226551';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1226551',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1226551
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1226551', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1226551',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1226551',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1226551';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1226551',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1226551';
        
END;
/

/***********************************************************
***** CHARGE 1247725 CJIS_CASE_NUMBER 2026CF1769A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247725';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247725',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247725',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247725'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1247725';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247725';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247725',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247725
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247725', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247725',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247725',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247725';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247725',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247725';
        
END;
/

/***********************************************************
***** CHARGE 1242936 CJIS_CASE_NUMBER 2026CF928A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1242936';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242936',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242936
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242936
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242936',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242936'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1242936';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242936';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242936',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242936
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242936', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242936',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242936',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1242936';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1242936',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1242936';
        
END;
/

/***********************************************************
***** CHARGE 1242937 CJIS_CASE_NUMBER 2026CF928A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1242937';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242937',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242937
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242937
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242937',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242937'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1242937';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242937';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242937',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242937
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242937', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242937',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242937',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1242937';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1242937',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1242937';
        
END;
/

/***********************************************************
***** CHARGE 1242938 CJIS_CASE_NUMBER 2026CF928A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1242938';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242938',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242938
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242938
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242938',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242938'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1242938';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242938';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242938',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242938
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242938', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242938',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242938',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1242938';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1242938',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1242938';
        
END;
/

/***********************************************************
***** CHARGE 1242939 CJIS_CASE_NUMBER 2026CF928A4
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1242939';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242939',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242939
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242939
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242939',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242939'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1242939';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242939';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242939',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242939
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242939', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242939',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242939',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1242939';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1242939',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1242939';
        
END;
/

/***********************************************************
***** CHARGE 1242940 CJIS_CASE_NUMBER 2026CF928A5
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1242940';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242940',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242940
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242940
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242940',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242940'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1242940';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242940';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242940',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242940
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242940', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242940',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242940',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1242940';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1242940',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1242940';
        
END;
/

/***********************************************************
***** CHARGE 1242941 CJIS_CASE_NUMBER 2026CF928A6
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1242941';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242941',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242941
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242941
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242941',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242941'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1242941';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242941';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242941',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242941
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242941', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242941',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242941',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1242941';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1242941',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1242941';
        
END;
/

/***********************************************************
***** CHARGE 1182566 CJIS_CASE_NUMBER 2023CF2058A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1182566';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1182566',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1182566
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1182566
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1182566',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1182566'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1182566';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1182566';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1182566',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1182566
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1182566', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1182566',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1182566',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1182566';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1182566',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1182566';
        
END;
/

/***********************************************************
***** CHARGE 990341 CJIS_CASE_NUMBER 2016CF1912A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '990341';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '990341',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 990341
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 990341
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '990341',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '990341'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'DOC'
WHERE CHARGE_ID = '990341';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '990341';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '990341',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 990341
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '990341', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '990341',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '990341',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '990341';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '990341',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '990341';
        
END;
/

/***********************************************************
***** CHARGE 1247591 CJIS_CASE_NUMBER 2026CF1746A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247591';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247591',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247591
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247591
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247591',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247591'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1247591';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247591';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247591',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247591
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247591', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247591',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247591',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247591';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247591',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247591';
        
END;
/

/***********************************************************
***** CHARGE 1247679 CJIS_CASE_NUMBER 2026MM1211A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247679';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247679',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247679
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247679
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247679',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247679'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1247679';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247679';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247679',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247679
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247679', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247679',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247679',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247679';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247679',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247679';
        
END;
/

/***********************************************************
***** CHARGE 1247680 CJIS_CASE_NUMBER 2026MM1211A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247680';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247680',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247680
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247680
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247680',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247680'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1247680';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247680';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247680',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247680
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247680', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247680',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247680',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247680';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247680',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247680';
        
END;
/

/***********************************************************
***** CHARGE 1247681 CJIS_CASE_NUMBER 2026MM1211A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247681';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247681',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247681
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247681
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247681',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247681'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1247681';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247681';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247681',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247681
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247681', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247681',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247681',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247681';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247681',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247681';
        
END;
/

/***********************************************************
***** CHARGE 1251215 CJIS_CASE_NUMBER 2026CF2152A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1251215';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251215',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251215
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251215
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251215',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251215'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251215';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251215';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251215',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251215
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251215', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251215',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251215',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1251215';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1251215',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1251215';
        
END;
/

/***********************************************************
***** CHARGE 1251212 CJIS_CASE_NUMBER 2026CF2152A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1251212';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251212',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251212
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251212
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251212',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251212'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251212';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251212';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251212',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251212
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251212', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251212',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251212',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1251212';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1251212',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1251212';
        
END;
/

/***********************************************************
***** CHARGE 1251213 CJIS_CASE_NUMBER 2026CF2152A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1251213';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251213
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251213
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251213',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251213'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251213';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251213';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251213',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251213
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251213', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251213',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1251213';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1251213',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1251213';
        
END;
/

/***********************************************************
***** CHARGE 1251214 CJIS_CASE_NUMBER 2026CF2152A4
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1251214';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251214',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251214
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251214
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251214',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251214'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251214';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251214';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251214',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251214
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251214', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251214',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251214',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1251214';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1251214',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1251214';
        
END;
/

/***********************************************************
***** CHARGE 1251216 CJIS_CASE_NUMBER 2026CF2152A5
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1251216';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251216',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251216
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251216
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251216',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251216'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1251216';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251216';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251216',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251216
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251216', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1251216',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1251216',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1251216';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1251216',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1251216';
        
END;
/

/***********************************************************
***** CHARGE 861372 CJIS_CASE_NUMBER 2013MM1358A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '861372';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '861372',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 861372
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 861372
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '861372',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '861372'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '861372';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '861372';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '861372',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 861372
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '861372', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '861372',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '861372',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '861372';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '861372',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '861372';
        
END;
/

/***********************************************************
***** CHARGE 944399 CJIS_CASE_NUMBER 2015MM1121A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '944399';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '944399',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 944399
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 944399
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '944399',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '944399'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '944399';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '944399';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '944399',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 944399
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '944399', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '944399',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '944399',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '944399';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '944399',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '944399';
        
END;
/

/***********************************************************
***** CHARGE 1246981 CJIS_CASE_NUMBER 2026MM1141A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1246981';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1246981',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246981
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246981
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1246981',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246981'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'C',
    LOCATION = 'CAP.'
WHERE CHARGE_ID = '1246981';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246981';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1246981',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246981
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246981', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1246981',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1246981',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1246981';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1246981',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1246981';
        
END;
/

/***********************************************************
***** CHARGE 1095767 CJIS_CASE_NUMBER 2019CF4212A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1095767';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095767',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095767
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095767
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095767',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095767'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1095767';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095767';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095767',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1095767
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1095767', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095767',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095767',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1095767';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1095767',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1095767';
        
END;
/

/***********************************************************
***** CHARGE 1095768 CJIS_CASE_NUMBER 2019CF4212A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1095768';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095768',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095768
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095768
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095768',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095768'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1095768';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095768';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095768',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1095768
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1095768', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095768',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095768',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1095768';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1095768',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1095768';
        
END;
/

/***********************************************************
***** CHARGE 1095769 CJIS_CASE_NUMBER 2019CF4212A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1095769';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095769',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095769
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095769
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095769',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095769'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1095769';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095769';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095769',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1095769
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1095769', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095769',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095769',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1095769';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1095769',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1095769';
        
END;
/

/***********************************************************
***** CHARGE 1095770 CJIS_CASE_NUMBER 2019CF4212A4
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1095770';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095770',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095770
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095770
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095770',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095770'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1095770';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095770';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095770',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1095770
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1095770', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095770',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095770',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1095770';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1095770',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1095770';
        
END;
/

/***********************************************************
***** CHARGE 1095771 CJIS_CASE_NUMBER 2019CF4212A5
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1095771';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095771',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095771
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1095771
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095771',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095771'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1095771';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1095771';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095771',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1095771
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1095771', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1095771',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1095771',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1095771';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1095771',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1095771';
        
END;
/

/***********************************************************
***** CHARGE 1247792 CJIS_CASE_NUMBER 2026CF1785A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247792';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247792',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247792
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247792
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247792',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247792'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1247792';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247792';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247792',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247792
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247792', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247792',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247792',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247792';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247792',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247792';
        
END;
/

/***********************************************************
***** CHARGE 1231651 CJIS_CASE_NUMBER 2025CF2730A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1231651';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231651',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231651
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231651
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231651',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231651'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1231651';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231651';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231651',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231651
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231651', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231651',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231651',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1231651';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1231651',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1231651';
        
END;
/

/***********************************************************
***** CHARGE 1231652 CJIS_CASE_NUMBER 2025CF2730A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1231652';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231652',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231652
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231652
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231652',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231652'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1231652';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231652';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231652',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231652
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231652', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231652',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231652',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1231652';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1231652',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1231652';
        
END;
/

/***********************************************************
***** CHARGE 1233461 CJIS_CASE_NUMBER 2025CF3010A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1233461';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1233461',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233461
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233461
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1233461',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233461'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1233461';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233461';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1233461',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233461
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233461', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1233461',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1233461',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1233461';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1233461',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1233461';
        
END;
/

/***********************************************************
***** CHARGE 1228914 CJIS_CASE_NUMBER 2025CF2279A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1228914';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1228914',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228914
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228914
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1228914',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228914'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1228914';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228914';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1228914',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228914
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228914', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1228914',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1228914',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1228914';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1228914',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1228914';
        
END;
/

/***********************************************************
***** CHARGE 1235967 CJIS_CASE_NUMBER 2025CF3402A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1235967';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1235967',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235967
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235967
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1235967',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235967'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1235967';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235967';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1235967',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1235967
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235967', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1235967',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1235967',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1235967';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1235967',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1235967';
        
END;
/

/***********************************************************
***** CHARGE 1243017 CJIS_CASE_NUMBER 2026CF946A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1243017';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1243017',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243017
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243017
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243017',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243017'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1243017';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243017';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243017',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243017
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243017', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243017',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1243017',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1243017';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1243017',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1243017';
        
END;
/

/***********************************************************
***** CHARGE 1243018 CJIS_CASE_NUMBER 2026CF946A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1243018';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1243018',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243018
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243018',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243018'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1243018';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243018';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243018',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243018
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243018', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243018',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1243018',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1243018';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1243018',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1243018';
        
END;
/

/***********************************************************
***** CHARGE 1243019 CJIS_CASE_NUMBER 2026CF946A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1243019';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1243019',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243019
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243019
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243019',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243019'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1243019';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243019';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243019',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243019
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243019', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1243019',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1243019',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1243019';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1243019',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1243019';
        
END;
/

/***********************************************************
***** CHARGE 1241552 CJIS_CASE_NUMBER 2026CT364A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1241552';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1241552',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241552
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241552
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1241552',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241552'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1241552';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241552';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1241552',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241552
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241552', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1241552',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1241552',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1241552';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1241552',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1241552';
        
END;
/

/***********************************************************
***** CHARGE 1241553 CJIS_CASE_NUMBER 2026CT364A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1241553';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1241553',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241553
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241553
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1241553',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241553'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1241553';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241553';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1241553',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241553
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241553', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1241553',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1241553',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1241553';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1241553',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1241553';
        
END;
/

/***********************************************************
***** CHARGE 1215650 CJIS_CASE_NUMBER 2025CF172A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215650';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215650',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215650
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215650
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215650',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215650'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1215650';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215650';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215650',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215650
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215650', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215650',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215650',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215650';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215650',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215650';
        
END;
/

/***********************************************************
***** CHARGE 1215653 CJIS_CASE_NUMBER 2025CF172A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215653';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215653',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215653
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215653
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215653',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215653'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1215653';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215653';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215653',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215653
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215653', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215653',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215653',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215653';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215653',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215653';
        
END;
/

/***********************************************************
***** CHARGE 1215651 CJIS_CASE_NUMBER 2025CF172A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215651';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215651',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215651
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215651
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215651',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215651'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1215651';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215651';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215651',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215651
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215651', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215651',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215651',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215651';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215651',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215651';
        
END;
/

/***********************************************************
***** CHARGE 1215654 CJIS_CASE_NUMBER 2025CF172A4
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215654';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215654',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215654
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215654
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215654',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215654'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1215654';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215654';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215654',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215654
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215654', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215654',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215654',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215654';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215654',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215654';
        
END;
/

/***********************************************************
***** CHARGE 1215652 CJIS_CASE_NUMBER 2025CF172A5
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215652';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215652',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215652
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215652
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215652',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215652'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1215652';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215652';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215652',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215652
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215652', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215652',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215652',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215652';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215652',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215652';
        
END;
/

/***********************************************************
***** CHARGE 1215656 CJIS_CASE_NUMBER 2025CF172A6
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215656';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215656',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215656
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215656
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215656',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215656'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1215656';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215656';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215656',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215656
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215656', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215656',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215656',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215656';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215656',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215656';
        
END;
/

/***********************************************************
***** CHARGE 1215657 CJIS_CASE_NUMBER 2025CF172A7
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215657';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215657
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215657
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215657',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215657'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1215657';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215657';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215657',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215657
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215657', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215657',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215657',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215657';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215657',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215657';
        
END;
/

/***********************************************************
***** CHARGE 1215655 CJIS_CASE_NUMBER 2025CF172A8
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1215655';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215655',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215655
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215655
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215655',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215655'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1215655';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215655';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215655',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215655
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215655', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1215655',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1215655',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1215655';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1215655',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1215655';
        
END;
/

/***********************************************************
***** CHARGE 1170112 CJIS_CASE_NUMBER 2023CT160A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1170112';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1170112',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170112
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170112
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1170112',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170112'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1170112';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170112';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1170112',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1170112
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170112', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1170112',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1170112',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1170112';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1170112',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1170112';
        
END;
/

/***********************************************************
***** CHARGE 1194368 CJIS_CASE_NUMBER 2024CT204A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1194368';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1194368',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1194368
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1194368
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1194368',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1194368'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1194368';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1194368';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1194368',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1194368
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1194368', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1194368',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1194368',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1194368';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1194368',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1194368';
        
END;
/

/***********************************************************
***** CHARGE 1201128 CJIS_CASE_NUMBER 2024CF1464A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1201128';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1201128',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201128
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201128
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201128',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201128'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1201128';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201128';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201128',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1201128
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1201128', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201128',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1201128',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1201128';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1201128',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1201128';
        
END;
/

/***********************************************************
***** CHARGE 1201129 CJIS_CASE_NUMBER 2024CF1464A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1201129';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1201129',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201129
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201129
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201129',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201129'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1201129';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201129';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201129',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1201129
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1201129', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201129',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1201129',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1201129';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1201129',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1201129';
        
END;
/

/***********************************************************
***** CHARGE 1201130 CJIS_CASE_NUMBER 2024CF1464A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1201130';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1201130',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201130
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1201130
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201130',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201130'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1201130';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1201130';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201130',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1201130
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1201130', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1201130',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1201130',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1201130';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1201130',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1201130';
        
END;
/

/***********************************************************
***** CHARGE 1225206 CJIS_CASE_NUMBER 2025CF1690A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1225206';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1225206',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225206
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225206
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1225206',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225206'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1225206';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225206';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1225206',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1225206
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1225206', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1225206',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1225206',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1225206';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1225206',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1225206';
        
END;
/

/***********************************************************
***** CHARGE 1225207 CJIS_CASE_NUMBER 2025CF1690A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1225207';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1225207',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225207
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225207
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1225207',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225207'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1225207';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225207';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1225207',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1225207
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1225207', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1225207',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1225207',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1225207';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1225207',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1225207';
        
END;
/

/***********************************************************
***** CHARGE 1247336 CJIS_CASE_NUMBER 2026HH568A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247336';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247336',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247336
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247336
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247336',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247336'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1247336';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247336';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247336',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247336
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247336', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247336',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247336',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247336';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247336',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247336';
        
END;
/

/***********************************************************
***** CHARGE 1247342 CJIS_CASE_NUMBER 2026HH568A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247342';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247342',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247342
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247342
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247342',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247342'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1247342';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247342';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247342',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247342
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247342', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247342',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247342',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247342';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247342',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247342';
        
END;
/

/***********************************************************
***** CHARGE 1247299 CJIS_CASE_NUMBER 2026CF1689A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247299';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247299',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247299
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247299
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247299',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247299'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1247299';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247299';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247299',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247299
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247299', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247299',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247299',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247299';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247299',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247299';
        
END;
/

/***********************************************************
***** CHARGE 1247300 CJIS_CASE_NUMBER 2026CF1689A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247300';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247300',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247300
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247300
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247300',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247300'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1247300';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247300';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247300',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247300
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247300', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247300',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247300',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247300';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247300',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247300';
        
END;
/

/***********************************************************
***** CHARGE 1236326 CJIS_CASE_NUMBER 2025CF3476A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1236326';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1236326',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1236326
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1236326
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1236326',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236326'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1236326';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236326';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1236326',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1236326
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236326', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1236326',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1236326',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1236326';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1236326',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1236326';
        
END;
/

/***********************************************************
***** CHARGE 1246904 CJIS_CASE_NUMBER 2026CF1628A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1246904';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1246904',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246904
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246904
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1246904',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246904'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1246904';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246904';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1246904',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246904
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246904', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1246904',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1246904',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1246904';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1246904',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1246904';
        
END;
/

/***********************************************************
***** CHARGE 1247019 CJIS_CASE_NUMBER 2026CF1651A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1247019';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247019',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247019
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247019
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247019',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247019'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1247019';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247019';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247019',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247019
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247019', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1247019',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1247019',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1247019';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1247019',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1247019';
        
END;
/

/***********************************************************
***** CHARGE 1242821 CJIS_CASE_NUMBER 2026CF908A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1242821';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242821',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242821
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242821',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242821'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1242821';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242821';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242821',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242821
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242821', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1242821',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1242821',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1242821';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1242821',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1242821';
        
END;
/

/***********************************************************
***** CHARGE 1248725 CJIS_CASE_NUMBER 2026CF1892A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1248725';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1248725',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248725
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1248725',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248725'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1248725';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248725';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1248725',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248725
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248725', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1248725',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1248725',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1248725';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1248725',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1248725';
        
END;
/

/***********************************************************
***** CHARGE 1248726 CJIS_CASE_NUMBER 2026CF1892A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1248726';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1248726',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248726
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1248726',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248726'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1248726';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248726';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1248726',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248726
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248726', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1248726',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1248726',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1248726';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1248726',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1248726';
        
END;
/

/***********************************************************
***** CHARGE 1224031 CJIS_CASE_NUMBER 2025CF1497A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1224031';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1224031',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1224031
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1224031
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1224031',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1224031'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1224031';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1224031';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1224031',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1224031
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1224031', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1224031',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1224031',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1224031';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1224031',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1224031';
        
END;
/

/***********************************************************
***** CHARGE 1230991 CJIS_CASE_NUMBER 2025CF2618A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1230991';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230991',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230991
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230991
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230991',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230991'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1230991';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230991';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230991',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1230991
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230991', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230991',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230991',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1230991';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1230991',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1230991';
        
END;
/

/***********************************************************
***** CHARGE 1230992 CJIS_CASE_NUMBER 2025CF2618A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1230992';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230992',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230992
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230992
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230992',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230992'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1230992';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230992';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230992',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1230992
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230992', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230992',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230992',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1230992';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1230992',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1230992';
        
END;
/

/***********************************************************
***** CHARGE 1230993 CJIS_CASE_NUMBER 2025CF2618A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1230993';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230993',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230993
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230993
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230993',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230993'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1230993';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230993';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230993',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1230993
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230993', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230993',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230993',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1230993';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1230993',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1230993';
        
END;
/

/***********************************************************
***** CHARGE 1230994 CJIS_CASE_NUMBER 2025CF2618A4
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1230994';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230994',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230994
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230994
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230994',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230994'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1230994';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230994';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230994',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1230994
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230994', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230994',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230994',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1230994';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1230994',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1230994';
        
END;
/

/***********************************************************
***** CHARGE 1230995 CJIS_CASE_NUMBER 2025CF2618A5
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1230995';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230995',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230995
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1230995
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230995',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230995'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1230995';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1230995';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230995',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1230995
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1230995', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1230995',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1230995',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1230995';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1230995',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1230995';
        
END;
/

/***********************************************************
***** CHARGE 1231305 CJIS_CASE_NUMBER 2025CF2658A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1231305';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231305',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231305
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231305
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231305',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231305'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1231305';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231305';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231305',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231305
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231305', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231305',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231305',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1231305';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1231305',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1231305';
        
END;
/

/***********************************************************
***** CHARGE 1231306 CJIS_CASE_NUMBER 2025CF2658A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1231306';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231306',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231306
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231306
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231306',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231306'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1231306';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231306';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231306',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231306
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231306', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231306',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231306',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1231306';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1231306',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1231306';
        
END;
/

/***********************************************************
***** CHARGE 1231307 CJIS_CASE_NUMBER 2025CF2658A3
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1231307';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231307',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231307'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1231307';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231307';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231307',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231307
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231307', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231307',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1231307';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1231307',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1231307';
        
END;
/

/***********************************************************
***** CHARGE 1231605 CJIS_CASE_NUMBER 2025CF2720A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1231605';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231605',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231605
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231605
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231605',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231605'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1231605';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231605';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231605',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231605
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231605', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231605',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231605',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1231605';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1231605',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1231605';
        
END;
/

/***********************************************************
***** CHARGE 1231606 CJIS_CASE_NUMBER 2025CF2720A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '1231606';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231606',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231606
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231606
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231606',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231606'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1231606';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231606';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231606',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231606
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231606', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '1231606',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '1231606',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '1231606';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '1231606',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '1231606';
        
END;
/

/***********************************************************
***** CHARGE 875730 CJIS_CASE_NUMBER 2013CF2697A1
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '875730';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '875730',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 875730
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 875730
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '875730',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '875730'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '875730';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '875730';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '875730',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 875730
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '875730', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '875730',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '875730',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '875730';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '875730',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '875730';
        
END;
/

/***********************************************************
***** CHARGE 916392 CJIS_CASE_NUMBER 2013CF2697A2
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
       WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
       AND charge_id = '916392';

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '916392',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 916392
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 916392
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '916392',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '916392'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '916392';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '916392';


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '916392',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 916392
AND cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '916392', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '93f9ea89-6fe1-401d-8bf7-a402de2be050' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id       => '916392',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
    p_charge_id    => '916392',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
            AND charge_id = '916392';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
            p_charge_id    => '916392',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '93f9ea89-6fe1-401d-8bf7-a402de2be050'
        AND charge_id = '916392';
        
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
        p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => '93f9ea89-6fe1-401d-8bf7-a402de2be050',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

