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
    WHERE cleanup_name='20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_10';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_10] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d','20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_10','Target current Inmates with changes to status, location, or bond amount that have no human activity in the audit trail after the first status, location, or bond amt change in the go live period.','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF189B15', '1176124', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF189B23', '1176213', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF189B25', '1176215', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF196A1', '1169856', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF196A22', '1169877', '269073', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF2547A1', '1185939', '273890', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF275A6', '1170414', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF275A8', '1170416', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF276A3', '1170421', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF276A4', '1170422', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF518A4', '1171839', '271076', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023CF722A2', '1172847', '272315', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023HH1060A1', '1191628', '36551', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2023MM812A1', '1176690', '260795', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF1764A2', '1202983', '266011', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF1764A4', '1204013', '266011', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF1774A1', '1203011', '225002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF1774A3', '1203013', '225002', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF1775A1', '1203015', '235826', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF2818A2', '1209443', '258884', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3244A2', '1212931', '198564', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3244A4', '1212171', '198564', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3285A1', '1212490', '143959', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3318A1', '1212703', '220932', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3403A1', '1213334', '275035', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3570A2', '1214286', '125241', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3601A1', '1214394', '43977', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2024CF3601A3', '1214393', '43977', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF1245A1', '1222636', '233068', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF1797A2', '1225967', '195187', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF198A2', '1215749', '262515', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF198A6', '1215753', '262515', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF198A7', '1215754', '262515', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF198A8', '1215755', '262515', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2026A2', '1227290', '277689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2027A1', '1227297', '277689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2028A1', '1227301', '277689', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2172A1', '1228158', '168108', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2200A1', '1228365', '278335', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2314A1', '1229136', '279623', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2376A11', '1232384', '279687', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2376A6', '1232386', '279687', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2391A1', '1229566', '272384', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF246A10', '1216060', '274757', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF246A18', '1216077', '274757', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF246A9', '1216076', '274757', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2627A5', '1231058', '279687', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2627A6', '1231059', '279687', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2830A1', '1232343', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2890A1', '1232694', '226121', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2934B2', '1233390', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2934B4', '1233392', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2934B9', '1233397', '245731', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2939A1', '1233032', '252306', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF2974A47', '1240922', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF3031A1', '1233555', '269541', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF663A1', '1218433', '278302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF663A2', '1218434', '278302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF663A3', '1218435', '278302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF676A1', '1218502', '267704', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF684A1', '1218534', '278302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF753C2', '1220866', '252644', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025CF764A7', '1219017', '112900', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025HH1165A2', '1235124', '280023', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025HV49A1', '1228058', '97806', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025MM1492A1', '1228651', '238833', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2025MM1995A1', '1233278', '180807', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1038A1', '1243553', '246723', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1038A2', '1243552', '246723', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1177A3', '1244328', '214849', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1202A4', '1244515', '250214', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1282A4', '1244897', '59944', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1295A2', '1244952', '11163', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1295A3', '1244953', '11163', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1345A1', '1245253', '104025', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1367A2', '1245395', '280624', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1437A1', '1245740', '221741', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1556A1', '1246475', '281861', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF166A3', '1238908', '22816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF166A4', '1237872', '22816', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1760A2', '1247672', '267980', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1845A12', '1248418', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1864A1', '1248533', '278219', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1953A2', '1249704', '281830', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF1973A4', '1249833', '233866', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF298A2', '1238612', '277996', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF473A1', '1239546', '178595', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF530A5', '1239880', '143959', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF551A11', '1240118', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF551A38', '1240145', '280192', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF902A1', '1242799', '278280', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF912A2', '1242850', '281377', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF912A3', '1242851', '281377', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CF523A2', '1239826', '204382', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CT71A1', '1238061', '272879', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026CT72A1', '1238063', '184102', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026HH605A2', '1248061', '257302', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026MM1220A2', '1247722', '143359', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026MM1244A4', '1247892', '243760', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('7eeb1d2a-d1ae-43e9-99bd-214012d7f20d', '2026MM674A1', '1243049', '244656', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20260925_094210_Cleanup_05_Current_Inmates_StatusChanges_With_NoHumanAction_10] started'
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[100] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[3] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocationBondAmount::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189B15'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176124',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1176124;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1176124';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176124',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176124'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176124';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176124';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176124',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
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
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176124', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176124',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176124',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1176124';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1176124',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1176124';
        
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189B23'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176213',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1176213;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1176213';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176213'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176213';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176213';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176213',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
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
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176213', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176213',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176213',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1176213';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1176213',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1176213';
        
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2023CF189B25'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176215',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1176215;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1176215';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176215',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176215'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1176215';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176215';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176215',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
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
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176215', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176215',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176215',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1176215';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1176215',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1176215';
        
END;
/

