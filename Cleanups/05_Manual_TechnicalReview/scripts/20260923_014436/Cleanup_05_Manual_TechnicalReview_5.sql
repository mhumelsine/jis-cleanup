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
    WHERE cleanup_name='20260923_014436_Cleanup_05_Manual_TechnicalReview_5';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_5] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036','20260923_014436_Cleanup_05_Manual_TechnicalReview_5','TODO','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2022CF242A2', '1148076', '251798', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2022CF3587A1', '1167609', '251798', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2022CF3587A3', '1167610', '251798', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF1707A2', '1225357', '251798', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF2228A1', '1110528', '252181', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2021CF1861A1', '1135585', '252181', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF794A1', '1241611', '252701', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2019CT2319A1', '1093409', '254002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2021CF2583A1', '1141412', '254002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2022MM746A1', '1153111', '254002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2022MM746A2', '1153110', '254002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF1975A1', '1181974', '254002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF2198A1', '1183451', '254002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF2057A1', '1227443', '254318', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025MM1541A1', '1229265', '254318', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025MM1618A1', '1229815', '254318', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2021CF1222A1', '1130603', '254879', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF1153A1', '1175927', '255428', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF1153A2', '1175928', '255428', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF1153A3', '1175929', '255428', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF1740A1', '1179950', '255428', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF1740A2', '1179951', '255428', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2023CF3481A1', '1191437', '255428', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF1984A1', '1227076', '255428', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF3300A1', '1212590', '255487', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1485A1', '1246086', '255487', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CT1207A1', '1227052', '256045', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1339A2', '1249251', '256479', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1339A3', '1249252', '256479', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF2764A1', '1209090', '256521', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF1261A1', '1222750', '256521', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2018CF3289A1', '1063153', '257125', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2018CF3289A2', '1063154', '257125', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF1933A1', '1203794', '258205', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF1933A2', '1203795', '258205', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF2254A1', '1206004', '258205', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF2254A2', '1206003', '258205', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1388A1', '1245483', '258205', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1403A1', '1245590', '258236', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1403A2', '1245591', '258236', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1738A1', '1247541', '258702', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3205A2', '1120738', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3205A3', '1120737', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3205A5', '1120740', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A1', '1122038', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A10', '1122047', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A2', '1122039', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A3', '1122040', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A4', '1122041', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A5', '1122042', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A6', '1122043', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A7', '1122044', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A8', '1122045', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3364A9', '1122046', '259302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1155A1', '1247075', '259867', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1465A1', '1250431', '260118', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2021CF268A1', '1124481', '260183', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1976A1', '1249839', '260821', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1976A2', '1249840', '260821', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1626A1', '1251937', '260821', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF2005A1', '1250111', '261698', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025MM2356A1', '1236290', '261760', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CT156A1', '1098549', '262781', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF2902A2', '1232747', '262794', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF3216A1', '1234734', '262794', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF3009A1', '1210613', '262804', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF38A1', '1192557', '262804', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1354A1', '1245307', '263043', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1354A2', '1245308', '263043', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF1852A1', '1226183', '263274', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF641A1', '1218362', '263274', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025HH499A1', '1223913', '263727', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1176A1', '1247343', '263753', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1838A1', '1252108', '264027', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1838A2', '1252109', '264027', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM1838A3', '1252110', '264027', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CT1021A1', '1250282', '264173', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1097A1', '1243888', '264536', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1097A2', '1243889', '264536', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1097A3', '1243890', '264536', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1097A4', '1243892', '264536', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1097A5', '1243891', '264536', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026MM877A1', '1244864', '264536', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3008A1', '1120047', '265008', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2020CF3008A2', '1119086', '265008', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF950A1', '1243042', '265875', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF950A2', '1243043', '265875', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF2141A1', '1227981', '266065', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1107A1', '1243938', '266065', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1120A1', '1244004', '266065', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2024CF2575A1', '1207858', '266073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1951A1', '1249692', '266073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1951A2', '1249690', '266073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1951A3', '1249689', '266073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1951A4', '1249691', '266073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF970A1', '1243190', '266736', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF970A5', '1243189', '266736', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF970A6', '1243188', '266736', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2025CF2034A1', '1227341', '266743', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('5fa7f461-9a79-4726-8bbb-bc8fb538e036', '2026CF1838A1', '1248341', '266855', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260923_014436_Cleanup_05_Manual_TechnicalReview_5] started'
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocation::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1148076 CJIS_CASE_NUMBER 2022CF242A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1148076';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1148076',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1148076
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1148076
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1148076',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1148076'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1148076';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1148076';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1148076',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1148076
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1148076', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1148076',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1148076',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1148076';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1148076',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1148076';
        
