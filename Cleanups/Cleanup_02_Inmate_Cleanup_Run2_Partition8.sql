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
    WHERE cleanup_name='Cleanup_02_Inmate_Cleanup_Partition_8';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [Cleanup_02_Inmate_Cleanup_Partition_8] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68','Cleanup_02_Inmate_Cleanup_Partition_8','All Inmates that have status, location, or bond amount changes','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026HH93A1', '1238589', '264162', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM1037A1', '1246157', '274561', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM1037A2', '1246158', '274561', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM1037A3', '1246159', '274561', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM1052A1', '1246309', '109063', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM1220A2', '1247722', '143359', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2025CF1745A1', '1225624', '245327', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM460A1', '1240500', '207281', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM617A1', '1242617', '256641', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM630A1', '1242766', '241406', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM647A1', '1242877', '160575', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM674A1', '1243049', '244656', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM72A1', '1237110', '111326', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM809A1', '1244233', '244656', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('6899570c-2f2d-46f4-aadc-9ffb644d6f68', '2026MM877A1', '1244864', '264536', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [Cleanup_02_Inmate_Cleanup_Partition_8] started'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[15] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[8] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocationBondAmount::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: FaChargeDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CourtCalendarDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: FirstAppearanceDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CustodyStatusDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: ReleaseBondDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1238589 CJIS_CASE_NUMBER 2026HH93A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026HH93A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1238589',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1238589;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1238589';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1238589',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238589'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1238589';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1238589';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238589
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1238589
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1238589
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
and source_row.CHARGE_ID = 1238589
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891388
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 891388
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891388
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 891388
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1238589'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1238589'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1238589
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1238589
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
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
AND CHARGE_ID = 1238589
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1238589', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1238589',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1238589',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1238589';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1238589',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1238589';
END;
/

/***********************************************************
***** CHARGE 1246157 CJIS_CASE_NUMBER 2026MM1037A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM1037A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246157',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1246157;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1246157';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246157',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246157'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1246157';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246157';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246157
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246157
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1246157
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
and source_row.CHARGE_ID = 1246157
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246157'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246157'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246157
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246157
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
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
AND CHARGE_ID = 1246157
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246157', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246157',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246157',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1246157';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1246157',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1246157';
END;
/

/***********************************************************
***** CHARGE 1246158 CJIS_CASE_NUMBER 2026MM1037A2
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM1037A2'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246158',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1246158;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1246158';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246158',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246158'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1246158';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246158';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246158
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246158
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1246158
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
and source_row.CHARGE_ID = 1246158
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246158'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246158'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246158
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246158
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
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
AND CHARGE_ID = 1246158
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246158', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246158',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246158',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1246158';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1246158',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1246158';
END;
/

/***********************************************************
***** CHARGE 1246159 CJIS_CASE_NUMBER 2026MM1037A3
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM1037A3'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246159',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1246159;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1246159';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246159',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246159'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1246159';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246159';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246159
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246159
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1246159
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
and source_row.CHARGE_ID = 1246159
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895839
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246159'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246159'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246159
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246159
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
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
AND CHARGE_ID = 1246159
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246159', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246159',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246159',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1246159';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1246159',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1246159';
END;
/

/***********************************************************
***** CHARGE 1246309 CJIS_CASE_NUMBER 2026MM1052A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM1052A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246309',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1246309;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1246309';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246309',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246309'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1246309';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1246309';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246309
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1246309
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1246309
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
and source_row.CHARGE_ID = 1246309
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895919
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895919
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895919
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895919
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246309'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1246309'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246309
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1246309
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
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
AND CHARGE_ID = 1246309
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1246309', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1246309',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1246309',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1246309';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1246309',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1246309';
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
   SAVEPOINT before_record;
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM1220A2'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1247722',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1247722;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1247722';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1247722',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1247722';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1247722
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
and source_row.CHARGE_ID = 1247722
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 896960
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 896960
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 896960
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 896960
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1247722'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1247722'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1247722
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1247722
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
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
AND CHARGE_ID = 1247722
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1247722', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1247722',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1247722',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1247722';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1247722',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1247722';
END;
/

/***********************************************************
***** CHARGE 1225624 CJIS_CASE_NUMBER 2025CF1745A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2025CF1745A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1225624',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1225624;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1225624';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1225624',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225624'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'R',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1225624';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1225624';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225624
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1225624
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1225624
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
and source_row.CHARGE_ID = 1225624
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 881401
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 881401
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 881401
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 881401
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1225624'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1225624'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1225624
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1225624
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
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
AND CHARGE_ID = 1225624
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1225624', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1225624',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1225624',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1225624';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1225624',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1225624';
END;
/

/***********************************************************
***** CHARGE 1240500 CJIS_CASE_NUMBER 2026MM460A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM460A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1240500',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1240500;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1240500';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1240500',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240500'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1240500';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1240500';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240500
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1240500
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1240500
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
and source_row.CHARGE_ID = 1240500
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 892569
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 892569
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 892569
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 892569
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1240500'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1240500'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1240500
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1240500
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
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
AND CHARGE_ID = 1240500
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1240500', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1240500',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1240500',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1240500';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1240500',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1240500';
END;
/

/***********************************************************
***** CHARGE 1242617 CJIS_CASE_NUMBER 2026MM617A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM617A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242617',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1242617;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1242617';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242617',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242617'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'CLRK'
WHERE CHARGE_ID = '1242617';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242617';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242617
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242617
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1242617
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
and source_row.CHARGE_ID = 1242617
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893526
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893526
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893526
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893526
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1242617'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1242617'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1242617
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1242617
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
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
AND CHARGE_ID = 1242617
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242617', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242617',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242617',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1242617';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1242617',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1242617';
END;
/

/***********************************************************
***** CHARGE 1242766 CJIS_CASE_NUMBER 2026MM630A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM630A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242766',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1242766;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1242766';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242766',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242766'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1242766';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242766';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242766
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242766
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1242766
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
and source_row.CHARGE_ID = 1242766
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893612
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893612
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893612
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893612
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1242766'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1242766'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1242766
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1242766
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
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
AND CHARGE_ID = 1242766
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242766', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242766',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242766',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1242766';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1242766',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1242766';
END;
/

/***********************************************************
***** CHARGE 1242877 CJIS_CASE_NUMBER 2026MM647A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM647A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242877',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1242877;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1242877';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242877',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242877'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'LCJ'
WHERE CHARGE_ID = '1242877';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1242877';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242877
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1242877
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1242877
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
and source_row.CHARGE_ID = 1242877
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893690
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893690
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893690
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1242877'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1242877'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1242877
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1242877
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
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
AND CHARGE_ID = 1242877
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1242877', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1242877',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1242877',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1242877';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1242877',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1242877';
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
   SAVEPOINT before_record;
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM674A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1243049',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1243049;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1243049';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1243049',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1243049';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1243049
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
and source_row.CHARGE_ID = 1243049
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893804
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 893804
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893804
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 893804
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1243049'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1243049'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1243049
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1243049
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
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
AND CHARGE_ID = 1243049
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1243049', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1243049',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1243049',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1243049';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1243049',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1243049';
END;
/

/***********************************************************
***** CHARGE 1237110 CJIS_CASE_NUMBER 2026MM72A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM72A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1237110',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1237110;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1237110';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1237110',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1237110'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1237110';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1237110';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1237110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1237110
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
and source_row.CHARGE_ID = 1237110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 890694
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 890694
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 890694
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 890694
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1237110'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1237110'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1237110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1237110
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
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
AND CHARGE_ID = 1237110
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1237110', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1237110',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1237110',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1237110';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1237110',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1237110';
END;
/

/***********************************************************
***** CHARGE 1244233 CJIS_CASE_NUMBER 2026MM809A1
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
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM809A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1244233',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1244233;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1244233';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1244233',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244233'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OREC'
WHERE CHARGE_ID = '1244233';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244233';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244233
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1244233
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1244233
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
and source_row.CHARGE_ID = 1244233
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 894556
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 894556
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 894556
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 894556
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1244233'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1244233'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1244233
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1244233
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
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
AND CHARGE_ID = 1244233
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244233', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244233',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1244233',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1244233';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1244233',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1244233';
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
   SAVEPOINT before_record;
   
IF v_is_valid = 1 THEN
SELECT COUNT(*)
INTO v_count
FROM JISJDW.audit_trail 
WHERE activity_date_time > TO_DATE('2026-08-18 00:00','YYYY-MM-DD HH24:MI')
AND cjis_case_number = '2026MM877A1'
AND (activity_user_id NOT IN ('JISJDW', 'SYSTEMA', 'PNX2JIS')
    OR activity_user_id is null
);
       
IF v_count <> 0 THEN
    v_is_valid := 0;
    v_validation_error := 'Human activity found in Audit Trail';
END IF;

IF v_is_valid <> 1 THEN
    JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1244864',
    p_step_name  => 'NoHumanActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = 1244864;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
       AND charge_id = '1244864';

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1244864',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244864'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDTS'
WHERE CHARGE_ID = '1244864';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1244864';


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
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
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
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
and source_row.CHARGE_ID = 1244864
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
and source_row.CHARGE_ID = 1244864
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895001
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 895001
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 895001
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1244864'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1244864'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1244864
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1244864
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
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
AND CHARGE_ID = 1244864
AND cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1244864', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO ADMINISTRATIVE ORDER 2026-__ ENTERED 09/__/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || '6899570c-2f2d-46f4-aadc-9ffb644d6f68' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id       => '1244864',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
    p_charge_id    => '1244864',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
            AND charge_id = '1244864';

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK TO before_record;
        
        JISREM.LOG
        (
            p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
            p_charge_id    => '1244864',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = '6899570c-2f2d-46f4-aadc-9ffb644d6f68'
        AND charge_id = '1244864';
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
        p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
        p_step_name  => 'TRANSACTION',
        p_message    => 'Cleanup transaction committed'
    );
    
 ELSE
    ROLLBACK;
    
    JISREM.LOG
    (
        p_cleanup_id => '6899570c-2f2d-46f4-aadc-9ffb644d6f68',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true transaction rolled back'
    );
 END IF;
END;
/