/***********************************************************
***** CHARGE 1169856 CJIS_CASE_NUMBER 2023CF196A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF196A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1169856',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1169856;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1169856';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1169856',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169856'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1169856';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169856';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1169856',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169856
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169856
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1169856',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1169856
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169856', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1169856',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1169856',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1169856';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1169856',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1169856';
        
END;
/

/***********************************************************
***** CHARGE 1169877 CJIS_CASE_NUMBER 2023CF196A22
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF196A22'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1169877',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1169877;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1169877';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1169877',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169877'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1169877';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1169877';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1169877',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169877
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1169877
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1169877',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1169877
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1169877', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1169877',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1169877',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1169877';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1169877',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1169877';
        
END;
/

/***********************************************************
***** CHARGE 1185939 CJIS_CASE_NUMBER 2023CF2547A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF2547A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1185939',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1185939;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1185939';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1185939',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185939'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1185939';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1185939';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1185939',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1185939
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1185939
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1185939',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1185939
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1185939', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1185939',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1185939',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1185939';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1185939',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1185939';
        
END;
/

/***********************************************************
***** CHARGE 1170414 CJIS_CASE_NUMBER 2023CF275A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF275A6'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170414',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1170414;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1170414';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170414',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170414'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1170414';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170414';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170414',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170414
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170414
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170414',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1170414
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170414', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170414',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170414',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1170414';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1170414',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1170414';
        
END;
/

/***********************************************************
***** CHARGE 1170416 CJIS_CASE_NUMBER 2023CF275A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF275A8'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170416',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1170416;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1170416';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170416',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170416'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1170416';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170416';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170416',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170416
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170416
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170416',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1170416
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170416', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170416',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170416',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1170416';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1170416',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1170416';
        
END;
/

/***********************************************************
***** CHARGE 1170421 CJIS_CASE_NUMBER 2023CF276A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF276A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170421',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1170421;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1170421';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170421',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170421'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1170421';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170421';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170421',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170421
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170421
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170421',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1170421
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170421', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170421',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170421',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1170421';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1170421',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1170421';
        
END;
/

/***********************************************************
***** CHARGE 1170422 CJIS_CASE_NUMBER 2023CF276A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF276A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170422',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1170422;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1170422';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170422',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170422'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1170422';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1170422';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170422',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170422
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1170422
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170422',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1170422
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1170422', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1170422',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1170422',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1170422';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1170422',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1170422';
        
END;
/

/***********************************************************
***** CHARGE 1171839 CJIS_CASE_NUMBER 2023CF518A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF518A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1171839',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1171839;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1171839';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1171839',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1171839'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1171839';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1171839';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1171839',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1171839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1171839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1171839',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1171839
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1171839', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1171839',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1171839',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1171839';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1171839',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1171839';
        
END;
/

/***********************************************************
***** CHARGE 1172847 CJIS_CASE_NUMBER 2023CF722A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023CF722A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1172847',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1172847;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1172847';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1172847',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1172847'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1172847';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1172847';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1172847',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1172847
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1172847
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1172847',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1172847
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1172847', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1172847',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1172847',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1172847';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1172847',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1172847';
        
END;
/

/***********************************************************
***** CHARGE 1191628 CJIS_CASE_NUMBER 2023HH1060A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023HH1060A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1191628',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1191628;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1191628';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1191628',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1191628'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1191628';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1191628';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1191628',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1191628
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1191628
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1191628',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1191628
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1191628', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1191628',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1191628',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1191628';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1191628',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1191628';
        
END;
/

/***********************************************************
***** CHARGE 1176690 CJIS_CASE_NUMBER 2023MM812A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2023MM812A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176690',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1176690;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1176690';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176690'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'F',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1176690';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1176690';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176690',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1176690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176690',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1176690
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1176690', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1176690',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1176690',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1176690';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1176690',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1176690';
        
END;
/

/***********************************************************
***** CHARGE 1202983 CJIS_CASE_NUMBER 2024CF1764A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF1764A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1202983',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1202983;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1202983';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1202983',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202983'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1202983';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1202983';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1202983',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202983
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1202983
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1202983',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1202983
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1202983', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1202983',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1202983',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1202983';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1202983',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1202983';
        
END;
/

/***********************************************************
***** CHARGE 1204013 CJIS_CASE_NUMBER 2024CF1764A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF1764A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1204013',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1204013;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1204013';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1204013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204013'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '25000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1204013';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1204013';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1204013',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1204013
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1204013
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1204013',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1204013
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1204013', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1204013',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1204013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1204013';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1204013',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1204013';
        
END;
/

/***********************************************************
***** CHARGE 1203011 CJIS_CASE_NUMBER 2024CF1774A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF1774A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203011',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1203011;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1203011';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203011',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203011'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1203011';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203011';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203011',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203011
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203011
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203011',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1203011
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1203011', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203011',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203011',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1203011';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1203011',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1203011';
        
END;
/

/***********************************************************
***** CHARGE 1203013 CJIS_CASE_NUMBER 2024CF1774A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF1774A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203013',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1203013;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1203013';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203013'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1203013';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203013';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203013',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203013
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203013
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203013',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1203013
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1203013', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203013',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203013',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1203013';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1203013',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1203013';
        
END;
/

/***********************************************************
***** CHARGE 1203015 CJIS_CASE_NUMBER 2024CF1775A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF1775A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203015',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1203015;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1203015';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203015',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203015'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1203015';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1203015';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203015',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203015
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1203015
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203015',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1203015
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1203015', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1203015',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1203015',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1203015';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1203015',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1203015';
        
END;
/

/***********************************************************
***** CHARGE 1209443 CJIS_CASE_NUMBER 2024CF2818A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF2818A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1209443',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1209443;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1209443';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1209443',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1209443'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1209443';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1209443';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1209443',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1209443
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1209443
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1209443',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1209443
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1209443', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1209443',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1209443',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1209443';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1209443',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1209443';
        
END;
/

/***********************************************************
***** CHARGE 1212931 CJIS_CASE_NUMBER 2024CF3244A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3244A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212931',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1212931;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1212931';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212931',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212931'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '50000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1212931';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212931';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212931',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212931
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212931
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212931',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1212931
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1212931', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212931',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212931',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1212931';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1212931',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1212931';
        
END;
/

/***********************************************************
***** CHARGE 1212171 CJIS_CASE_NUMBER 2024CF3244A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3244A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212171',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1212171;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1212171';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212171',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212171'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '50000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1212171';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212171';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212171',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212171
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212171
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212171',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1212171
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1212171', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212171',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212171',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1212171';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1212171',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1212171';
        
END;
/

/***********************************************************
***** CHARGE 1212490 CJIS_CASE_NUMBER 2024CF3285A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3285A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212490',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1212490;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1212490';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212490',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212490'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1212490';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212490';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212490',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212490
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212490
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212490',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1212490
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1212490', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212490',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212490',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1212490';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1212490',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1212490';
        
END;
/

/***********************************************************
***** CHARGE 1212703 CJIS_CASE_NUMBER 2024CF3318A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3318A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212703',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1212703;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1212703';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212703',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212703'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1212703';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1212703';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212703',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212703
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1212703
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212703',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1212703
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1212703', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1212703',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1212703',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1212703';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1212703',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1212703';
        
END;
/

/***********************************************************
***** CHARGE 1213334 CJIS_CASE_NUMBER 2024CF3403A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3403A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1213334',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1213334;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1213334';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1213334',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213334'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1213334';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1213334';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1213334',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213334
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1213334
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1213334',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1213334
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1213334', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1213334',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1213334',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1213334';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1213334',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1213334';
        
END;
/

/***********************************************************
***** CHARGE 1214286 CJIS_CASE_NUMBER 2024CF3570A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3570A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214286',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1214286;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1214286';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214286',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214286'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1214286';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214286';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214286',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214286
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214286
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214286',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1214286
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1214286', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214286',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214286',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1214286';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1214286',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1214286';
        
END;
/

/***********************************************************
***** CHARGE 1214394 CJIS_CASE_NUMBER 2024CF3601A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3601A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214394',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1214394;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1214394';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214394',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214394'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1214394';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214394';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214394',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214394
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214394
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214394',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1214394
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1214394', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214394',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214394',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1214394';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1214394',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1214394';
        
END;
/

/***********************************************************
***** CHARGE 1214393 CJIS_CASE_NUMBER 2024CF3601A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF3601A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214393',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1214393;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1214393';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214393',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214393'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1214393';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1214393';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214393',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214393
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1214393
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214393',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1214393
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1214393', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1214393',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1214393',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1214393';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1214393',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1214393';
        
END;
/

/***********************************************************
***** CHARGE 1222636 CJIS_CASE_NUMBER 2025CF1245A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF1245A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1222636',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1222636;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1222636';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1222636',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1222636'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1222636';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1222636';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1222636',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1222636
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1222636
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1222636',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1222636
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1222636', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1222636',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1222636',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1222636';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1222636',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1222636';
        
END;
/

/***********************************************************
***** CHARGE 1225967 CJIS_CASE_NUMBER 2025CF1797A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF1797A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1225967',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1225967;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1225967';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1225967',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225967'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '25000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1225967';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225967';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1225967',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225967
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225967
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1225967',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1225967
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1225967', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1225967',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1225967',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1225967';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1225967',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1225967';
        
END;
/

/***********************************************************
***** CHARGE 1215749 CJIS_CASE_NUMBER 2025CF198A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF198A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215749',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1215749;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1215749';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215749',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215749'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1215749';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215749';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215749',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215749
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215749
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215749',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215749
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215749', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215749',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215749',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1215749';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1215749',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1215749';
        
END;
/

/***********************************************************
***** CHARGE 1215753 CJIS_CASE_NUMBER 2025CF198A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF198A6'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215753',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1215753;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1215753';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215753',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215753'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1215753';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215753';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215753',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215753
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215753
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215753',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215753
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215753', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215753',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215753',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1215753';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1215753',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1215753';
        
END;
/

/***********************************************************
***** CHARGE 1215754 CJIS_CASE_NUMBER 2025CF198A7
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF198A7'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215754',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1215754;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1215754';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215754',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215754'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1215754';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215754';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215754',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215754
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215754
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215754',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215754
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215754', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215754',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215754',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1215754';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1215754',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1215754';
        
END;
/

/***********************************************************
***** CHARGE 1215755 CJIS_CASE_NUMBER 2025CF198A8
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF198A8'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215755',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1215755;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1215755';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215755',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215755'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1215755';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1215755';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215755',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215755
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1215755
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215755',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1215755
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1215755', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1215755',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1215755',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1215755';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1215755',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1215755';
        
END;
/

/***********************************************************
***** CHARGE 1227290 CJIS_CASE_NUMBER 2025CF2026A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2026A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227290',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1227290;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1227290';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227290',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227290'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1227290';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227290';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227290',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227290
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227290
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227290',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227290
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227290', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227290',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227290',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1227290';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1227290',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1227290';
        
END;
/

/***********************************************************
***** CHARGE 1227297 CJIS_CASE_NUMBER 2025CF2027A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2027A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227297',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1227297;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1227297';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227297',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227297'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1227297';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227297';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227297',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227297
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227297
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227297',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227297
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227297', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227297',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227297',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1227297';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1227297',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1227297';
        
END;
/

/***********************************************************
***** CHARGE 1227301 CJIS_CASE_NUMBER 2025CF2028A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2028A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227301',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1227301;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1227301';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227301',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227301'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1227301';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1227301';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227301',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227301
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1227301
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227301',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1227301
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1227301', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1227301',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1227301',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1227301';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1227301',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1227301';
        
END;
/

/***********************************************************
***** CHARGE 1228158 CJIS_CASE_NUMBER 2025CF2172A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2172A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228158',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1228158;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1228158';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228158',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228158'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1228158';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228158';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228158',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228158
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228158
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228158',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228158
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228158', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228158',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228158',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1228158';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1228158',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1228158';
        
END;
/

/***********************************************************
***** CHARGE 1228365 CJIS_CASE_NUMBER 2025CF2200A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2200A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228365',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1228365;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1228365';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228365',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228365'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '10000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1228365';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228365';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228365',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228365
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228365
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228365',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228365
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228365', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228365',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228365',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1228365';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1228365',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1228365';
        
END;
/

/***********************************************************
***** CHARGE 1229136 CJIS_CASE_NUMBER 2025CF2314A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2314A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1229136',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1229136;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1229136';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1229136',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229136'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1229136';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229136';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1229136',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229136
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229136
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1229136',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1229136
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1229136', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1229136',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1229136',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1229136';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1229136',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1229136';
        
END;
/

/***********************************************************
***** CHARGE 1232384 CJIS_CASE_NUMBER 2025CF2376A11
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2376A11'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232384',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1232384;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1232384';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232384',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232384'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1232384';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232384';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232384',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232384
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232384
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232384',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232384
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232384', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232384',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232384',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1232384';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1232384',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1232384';
        
END;
/

/***********************************************************
***** CHARGE 1232386 CJIS_CASE_NUMBER 2025CF2376A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2376A6'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232386',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1232386;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1232386';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232386',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232386'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '2500',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1232386';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232386';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232386',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232386
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232386
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232386',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232386
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232386', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232386',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232386',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1232386';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1232386',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1232386';
        
END;
/

/***********************************************************
***** CHARGE 1229566 CJIS_CASE_NUMBER 2025CF2391A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2391A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1229566',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1229566;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1229566';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1229566',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229566'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1229566';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1229566';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1229566',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229566
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1229566
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1229566',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1229566
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1229566', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1229566',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1229566',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1229566';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1229566',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1229566';
        
END;
/

/***********************************************************
***** CHARGE 1216060 CJIS_CASE_NUMBER 2025CF246A10
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF246A10'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216060',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1216060;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1216060';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216060',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216060'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216060';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216060';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216060',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216060
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216060
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216060',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216060
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216060', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216060',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216060',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1216060';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1216060',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1216060';
        
END;
/

/***********************************************************
***** CHARGE 1216077 CJIS_CASE_NUMBER 2025CF246A18
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF246A18'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216077',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1216077;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1216077';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216077',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216077'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216077';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216077';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216077',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216077
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216077
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216077',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216077
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216077', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216077',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216077',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1216077';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1216077',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1216077';
        
END;
/

/***********************************************************
***** CHARGE 1216076 CJIS_CASE_NUMBER 2025CF246A9
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF246A9'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216076',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1216076;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1216076';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216076',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216076'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1216076';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1216076';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216076',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216076
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1216076
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216076',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1216076
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1216076', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1216076',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1216076',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1216076';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1216076',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1216076';
        
END;
/

/***********************************************************
***** CHARGE 1231058 CJIS_CASE_NUMBER 2025CF2627A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2627A5'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1231058',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1231058;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1231058';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1231058',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231058'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1231058';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231058';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1231058',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231058
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231058
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1231058',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231058
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231058', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1231058',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1231058',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1231058';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1231058',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1231058';
        
END;
/

/***********************************************************
***** CHARGE 1231059 CJIS_CASE_NUMBER 2025CF2627A6
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2627A6'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1231059',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1231059;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1231059';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1231059',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231059'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1231059';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1231059';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1231059',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231059
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1231059
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1231059',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1231059
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1231059', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1231059',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1231059',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1231059';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1231059',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1231059';
        
END;
/

/***********************************************************
***** CHARGE 1232343 CJIS_CASE_NUMBER 2025CF2830A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2830A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232343',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1232343;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1232343';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232343',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232343'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '10000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1232343';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232343';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232343',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232343
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232343
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232343',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232343
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232343', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232343',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232343',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1232343';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1232343',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1232343';
        
END;
/

/***********************************************************
***** CHARGE 1232694 CJIS_CASE_NUMBER 2025CF2890A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2890A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232694',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1232694;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1232694';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232694',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232694'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1232694';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1232694';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232694',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232694
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1232694
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232694',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1232694
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1232694', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1232694',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1232694',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1232694';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1232694',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1232694';
        
END;
/

/***********************************************************
***** CHARGE 1233390 CJIS_CASE_NUMBER 2025CF2934B2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2934B2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233390',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1233390;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1233390';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233390',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233390'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233390';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233390';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233390',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233390
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233390
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233390',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233390
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233390', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233390',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233390',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1233390';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1233390',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1233390';
        
END;
/

/***********************************************************
***** CHARGE 1233392 CJIS_CASE_NUMBER 2025CF2934B4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2934B4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233392',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1233392;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1233392';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233392',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233392'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233392';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233392';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233392',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233392
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233392
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233392',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233392
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233392', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233392',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233392',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1233392';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1233392',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1233392';
        
END;
/

/***********************************************************
***** CHARGE 1233397 CJIS_CASE_NUMBER 2025CF2934B9
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2934B9'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233397',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1233397;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1233397';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233397',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233397'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233397';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233397';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233397',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233397
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233397
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233397',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233397
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233397', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233397',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233397',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1233397';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1233397',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1233397';
        
END;
/

/***********************************************************
***** CHARGE 1233032 CJIS_CASE_NUMBER 2025CF2939A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2939A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233032',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1233032;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1233032';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233032',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233032'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1233032';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233032';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233032',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233032
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233032
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233032',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233032
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233032', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233032',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233032',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1233032';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1233032',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1233032';
        
END;
/

/***********************************************************
***** CHARGE 1240922 CJIS_CASE_NUMBER 2025CF2974A47
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF2974A47'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240922',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1240922;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1240922';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240922'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1240922';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240922';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240922',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240922
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240922',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240922
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240922', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240922',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240922',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1240922';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1240922',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1240922';
        
END;
/

/***********************************************************
***** CHARGE 1233555 CJIS_CASE_NUMBER 2025CF3031A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF3031A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233555',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1233555;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1233555';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233555',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233555'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233555';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233555';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233555',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233555
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233555
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233555',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233555
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233555', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233555',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233555',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1233555';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1233555',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1233555';
        
END;
/

/***********************************************************
***** CHARGE 1218433 CJIS_CASE_NUMBER 2025CF663A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF663A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218433',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1218433;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1218433';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218433',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218433'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218433';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218433';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218433',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218433
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218433
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218433',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218433
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218433', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218433',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218433',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1218433';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1218433',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1218433';
        
END;
/

/***********************************************************
***** CHARGE 1218434 CJIS_CASE_NUMBER 2025CF663A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF663A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218434',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1218434;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1218434';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218434',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218434'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218434';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218434';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218434',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218434
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218434
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218434',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218434
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218434', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218434',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218434',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1218434';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1218434',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1218434';
        
END;
/

/***********************************************************
***** CHARGE 1218435 CJIS_CASE_NUMBER 2025CF663A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF663A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218435',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1218435;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1218435';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218435',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218435'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218435';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218435';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218435',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218435
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218435
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218435',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218435
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218435', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218435',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218435',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1218435';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1218435',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1218435';
        
END;
/

/***********************************************************
***** CHARGE 1218502 CJIS_CASE_NUMBER 2025CF676A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF676A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218502',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1218502;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1218502';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218502',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218502'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1218502';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218502';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218502',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218502
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218502
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218502',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218502
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218502', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218502',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218502',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1218502';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1218502',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1218502';
        
END;
/

/***********************************************************
***** CHARGE 1218534 CJIS_CASE_NUMBER 2025CF684A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF684A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218534',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1218534;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1218534';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218534',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218534'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1218534';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1218534';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218534',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218534
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1218534
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218534',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1218534
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1218534', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1218534',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1218534',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1218534';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1218534',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1218534';
        
END;
/

/***********************************************************
***** CHARGE 1220866 CJIS_CASE_NUMBER 2025CF753C2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF753C2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1220866',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1220866;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1220866';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1220866',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1220866'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1220866';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1220866';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1220866',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1220866
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1220866
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1220866',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1220866
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1220866', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1220866',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1220866',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1220866';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1220866',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1220866';
        
END;
/

/***********************************************************
***** CHARGE 1219017 CJIS_CASE_NUMBER 2025CF764A7
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025CF764A7'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1219017',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1219017;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1219017';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1219017',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219017'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '50000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1219017';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1219017';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1219017',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219017
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1219017
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1219017',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1219017
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1219017', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1219017',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1219017',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1219017';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1219017',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1219017';
        
END;
/

/***********************************************************
***** CHARGE 1235124 CJIS_CASE_NUMBER 2025HH1165A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025HH1165A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1235124',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1235124;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1235124';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1235124',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235124'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1235124';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1235124';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1235124',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235124
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1235124
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1235124',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1235124
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1235124', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1235124',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1235124',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1235124';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1235124',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1235124';
        
END;
/

/***********************************************************
***** CHARGE 1228058 CJIS_CASE_NUMBER 2025HV49A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025HV49A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228058',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1228058;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1228058';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228058',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228058'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'V',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1228058';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228058';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228058',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228058
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228058
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228058',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228058
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228058', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228058',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228058',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1228058';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1228058',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1228058';
        
END;
/

/***********************************************************
***** CHARGE 1228651 CJIS_CASE_NUMBER 2025MM1492A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025MM1492A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228651',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1228651;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1228651';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228651',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228651'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1228651';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1228651';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228651',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228651
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1228651
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228651',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1228651
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1228651', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1228651',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1228651',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1228651';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1228651',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1228651';
        
END;
/

/***********************************************************
***** CHARGE 1233278 CJIS_CASE_NUMBER 2025MM1995A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2025MM1995A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233278',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1233278;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1233278';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233278',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233278'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '1000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1233278';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1233278';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233278',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233278
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1233278
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233278',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1233278
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1233278', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1233278',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1233278',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1233278';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1233278',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1233278';
        
END;
/

/***********************************************************
***** CHARGE 1243553 CJIS_CASE_NUMBER 2026CF1038A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1038A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243553',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1243553;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1243553';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243553',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243553'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '1000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1243553';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243553';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243553',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243553
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243553
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243553',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243553
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243553', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243553',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243553',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1243553';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1243553',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1243553';
        
END;
/

/***********************************************************
***** CHARGE 1243552 CJIS_CASE_NUMBER 2026CF1038A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1038A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243552',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1243552;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1243552';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243552',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243552'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '500',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1243552';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243552';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243552',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243552
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243552
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243552',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243552
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243552', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243552',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243552',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1243552';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1243552',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1243552';
        
END;
/

/***********************************************************
***** CHARGE 1244328 CJIS_CASE_NUMBER 2026CF1177A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1177A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244328',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1244328;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1244328';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244328',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244328'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244328';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244328';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244328',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244328
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244328
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244328',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244328
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244328', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244328',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244328',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1244328';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1244328',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1244328';
        
END;
/

/***********************************************************
***** CHARGE 1244515 CJIS_CASE_NUMBER 2026CF1202A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1202A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244515',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1244515;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1244515';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244515',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244515'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1244515';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244515';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244515',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244515
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244515
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244515',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244515
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244515', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244515',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244515',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1244515';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1244515',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1244515';
        
END;
/

/***********************************************************
***** CHARGE 1244897 CJIS_CASE_NUMBER 2026CF1282A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1282A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244897',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1244897;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1244897';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244897',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244897'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '500',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1244897';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244897';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244897',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244897
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244897
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244897',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244897
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244897', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244897',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244897',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1244897';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1244897',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1244897';
        
END;
/

/***********************************************************
***** CHARGE 1244952 CJIS_CASE_NUMBER 2026CF1295A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1295A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244952',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1244952;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1244952';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244952',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244952'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1244952';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244952';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244952',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244952
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244952
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244952',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244952
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244952', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244952',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244952',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1244952';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1244952',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1244952';
        
END;
/

/***********************************************************
***** CHARGE 1244953 CJIS_CASE_NUMBER 2026CF1295A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1295A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244953',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1244953;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1244953';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244953',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244953'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1244953';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244953';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244953',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244953
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244953
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244953',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1244953
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244953', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1244953',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1244953',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1244953';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1244953',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1244953';
        
END;
/

/***********************************************************
***** CHARGE 1245253 CJIS_CASE_NUMBER 2026CF1345A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1345A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245253',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1245253;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1245253';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245253',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245253'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '5000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1245253';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245253';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245253',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245253
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245253
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245253',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245253
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245253', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245253',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245253',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1245253';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1245253',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1245253';
        
END;
/

/***********************************************************
***** CHARGE 1245395 CJIS_CASE_NUMBER 2026CF1367A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1367A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245395',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1245395;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1245395';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245395',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245395'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1245395';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245395';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245395',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245395
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245395
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245395',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245395
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245395', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245395',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245395',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1245395';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1245395',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1245395';
        
END;
/

/***********************************************************
***** CHARGE 1245740 CJIS_CASE_NUMBER 2026CF1437A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1437A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245740',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1245740;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1245740';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245740',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245740'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1245740';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1245740';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245740',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245740
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1245740
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245740',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1245740
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1245740', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1245740',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1245740',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1245740';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1245740',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1245740';
        
END;
/

/***********************************************************
***** CHARGE 1246475 CJIS_CASE_NUMBER 2026CF1556A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1556A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1246475',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1246475;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1246475';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1246475',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246475'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '2500',
    LOCATION = 'BOND'
WHERE CHARGE_ID = '1246475';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246475';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1246475',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246475
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246475
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1246475',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1246475
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246475', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1246475',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1246475',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1246475';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1246475',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1246475';
        
END;
/

/***********************************************************
***** CHARGE 1238908 CJIS_CASE_NUMBER 2026CF166A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF166A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238908',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1238908;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1238908';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238908',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238908'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1238908';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238908';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238908',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238908
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238908
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238908',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1238908
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238908', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238908',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238908',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1238908';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1238908',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1238908';
        
END;
/

/***********************************************************
***** CHARGE 1237872 CJIS_CASE_NUMBER 2026CF166A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF166A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1237872',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1237872;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1237872';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1237872',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1237872'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '25000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1237872';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1237872';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1237872',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237872
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237872
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1237872',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1237872
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1237872', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1237872',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1237872',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1237872';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1237872',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1237872';
        
END;
/

/***********************************************************
***** CHARGE 1247672 CJIS_CASE_NUMBER 2026CF1760A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1760A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247672',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1247672;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1247672';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247672',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247672'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1247672';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247672';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247672',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247672
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247672
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247672',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247672
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247672', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247672',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247672',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1247672';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1247672',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1247672';
        
END;
/

/***********************************************************
***** CHARGE 1248418 CJIS_CASE_NUMBER 2026CF1845A12
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1845A12'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248418',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1248418;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1248418';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248418',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248418'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1248418';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248418';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248418',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248418
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248418
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248418',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248418
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248418', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248418',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248418',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1248418';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1248418',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1248418';
        
END;
/

/***********************************************************
***** CHARGE 1248533 CJIS_CASE_NUMBER 2026CF1864A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1864A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248533',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1248533;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1248533';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248533',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248533'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1248533';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248533';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248533',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248533
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248533
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248533',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248533
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248533', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248533',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248533',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1248533';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1248533',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1248533';
        
END;
/

/***********************************************************
***** CHARGE 1249704 CJIS_CASE_NUMBER 2026CF1953A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1953A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1249704',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1249704;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1249704';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1249704',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249704'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1249704';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249704';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1249704',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249704
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249704
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1249704',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249704
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249704', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1249704',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1249704',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1249704';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1249704',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1249704';
        
END;
/

/***********************************************************
***** CHARGE 1249833 CJIS_CASE_NUMBER 2026CF1973A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1973A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1249833',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1249833;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1249833';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1249833',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249833'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1249833';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249833';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1249833',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249833
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249833
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1249833',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1249833
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249833', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1249833',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1249833',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1249833';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1249833',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1249833';
        
END;
/

/***********************************************************
***** CHARGE 1238612 CJIS_CASE_NUMBER 2026CF298A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF298A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238612',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1238612;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1238612';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238612',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238612'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNP'
WHERE CHARGE_ID = '1238612';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238612';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238612',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238612
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238612
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238612',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1238612
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238612', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238612',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238612',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1238612';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1238612',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1238612';
        
END;
/

/***********************************************************
***** CHARGE 1239546 CJIS_CASE_NUMBER 2026CF473A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF473A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239546',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1239546;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1239546';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239546',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239546'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '1000',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1239546';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239546';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239546',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239546
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239546
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239546',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239546
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239546', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239546',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239546',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1239546';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1239546',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1239546';
        
END;
/

/***********************************************************
***** CHARGE 1239880 CJIS_CASE_NUMBER 2026CF530A5
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF530A5'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239880',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1239880;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1239880';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239880',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239880'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1239880';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239880';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239880',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239880
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239880
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239880',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239880
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239880', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239880',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239880',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1239880';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1239880',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1239880';
        
END;
/

/***********************************************************
***** CHARGE 1240118 CJIS_CASE_NUMBER 2026CF551A11
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF551A11'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240118',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1240118;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1240118';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240118',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240118'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '5000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1240118';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240118';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240118',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240118
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240118
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240118',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240118
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240118', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240118',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240118',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1240118';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1240118',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1240118';
        
END;
/

/***********************************************************
***** CHARGE 1240145 CJIS_CASE_NUMBER 2026CF551A38
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF551A38'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240145',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1240145;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1240145';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240145',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240145'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '1000',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1240145';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240145';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240145',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240145
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240145
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240145',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1240145
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240145', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1240145',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1240145',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1240145';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1240145',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1240145';
        
END;
/

/***********************************************************
***** CHARGE 1242799 CJIS_CASE_NUMBER 2026CF902A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF902A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242799',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1242799;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1242799';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242799',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242799'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDNI'
WHERE CHARGE_ID = '1242799';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242799';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242799',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242799
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242799
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242799',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242799
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242799', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242799',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242799',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1242799';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1242799',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1242799';
        
END;
/

/***********************************************************
***** CHARGE 1242850 CJIS_CASE_NUMBER 2026CF912A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF912A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242850',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1242850;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1242850';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242850',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242850'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1242850';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242850';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242850',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242850
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242850
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242850',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242850
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242850', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242850',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242850',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1242850';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1242850',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1242850';
        
END;
/

/***********************************************************
***** CHARGE 1242851 CJIS_CASE_NUMBER 2026CF912A3
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF912A3'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242851',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1242851;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1242851';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242851',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242851'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '2500',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1242851';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242851';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242851',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242851
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242851
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242851',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1242851
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242851', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1242851',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1242851',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1242851';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1242851',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1242851';
        
END;
/

/***********************************************************
***** CHARGE 1239826 CJIS_CASE_NUMBER 2026CF523A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF523A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239826',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1239826;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1239826';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239826',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239826'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1239826';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1239826';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239826',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239826
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1239826
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239826',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1239826
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1239826', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1239826',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1239826',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1239826';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1239826',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1239826';
        
END;
/

/***********************************************************
***** CHARGE 1238061 CJIS_CASE_NUMBER 2026CT71A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CT71A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238061',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1238061;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1238061';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238061'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1238061';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238061';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238061',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238061',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1238061
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238061', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238061',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1238061';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1238061',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1238061';
        
END;
/

/***********************************************************
***** CHARGE 1238063 CJIS_CASE_NUMBER 2026CT72A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CT72A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238063',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1238063;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1238063';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238063',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238063'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1238063';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238063';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238063',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238063
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238063
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238063',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1238063
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238063', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1238063',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1238063',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1238063';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1238063',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1238063';
        
END;
/

/***********************************************************
***** CHARGE 1248061 CJIS_CASE_NUMBER 2026HH605A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026HH605A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248061',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1248061;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1248061';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248061'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '500',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1248061';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1248061';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248061',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1248061
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248061',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1248061
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1248061', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1248061',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1248061',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1248061';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1248061',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1248061';
        
END;
/

/***********************************************************
***** CHARGE 1247722 CJIS_CASE_NUMBER 2026MM1220A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026MM1220A2'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247722',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1247722;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1247722';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247722',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247722'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1247722';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247722';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247722',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247722
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247722
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247722',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247722
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247722', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247722',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247722',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1247722';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1247722',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1247722';
        
END;
/

/***********************************************************
***** CHARGE 1247892 CJIS_CASE_NUMBER 2026MM1244A4
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026MM1244A4'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247892',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1247892;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1247892';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247892',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247892'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'O',
    BOND_AMT = '',
    LOCATION = 'PTRL'
WHERE CHARGE_ID = '1247892';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247892';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247892',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247892
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1247892
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247892',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1247892
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247892', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1247892',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1247892',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1247892';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1247892',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1247892';
        
END;
/

/***********************************************************
***** CHARGE 1243049 CJIS_CASE_NUMBER 2026MM674A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026MM674A1'
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
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243049',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = 1243049;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
       AND charge_id = '1243049';

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243049',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243049'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1243049';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243049';


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243049',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243049
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1243049
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243049',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

v_inserted_id := JISJDW.cjis_docket_seq.NEXTVAL;

SELECT LISTAGG(TO_CHAR(DOCKET_SEQ), ', ')
     WITHIN GROUP (ORDER BY DOCKET_SEQ) AS charge_list
INTO v_docket_id_str
FROM JISREM.CJIS_DOCKET
WHERE row_state = 'BEFORE'
AND change_action = 'DELETE'
AND CHARGE_ID = 1243049
AND cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243049', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id       => '1243049',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
    p_charge_id    => '1243049',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
            AND charge_id = '1243049';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
            p_charge_id    => '1243049',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d'
        AND charge_id = '1243049';
        
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='CHARGES_PROCESSED'
    WHERE cleanup_id = '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d';
    
    JISREM.LOG
    (
        p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => '7eeb1d2a-d1ae-43e9-99bd-214012d7f20d',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