END;
/

/***********************************************************
***** CHARGE 1167609 CJIS_CASE_NUMBER 2022CF3587A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1167609';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1167609',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1167609
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1167609
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1167609',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1167609'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1167609';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1167609';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1167609',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1167609
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1167609', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1167609',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1167609',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1167609';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1167609',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1167609';
        
END;
/

/***********************************************************
***** CHARGE 1167610 CJIS_CASE_NUMBER 2022CF3587A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1167610';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1167610',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1167610
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1167610
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1167610',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1167610'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1167610';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1167610';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1167610',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1167610
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1167610', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1167610',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1167610',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1167610';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1167610',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1167610';
        
END;
/

/***********************************************************
***** CHARGE 1225357 CJIS_CASE_NUMBER 2025CF1707A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1225357';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1225357',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225357
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225357
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1225357',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225357'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1225357';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225357';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1225357',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1225357
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1225357', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1225357',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1225357',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1225357';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1225357',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1225357';
        
END;
/

/***********************************************************
***** CHARGE 1110528 CJIS_CASE_NUMBER 2020CF2228A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1110528';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1110528',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1110528
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1110528
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1110528',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1110528'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1110528';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1110528';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1110528',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1110528
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1110528', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1110528',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1110528',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1110528';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1110528',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1110528';
        
END;
/

/***********************************************************
***** CHARGE 1135585 CJIS_CASE_NUMBER 2021CF1861A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1135585';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1135585',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1135585
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1135585
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1135585',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1135585'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1135585';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1135585';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1135585',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1135585
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1135585', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1135585',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1135585',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1135585';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1135585',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1135585';
        
END;
/

/***********************************************************
***** CHARGE 1241611 CJIS_CASE_NUMBER 2026CF794A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1241611';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1241611',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241611
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1241611
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1241611',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241611'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1241611';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1241611';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1241611',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1241611
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1241611', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1241611',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1241611',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1241611';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1241611',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1241611';
        
END;
/

/***********************************************************
***** CHARGE 1093409 CJIS_CASE_NUMBER 2019CT2319A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1093409';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1093409',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1093409
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1093409
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1093409',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1093409'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1093409';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1093409';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1093409',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1093409
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1093409', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1093409',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1093409',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1093409';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1093409',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1093409';
        
END;
/

/***********************************************************
***** CHARGE 1141412 CJIS_CASE_NUMBER 2021CF2583A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1141412';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1141412',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1141412
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1141412
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1141412',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1141412'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1141412';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1141412';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1141412',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1141412
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1141412', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1141412',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1141412',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1141412';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1141412',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1141412';
        
END;
/

/***********************************************************
***** CHARGE 1153111 CJIS_CASE_NUMBER 2022MM746A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1153111';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1153111',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1153111
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1153111
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1153111',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1153111'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1153111';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1153111';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1153111',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1153111
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1153111', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1153111',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1153111',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1153111';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1153111',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1153111';
        
END;
/

/***********************************************************
***** CHARGE 1153110 CJIS_CASE_NUMBER 2022MM746A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1153110';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1153110',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1153110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1153110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1153110',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1153110'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1153110';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1153110';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1153110',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1153110
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1153110', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1153110',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1153110',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1153110';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1153110',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1153110';
        
END;
/

/***********************************************************
***** CHARGE 1181974 CJIS_CASE_NUMBER 2023CF1975A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1181974';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1181974',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1181974
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1181974
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1181974',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1181974'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1181974';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1181974';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1181974',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1181974
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1181974', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1181974',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1181974',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1181974';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1181974',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1181974';
        
END;
/

/***********************************************************
***** CHARGE 1183451 CJIS_CASE_NUMBER 2023CF2198A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1183451';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1183451',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1183451
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1183451
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1183451',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1183451'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1183451';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1183451';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1183451',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1183451
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1183451', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1183451',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1183451',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1183451';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1183451',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1183451';
        
END;
/

/***********************************************************
***** CHARGE 1227443 CJIS_CASE_NUMBER 2025CF2057A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1227443';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227443',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227443
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227443
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227443',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227443'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1227443';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227443';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227443',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227443
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227443', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227443',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227443',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1227443';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1227443',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1227443';
        
END;
/

/***********************************************************
***** CHARGE 1229265 CJIS_CASE_NUMBER 2025MM1541A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1229265';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1229265',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229265
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229265
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1229265',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229265'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1229265';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229265';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1229265',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1229265
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1229265', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1229265',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1229265',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1229265';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1229265',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1229265';
        
END;
/

/***********************************************************
***** CHARGE 1229815 CJIS_CASE_NUMBER 2025MM1618A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1229815';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1229815',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229815
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229815
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1229815',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229815'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1229815';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229815';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1229815',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1229815
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1229815', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1229815',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1229815',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1229815';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1229815',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1229815';
        
END;
/

/***********************************************************
***** CHARGE 1130603 CJIS_CASE_NUMBER 2021CF1222A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1130603';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1130603',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1130603
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1130603
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1130603',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1130603'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1130603';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1130603';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1130603',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1130603
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1130603', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1130603',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1130603',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1130603';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1130603',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1130603';
        
END;
/

/***********************************************************
***** CHARGE 1175927 CJIS_CASE_NUMBER 2023CF1153A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1175927';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1175927',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175927
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175927
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175927',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175927'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1175927';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175927';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175927',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1175927
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1175927', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175927',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1175927',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1175927';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1175927',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1175927';
        
END;
/

/***********************************************************
***** CHARGE 1175928 CJIS_CASE_NUMBER 2023CF1153A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1175928';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1175928',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175928
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175928
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175928',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175928'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1175928';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175928';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175928',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1175928
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1175928', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175928',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1175928',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1175928';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1175928',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1175928';
        
END;
/

/***********************************************************
***** CHARGE 1175929 CJIS_CASE_NUMBER 2023CF1153A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1175929';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1175929',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175929
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1175929
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175929',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175929'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1175929';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1175929';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175929',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1175929
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1175929', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1175929',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1175929',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1175929';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1175929',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1175929';
        
END;
/

/***********************************************************
***** CHARGE 1179950 CJIS_CASE_NUMBER 2023CF1740A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1179950';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1179950',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1179950
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1179950
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1179950',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1179950'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1179950';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1179950';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1179950',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1179950
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1179950', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1179950',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1179950',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1179950';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1179950',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1179950';
        
END;
/

/***********************************************************
***** CHARGE 1179951 CJIS_CASE_NUMBER 2023CF1740A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1179951';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1179951',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1179951
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1179951
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1179951',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1179951'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1179951';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1179951';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1179951',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1179951
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1179951', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1179951',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1179951',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1179951';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1179951',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1179951';
        
END;
/

/***********************************************************
***** CHARGE 1191437 CJIS_CASE_NUMBER 2023CF3481A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1191437';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1191437',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1191437
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1191437
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1191437',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1191437'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1191437';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1191437';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1191437',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1191437
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1191437', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1191437',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1191437',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1191437';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1191437',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1191437';
        
END;
/

/***********************************************************
***** CHARGE 1227076 CJIS_CASE_NUMBER 2025CF1984A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1227076';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227076',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227076
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227076
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227076',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227076'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1227076';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227076';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227076',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227076
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227076', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227076',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227076',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1227076';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1227076',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1227076';
        
END;
/

/***********************************************************
***** CHARGE 1212590 CJIS_CASE_NUMBER 2024CF3300A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1212590';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1212590',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1212590',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212590'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1212590';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212590';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1212590',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1212590
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1212590', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1212590',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1212590',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1212590';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1212590',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1212590';
        
END;
/

/***********************************************************
***** CHARGE 1246086 CJIS_CASE_NUMBER 2026CF1485A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1246086';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1246086',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246086
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246086
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1246086',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246086'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1246086';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246086';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1246086',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246086
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246086', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1246086',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1246086',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1246086';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1246086',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1246086';
        
END;
/

/***********************************************************
***** CHARGE 1227052 CJIS_CASE_NUMBER 2025CT1207A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1227052';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227052',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227052
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227052
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227052',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227052'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1227052';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227052';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227052',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227052
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227052', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227052',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227052',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1227052';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1227052',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1227052';
        
END;
/

/***********************************************************
***** CHARGE 1249251 CJIS_CASE_NUMBER 2026MM1339A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249251';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249251',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249251
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249251
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249251',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249251'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1249251';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249251';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249251',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249251
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249251', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249251',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249251',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249251';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249251',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249251';
        
END;
/

/***********************************************************
***** CHARGE 1249252 CJIS_CASE_NUMBER 2026MM1339A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249252';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249252',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249252
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249252
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249252',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249252'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1249252';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249252';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249252',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249252
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249252', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249252',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249252',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249252';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249252',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249252';
        
END;
/

/***********************************************************
***** CHARGE 1209090 CJIS_CASE_NUMBER 2024CF2764A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1209090';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1209090',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1209090
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1209090
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1209090',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1209090'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1209090';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1209090';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1209090',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1209090
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1209090', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1209090',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1209090',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1209090';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1209090',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1209090';
        
END;
/

/***********************************************************
***** CHARGE 1222750 CJIS_CASE_NUMBER 2025CF1261A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1222750';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1222750',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1222750
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1222750
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1222750',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1222750'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1222750';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1222750';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1222750',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1222750
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1222750', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1222750',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1222750',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1222750';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1222750',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1222750';
        
END;
/

/***********************************************************
***** CHARGE 1063153 CJIS_CASE_NUMBER 2018CF3289A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1063153';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1063153',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1063153
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1063153
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1063153',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1063153'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1063153';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1063153';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1063153',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1063153
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1063153', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1063153',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1063153',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1063153';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1063153',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1063153';
        
END;
/

/***********************************************************
***** CHARGE 1063154 CJIS_CASE_NUMBER 2018CF3289A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1063154';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1063154',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1063154
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1063154
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1063154',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1063154'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1063154';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1063154';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1063154',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1063154
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1063154', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1063154',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1063154',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1063154';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1063154',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1063154';
        
END;
/

/***********************************************************
***** CHARGE 1203794 CJIS_CASE_NUMBER 2024CF1933A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1203794';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1203794',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203794
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203794
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1203794',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203794'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1203794';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203794';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1203794',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1203794
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1203794', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1203794',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1203794',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1203794';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1203794',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1203794';
        
END;
/

/***********************************************************
***** CHARGE 1203795 CJIS_CASE_NUMBER 2024CF1933A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1203795';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1203795',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203795
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203795
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1203795',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203795'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1203795';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203795';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1203795',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1203795
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1203795', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1203795',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1203795',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1203795';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1203795',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1203795';
        
END;
/

/***********************************************************
***** CHARGE 1206004 CJIS_CASE_NUMBER 2024CF2254A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1206004';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1206004',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1206004
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1206004
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1206004',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1206004'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1206004';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1206004';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1206004',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1206004
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1206004', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1206004',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1206004',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1206004';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1206004',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1206004';
        
END;
/

/***********************************************************
***** CHARGE 1206003 CJIS_CASE_NUMBER 2024CF2254A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1206003';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1206003',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1206003
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1206003
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1206003',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1206003'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1206003';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1206003';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1206003',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1206003
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1206003', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1206003',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1206003',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1206003';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1206003',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1206003';
        
END;
/

/***********************************************************
***** CHARGE 1245483 CJIS_CASE_NUMBER 2026CF1388A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1245483';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245483',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245483
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245483
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245483',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245483'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1245483';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245483';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245483',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245483
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245483', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245483',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245483',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1245483';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1245483',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1245483';
        
END;
/

/***********************************************************
***** CHARGE 1245590 CJIS_CASE_NUMBER 2026CF1403A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1245590';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245590',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245590
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245590',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245590'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1245590';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245590';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245590',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245590
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245590', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245590',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245590',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1245590';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1245590',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1245590';
        
END;
/

/***********************************************************
***** CHARGE 1245591 CJIS_CASE_NUMBER 2026CF1403A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1245591';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245591',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245591
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245591
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245591',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245591'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1245591';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245591';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245591',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245591
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245591', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245591',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245591',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1245591';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1245591',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1245591';
        
END;
/

/***********************************************************
***** CHARGE 1247541 CJIS_CASE_NUMBER 2026CF1738A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1247541';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1247541',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247541
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247541
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247541',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247541'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1247541';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247541';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247541',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247541
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247541', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247541',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1247541',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1247541';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1247541',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1247541';
        
END;
/

/***********************************************************
***** CHARGE 1120738 CJIS_CASE_NUMBER 2020CF3205A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1120738';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120738',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120738
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120738
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120738',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120738'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1120738';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120738';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120738',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1120738
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1120738', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120738',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120738',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1120738';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1120738',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1120738';
        
END;
/

/***********************************************************
***** CHARGE 1120737 CJIS_CASE_NUMBER 2020CF3205A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1120737';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120737',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120737
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120737
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120737',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120737'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1120737';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120737';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120737',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1120737
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1120737', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120737',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120737',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1120737';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1120737',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1120737';
        
END;
/

/***********************************************************
***** CHARGE 1120740 CJIS_CASE_NUMBER 2020CF3205A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1120740';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120740',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120740
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120740
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120740',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120740'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1120740';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120740';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120740',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1120740
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1120740', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120740',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120740',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1120740';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1120740',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1120740';
        
END;
/

/***********************************************************
***** CHARGE 1122038 CJIS_CASE_NUMBER 2020CF3364A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122038';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122038',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122038
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122038
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122038',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122038'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122038';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122038';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122038',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122038
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122038', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122038',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122038',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122038';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122038',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122038';
        
END;
/

/***********************************************************
***** CHARGE 1122047 CJIS_CASE_NUMBER 2020CF3364A10
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122047';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122047',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122047
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122047
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122047',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122047'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1122047';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122047';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122047',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122047
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122047', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122047',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122047',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122047';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122047',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122047';
        
END;
/

/***********************************************************
***** CHARGE 1122039 CJIS_CASE_NUMBER 2020CF3364A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122039';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122039',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122039
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122039
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122039',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122039'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122039';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122039';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122039',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122039
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122039', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122039',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122039',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122039';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122039',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122039';
        
END;
/

/***********************************************************
***** CHARGE 1122040 CJIS_CASE_NUMBER 2020CF3364A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122040';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122040',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122040
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122040
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122040',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122040'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122040';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122040';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122040',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122040
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122040', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122040',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122040',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122040';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122040',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122040';
        
END;
/

/***********************************************************
***** CHARGE 1122041 CJIS_CASE_NUMBER 2020CF3364A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122041';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122041',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122041
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122041
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122041',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122041'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122041';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122041';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122041',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122041
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122041', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122041',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122041',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122041';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122041',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122041';
        
END;
/

/***********************************************************
***** CHARGE 1122042 CJIS_CASE_NUMBER 2020CF3364A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122042';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122042',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122042
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122042
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122042',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122042'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122042';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122042';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122042',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122042
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122042', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122042',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122042',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122042';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122042',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122042';
        
END;
/

/***********************************************************
***** CHARGE 1122043 CJIS_CASE_NUMBER 2020CF3364A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122043';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122043',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122043
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122043
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122043',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122043'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122043';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122043';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122043',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122043
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122043', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122043',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122043',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122043';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122043',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122043';
        
END;
/

/***********************************************************
***** CHARGE 1122044 CJIS_CASE_NUMBER 2020CF3364A7
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122044';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122044',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122044
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122044
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122044',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122044'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122044';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122044';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122044',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122044
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122044', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122044',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122044',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122044';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122044',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122044';
        
END;
/

/***********************************************************
***** CHARGE 1122045 CJIS_CASE_NUMBER 2020CF3364A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122045';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122045',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122045
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122045
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122045',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122045'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122045';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122045';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122045',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122045
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122045', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122045',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122045',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122045';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122045',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122045';
        
END;
/

/***********************************************************
***** CHARGE 1122046 CJIS_CASE_NUMBER 2020CF3364A9
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1122046';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122046',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122046
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1122046
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122046',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122046'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1122046';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1122046';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122046',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1122046
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1122046', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1122046',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1122046',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1122046';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1122046',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1122046';
        
END;
/

/***********************************************************
***** CHARGE 1247075 CJIS_CASE_NUMBER 2026MM1155A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1247075';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1247075',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247075
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247075
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247075',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247075'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1247075';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247075';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247075',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247075
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247075', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247075',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1247075',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1247075';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1247075',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1247075';
        
END;
/

/***********************************************************
***** CHARGE 1250431 CJIS_CASE_NUMBER 2026MM1465A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1250431';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1250431',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250431
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250431
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250431',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250431'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1250431';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250431';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250431',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1250431
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1250431', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250431',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1250431',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1250431';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1250431',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1250431';
        
END;
/

/***********************************************************
***** CHARGE 1124481 CJIS_CASE_NUMBER 2021CF268A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1124481';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1124481',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1124481
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1124481
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1124481',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1124481'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1124481';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1124481';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1124481',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1124481
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1124481', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1124481',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1124481',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1124481';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1124481',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1124481';
        
END;
/

/***********************************************************
***** CHARGE 1249839 CJIS_CASE_NUMBER 2026CF1976A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249839';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249839',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249839',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249839'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1249839';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249839';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249839',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249839
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249839', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249839',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249839',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249839';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249839',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249839';
        
END;
/

/***********************************************************
***** CHARGE 1249840 CJIS_CASE_NUMBER 2026CF1976A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249840';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249840',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249840
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249840
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249840',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249840'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1249840';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249840';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249840',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249840
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249840', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249840',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249840',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249840';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249840',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249840';
        
END;
/

/***********************************************************
***** CHARGE 1251937 CJIS_CASE_NUMBER 2026MM1626A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1251937';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1251937',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251937
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1251937
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1251937',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251937'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1251937';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1251937';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1251937',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1251937
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1251937', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1251937',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1251937',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1251937';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1251937',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1251937';
        
END;
/

/***********************************************************
***** CHARGE 1250111 CJIS_CASE_NUMBER 2026CF2005A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1250111';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1250111',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250111
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250111
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250111',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250111'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1250111';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250111';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250111',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1250111
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1250111', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250111',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1250111',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1250111';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1250111',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1250111';
        
END;
/

/***********************************************************
***** CHARGE 1236290 CJIS_CASE_NUMBER 2025MM2356A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1236290';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1236290',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1236290
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1236290
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1236290',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236290'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1236290';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1236290';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1236290',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1236290
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1236290', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1236290',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1236290',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1236290';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1236290',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1236290';
        
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
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1098549';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1098549',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1098549',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1098549'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1098549';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1098549';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1098549',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
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
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1098549', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1098549',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1098549',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1098549';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1098549',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1098549';
        
END;
/

/***********************************************************
***** CHARGE 1232747 CJIS_CASE_NUMBER 2025CF2902A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1232747';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1232747',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232747
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232747
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1232747',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232747'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1232747';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232747';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1232747',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232747
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232747', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1232747',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1232747',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1232747';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1232747',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1232747';
        
END;
/

/***********************************************************
***** CHARGE 1234734 CJIS_CASE_NUMBER 2025CF3216A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1234734';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1234734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1234734
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1234734',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234734'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1234734';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1234734';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1234734',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1234734
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1234734', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1234734',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1234734',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1234734';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1234734',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1234734';
        
END;
/

/***********************************************************
***** CHARGE 1210613 CJIS_CASE_NUMBER 2024CF3009A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1210613';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1210613',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210613
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1210613
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1210613',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1210613'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1210613';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1210613';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1210613',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1210613
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1210613', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1210613',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1210613',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1210613';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1210613',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1210613';
        
END;
/

/***********************************************************
***** CHARGE 1192557 CJIS_CASE_NUMBER 2024CF38A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1192557';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1192557',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1192557
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1192557
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1192557',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1192557'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1192557';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1192557';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1192557',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1192557
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1192557', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1192557',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1192557',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1192557';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1192557',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1192557';
        
END;
/

/***********************************************************
***** CHARGE 1245307 CJIS_CASE_NUMBER 2026CF1354A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1245307';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245307
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245307',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245307'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1245307';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245307';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245307',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245307
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245307', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245307',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245307',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1245307';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1245307',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1245307';
        
END;
/

/***********************************************************
***** CHARGE 1245308 CJIS_CASE_NUMBER 2026CF1354A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1245308';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245308',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245308
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245308
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245308',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245308'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1245308';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245308';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245308',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245308
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245308', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1245308',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1245308',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1245308';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1245308',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1245308';
        
END;
/

/***********************************************************
***** CHARGE 1226183 CJIS_CASE_NUMBER 2025CF1852A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1226183';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1226183',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226183
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1226183
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1226183',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226183'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1226183';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1226183';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1226183',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1226183
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1226183', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1226183',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1226183',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1226183';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1226183',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1226183';
        
END;
/

/***********************************************************
***** CHARGE 1218362 CJIS_CASE_NUMBER 2025CF641A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1218362';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1218362',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218362
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218362
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1218362',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218362'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDDS'
WHERE CHARGE_ID = '1218362';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218362';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1218362',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218362
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218362', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1218362',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1218362',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1218362';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1218362',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1218362';
        
END;
/

/***********************************************************
***** CHARGE 1223913 CJIS_CASE_NUMBER 2025HH499A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1223913';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1223913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1223913
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1223913
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1223913',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1223913'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1223913';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1223913';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1223913',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1223913
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1223913', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1223913',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1223913',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1223913';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1223913',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1223913';
        
END;
/

/***********************************************************
***** CHARGE 1247343 CJIS_CASE_NUMBER 2026MM1176A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1247343';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1247343',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247343
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247343
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247343',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247343'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1247343';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247343';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247343',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247343
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247343', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1247343',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1247343',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1247343';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1247343',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1247343';
        
END;
/

/***********************************************************
***** CHARGE 1252108 CJIS_CASE_NUMBER 2026MM1838A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1252108';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1252108',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252108
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252108
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252108',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252108'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1252108';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252108';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252108',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1252108
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1252108', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252108',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1252108',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1252108';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1252108',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1252108';
        
END;
/

/***********************************************************
***** CHARGE 1252109 CJIS_CASE_NUMBER 2026MM1838A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1252109';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1252109',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252109
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252109
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252109',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252109'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1252109';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252109';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252109',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1252109
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1252109', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252109',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1252109',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1252109';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1252109',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1252109';
        
END;
/

/***********************************************************
***** CHARGE 1252110 CJIS_CASE_NUMBER 2026MM1838A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1252110';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1252110',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1252110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252110',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252110'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1252110';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1252110';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252110',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1252110
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1252110', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1252110',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1252110',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1252110';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1252110',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1252110';
        
END;
/

/***********************************************************
***** CHARGE 1250282 CJIS_CASE_NUMBER 2026CT1021A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1250282';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1250282',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250282
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1250282
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250282',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250282'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1250282';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1250282';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250282',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1250282
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1250282', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1250282',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1250282',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1250282';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1250282',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1250282';
        
END;
/

/***********************************************************
***** CHARGE 1243888 CJIS_CASE_NUMBER 2026CF1097A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243888';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243888',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243888
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243888
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243888',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243888'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1243888';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243888';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243888',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243888
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243888', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243888',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243888',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243888';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243888',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243888';
        
END;
/

/***********************************************************
***** CHARGE 1243889 CJIS_CASE_NUMBER 2026CF1097A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243889';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243889',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243889
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243889
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243889',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243889'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1243889';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243889';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243889',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243889
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243889', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243889',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243889',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243889';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243889',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243889';
        
END;
/

/***********************************************************
***** CHARGE 1243890 CJIS_CASE_NUMBER 2026CF1097A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243890';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243890',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243890
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243890
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243890',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243890'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1243890';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243890';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243890',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243890
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243890', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243890',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243890',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243890';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243890',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243890';
        
END;
/

/***********************************************************
***** CHARGE 1243892 CJIS_CASE_NUMBER 2026CF1097A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243892';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243892',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243892
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243892
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243892',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243892'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1243892';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243892';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243892',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243892
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243892', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243892',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243892',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243892';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243892',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243892';
        
END;
/

/***********************************************************
***** CHARGE 1243891 CJIS_CASE_NUMBER 2026CF1097A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243891';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243891',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243891
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243891
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243891',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243891'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1243891';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243891';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243891',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243891
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243891', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243891',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243891',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243891';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243891',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243891';
        
END;
/

/***********************************************************
***** CHARGE 1244864 CJIS_CASE_NUMBER 2026MM877A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1244864';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1244864',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244864
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244864
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1244864',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244864'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1244864';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244864';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1244864',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244864
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244864', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1244864',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1244864',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1244864';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1244864',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1244864';
        
END;
/

/***********************************************************
***** CHARGE 1120047 CJIS_CASE_NUMBER 2020CF3008A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1120047';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120047',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120047
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1120047
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120047',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120047'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1120047';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1120047';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120047',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1120047
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1120047', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1120047',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1120047',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1120047';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1120047',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1120047';
        
END;
/

/***********************************************************
***** CHARGE 1119086 CJIS_CASE_NUMBER 2020CF3008A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1119086';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1119086',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1119086
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1119086
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1119086',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1119086'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1119086';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1119086';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1119086',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1119086
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1119086', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1119086',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1119086',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1119086';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1119086',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1119086';
        
END;
/

/***********************************************************
***** CHARGE 1243042 CJIS_CASE_NUMBER 2026CF950A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243042';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243042',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243042
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243042
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243042',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243042'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1243042';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243042';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243042',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243042
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243042', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243042',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243042',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243042';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243042',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243042';
        
END;
/

/***********************************************************
***** CHARGE 1243043 CJIS_CASE_NUMBER 2026CF950A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243043';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243043',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243043
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243043
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243043',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243043'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1243043';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243043';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243043',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243043
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243043', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243043',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243043',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243043';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243043',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243043';
        
END;
/

/***********************************************************
***** CHARGE 1227981 CJIS_CASE_NUMBER 2025CF2141A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1227981';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227981',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227981
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227981
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227981',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227981'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1227981';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227981';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227981',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227981
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227981', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227981',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227981',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1227981';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1227981',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1227981';
        
END;
/

/***********************************************************
***** CHARGE 1243938 CJIS_CASE_NUMBER 2026CF1107A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243938';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243938',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243938
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243938
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243938',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243938'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1243938';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243938';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243938',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243938
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243938', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243938',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243938',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243938';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243938',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243938';
        
END;
/

/***********************************************************
***** CHARGE 1244004 CJIS_CASE_NUMBER 2026CF1120A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1244004';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1244004',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244004
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244004
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1244004',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244004'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1244004';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244004';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1244004',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244004
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244004', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1244004',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1244004',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1244004';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1244004',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1244004';
        
END;
/

/***********************************************************
***** CHARGE 1207858 CJIS_CASE_NUMBER 2024CF2575A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1207858';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1207858',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207858
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207858
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1207858',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207858'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1207858';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207858';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1207858',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1207858
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1207858', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1207858',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1207858',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1207858';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1207858',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1207858';
        
END;
/

/***********************************************************
***** CHARGE 1249692 CJIS_CASE_NUMBER 2026CF1951A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249692';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249692',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249692
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249692
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249692',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249692'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1249692';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249692';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249692',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249692
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249692', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249692',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249692',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249692';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249692',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249692';
        
END;
/

/***********************************************************
***** CHARGE 1249690 CJIS_CASE_NUMBER 2026CF1951A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249690';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249690',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249690'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1249690';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249690';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249690',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249690
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249690', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249690',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249690';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249690',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249690';
        
END;
/

/***********************************************************
***** CHARGE 1249689 CJIS_CASE_NUMBER 2026CF1951A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249689';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249689',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249689
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249689
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249689',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249689'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDCC'
WHERE CHARGE_ID = '1249689';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249689';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249689',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249689
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249689', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249689',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249689',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249689';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249689',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249689';
        
END;
/

/***********************************************************
***** CHARGE 1249691 CJIS_CASE_NUMBER 2026CF1951A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1249691';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249691',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249691
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249691
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249691',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249691'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1249691';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249691';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249691',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249691
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249691', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1249691',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1249691',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1249691';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1249691',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1249691';
        
END;
/

/***********************************************************
***** CHARGE 1243190 CJIS_CASE_NUMBER 2026CF970A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243190';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243190',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243190
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243190
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243190',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243190'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1243190';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243190';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243190',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243190
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243190', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243190',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243190',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243190';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243190',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243190';
        
END;
/

/***********************************************************
***** CHARGE 1243189 CJIS_CASE_NUMBER 2026CF970A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243189';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243189',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243189
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243189
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243189',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243189'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1243189';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243189';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243189',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243189
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243189', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243189',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243189',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243189';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243189',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243189';
        
END;
/

/***********************************************************
***** CHARGE 1243188 CJIS_CASE_NUMBER 2026CF970A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1243188';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243188',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243188
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243188
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243188',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243188'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'RLSD'
WHERE CHARGE_ID = '1243188';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243188';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243188',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243188
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243188', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1243188',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1243188',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1243188';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1243188',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1243188';
        
END;
/

/***********************************************************
***** CHARGE 1227341 CJIS_CASE_NUMBER 2025CF2034A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1227341';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227341',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227341
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227341
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227341',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227341'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    LOCATION = 'STPR'
WHERE CHARGE_ID = '1227341';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227341';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227341',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227341
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227341', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1227341',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1227341',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1227341';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1227341',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1227341';
        
END;
/

/***********************************************************
***** CHARGE 1248341 CJIS_CASE_NUMBER 2026CF1838A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
    v_validation_error VARCHAR2(512) := NULL;
    v_count PLS_INTEGER := 0;
    v_error_message VARCHAR2(512);
    v_docket_id_str VARCHAR2(1024);
    v_inserted_id PLS_INTEGER := 0;

BEGIN
   

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
       AND charge_id = '1248341';

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1248341',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248341
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248341
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1248341',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248341'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1248341';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248341';


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1248341',
    p_step_name     => 'RestoreStatusLocation__UPDATE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248341
AND cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248341', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '5fa7f461-9a79-4726-8bbb-bc8fb538e036' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id       => '1248341',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
    p_charge_id    => '1248341',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
            AND charge_id = '1248341';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
            p_charge_id    => '1248341',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '5fa7f461-9a79-4726-8bbb-bc8fb538e036'
        AND charge_id = '1248341';
        
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
        p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => '5fa7f461-9a79-4726-8bbb-bc8fb538e036',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

