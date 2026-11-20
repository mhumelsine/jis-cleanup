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
    WHERE cleanup_name='20261119_073102_Cleanup_01_GroceryStoreRun_1';
    
    IF v_existing>0 THEN 
         RAISE_APPLICATION_ERROR(-20002,'Cleanup [20261119_073102_Cleanup_01_GroceryStoreRun_1] already exists'); 
    END IF;
    
    
    INSERT INTO JISREM.CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
    VALUES('c873e585-e99d-4035-86c2-84c84c2d6991','20261119_073102_Cleanup_01_GroceryStoreRun_1','Grocery store run; Initial cleanup of cases with only invalid system activity for defendants already released.','JIS','CREATED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c873e585-e99d-4035-86c2-84c84c2d6991', '2026CF1929A2', '1249492', '282146', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c873e585-e99d-4035-86c2-84c84c2d6991', '2026CF1929A1', '1249491', '282146', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c873e585-e99d-4035-86c2-84c84c2d6991', '2024CF2517A1', '1207491', '180849', 'QUEUED');

INSERT INTO JISREM.CLEANUP_CASE_QUEUE(cleanup_id, case_id, charge_id, spn_id, status) 
VALUES('c873e585-e99d-4035-86c2-84c84c2d6991', '2021CF2857A1', '1143125', '213498', 'QUEUED');

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup [20261119_073102_Cleanup_01_GroceryStoreRun_1] started'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[4] case(s) will be affected'
);

COMMIT;
END;
/

BEGIN
JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => '[8] changes will be applied'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: RestoreStatusLocationBondAmount::UPDATE'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CjisDocketDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: FaChargeDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CourtCalendarDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: FirstAppearanceDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: CustodyStatusDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: ReleaseBondDelete::DELETE'
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_step_name  => 'INITIALIZATION',
    p_message    => 'Cleanup agent registered: InsertCleanupDocketEntry::INSERT'
);

END;
/

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/***********************************************************
***** CHARGE 1249492 CJIS_CASE_NUMBER 2026CF1929A2
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1929A2'
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
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1249492',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = 1249492;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
       AND charge_id = '1249492';

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1249492',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249492'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1249492';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249492';


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1249492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1249492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1249492'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1249492'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1249492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1249492
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
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
AND CHARGE_ID = 1249492
AND cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249492', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c873e585-e99d-4035-86c2-84c84c2d6991' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249492',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1249492',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
            AND charge_id = '1249492';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
            p_charge_id    => '1249492',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = '1249492';
        
END;
/

/***********************************************************
***** CHARGE 1249491 CJIS_CASE_NUMBER 2026CF1929A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2026CF1929A1'
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
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1249491',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = 1249491;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
       AND charge_id = '1249491';

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1249491',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249491'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'OTJA'
WHERE CHARGE_ID = '1249491';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1249491';


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1249491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1249491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1249491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 897816
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1249491'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1249491'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1249491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1249491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
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
AND CHARGE_ID = 1249491
AND cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1249491', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c873e585-e99d-4035-86c2-84c84c2d6991' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1249491',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1249491',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
            AND charge_id = '1249491';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
            p_charge_id    => '1249491',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = '1249491';
        
END;
/

/***********************************************************
***** CHARGE 1207491 CJIS_CASE_NUMBER 2024CF2517A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2024CF2517A1'
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
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1207491',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = 1207491;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
       AND charge_id = '1207491';

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1207491',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207491'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPT'
WHERE CHARGE_ID = '1207491';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1207491';


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1207491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1207491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1207491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 870350
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 870350
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 870350
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 870350
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1207491'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1207491'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1207491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1207491
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
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
AND CHARGE_ID = 1207491
AND cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1207491', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c873e585-e99d-4035-86c2-84c84c2d6991' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1207491',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1207491',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
            AND charge_id = '1207491';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
            p_charge_id    => '1207491',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = '1207491';
        
END;
/

/***********************************************************
***** CHARGE 1143125 CJIS_CASE_NUMBER 2021CF2857A1
***********************************************************/

DECLARE
    v_is_valid PLS_INTEGER := 1;
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
AND cjis_case_number = '2021CF2857A1'
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
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1143125',
    p_step_name  => 'NoHumanChargeActivity',
    p_message    => 'Error: ' || v_validation_error
);

   
   UPDATE
        JISREM.CLEANUP_CASE_QUEUE
    SET
        status = 'VALIDATION_FAILED',
        message = v_validation_error
    WHERE
        cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = 1143125;
   
    RETURN;
END IF;

END IF;

       UPDATE JISREM.CLEANUP_CASE_QUEUE
       SET status = 'VALIDATED',
       message = 'All validations passed'
       WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
       AND charge_id = '1143125';

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1143125',
    p_step_name  => 'CLEANUP',
    p_message    => 'Starting cleanup for case'
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'BEFORE'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143125'
;

UPDATE JISJDW.CHARGE
SET STATUS = 'D',
    BOND_AMT = '',
    LOCATION = 'RLSDPB'
WHERE CHARGE_ID = '1143125';


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'UPDATE',
    'AFTER'
FROM JISJDW.CHARGE source_row
WHERE CHARGE_ID = '1143125';


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
    p_step_name     => 'RestoreStatusLocationBondAmount__UPDATE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143125
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CJIS_DOCKET source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
    and d.CJIS_DOCKET_ID = source_row.CJIS_DOCKET_ID
)
and source_row.CHARGE_ID = 1143125
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
    p_step_name     => 'CjisDocketDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FA_CHARGE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1143125
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FA_CHARGE source_row
WHERE exists (
    select CJIS_DOCKET_ID
    from JISJDW.CHARGE c
    inner join JISJDW.V_PNX2JIS_BAD_DKT_v2 d
    on c.CHARGE_ID = d.CHARGE_ID
    where c.CHARGE_ID = source_row.CHARGE_ID
)
and source_row.CHARGE_ID = 1143125
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
    p_step_name     => 'FaChargeDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.COURT_CALENDAR
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 828874
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.COURT_CALENDAR source_row
WHERE source_row.CASE_DEFENDANT_ID = 828874
AND source_row.CALENDAR_TYPE = 'FAP'
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
    p_step_name     => 'CourtCalendarDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.FIRST_APPEARANCE
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 828874
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.FIRST_APPEARANCE source_row
WHERE source_row.CASE_DEFENDANT_ID = 828874
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
    p_step_name     => 'FirstAppearanceDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.CUSTODY_STATUS
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1143125'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.CUSTODY_STATUS source_row
WHERE EXISTS (
    SELECT *
    FROM JISREM.CJIS_DOCKET d
    WHERE d.CHARGE_ID = '1143125'
    AND d.CHARGE_ID = source_row.CHARGE_ID
    AND d.row_state = 'BEFORE'
    AND d.cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
)
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
    p_step_name     => 'CustodyStatusDelete__DELETE',
    p_affected_rows => v_count
);

--SNAPSHOT BEFORE
INSERT INTO JISREM.RELEASE_BOND
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'DELETE',
    'BEFORE'
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1143125
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA')
;

DELETE 
FROM JISJDW.RELEASE_BOND source_row
WHERE source_row.CHARGE_ID = 1143125
AND source_row.CREATE_DATE_TIME >= to_date('2026-08-18','YYYY-MM-DD')
AND NVL(UPPER(TRIM(source_row.create_user_id)),'~') IN ('JISJDW','PNX2JIS','SYSTEMA');


 v_count := SQL%ROWCOUNT;
 


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
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
AND CHARGE_ID = 1143125
AND cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991';

--ensure at least 1 docket was deleted
IF v_docket_id_str IS NOT NULL THEN
         
    INSERT INTO JISJDW.cjis_docket (cjis_docket_id, charge_id, docket_date, received_date, docket_code, docket_free_text)
    VALUES (v_inserted_id, '1143125', SYSDATE,SYSDATE, 'APPF',
           'PURSUANT TO OMNIBUS ORDER ON CASE CHANGES/CORRECTIONS ENTERED 09/25/2026, REMOVED ERRONEOUS SYSTEM-GENERATED '||
           'DOCKET ENTRIES SEQ [' || v_docket_id_str || '] ' ||
           'CREATED 08/18-08/21/2026 DURING THE COUNTY''S UPGRADE TO THE LEGACY JIS SYSTEM.'||
           ' [CASE STATUS RESTORED TO STATUS AS OF 08/17/2026.] NO OTHER DOCKET ENTRY ALTERED.'||
           ' JIS RECORD CORRECTION, BATCH ' || 'c873e585-e99d-4035-86c2-84c84c2d6991' );
   
     v_count := SQL%ROWCOUNT;
END IF;


 v_count := SQL%ROWCOUNT;
 
--SNAPSHOT AFTER
INSERT INTO JISREM.CJIS_DOCKET
SELECT
    source_row.*,
    'c873e585-e99d-4035-86c2-84c84c2d6991',
    'INSERT',
    'AFTER'
FROM JISJDW.CJIS_DOCKET source_row
WHERE CJIS_DOCKET_ID = v_inserted_id;


JISREM.LOG
(
    p_cleanup_id    => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id       => '1143125',
    p_step_name     => 'InsertCleanupDocketEntry__INSERT',
    p_affected_rows => v_count
);

JISREM.LOG
(
    p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
    p_charge_id    => '1143125',
    p_step_name  => 'CLEANUP',
    p_message    => 'Completed cleanup for case'
);

        UPDATE
            JISREM.CLEANUP_CASE_QUEUE
        SET
            status = 'PROCESSED'
        WHERE
            cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
            AND charge_id = '1143125';

   IF 0 = 0 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SUBSTR(SQLERRM, 1, 512);

        ROLLBACK;
        
        JISREM.LOG
        (
            p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
            p_charge_id    => '1143125',
            p_step_name  => 'EXCEPTION',
            p_message    => v_error_message
        );
        
        UPDATE JISREM.CLEANUP_CASE_QUEUE
        SET 
            status = 'PROCESSING_FAILED',
            message = v_error_message
        WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991'
        AND charge_id = '1143125';
        
END;
/

BEGIN
 IF 0 = 0 THEN
    UPDATE JISREM.CLEANUP 
    SET 
        status='CHARGES_PROCESSED'
    WHERE cleanup_id = 'c873e585-e99d-4035-86c2-84c84c2d6991';
    
    JISREM.LOG
    (
        p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
        p_step_name  => 'TRANSACTION',
        p_message    => 'All charges processed'
    );
    
 ELSE
    JISREM.LOG
    (
        p_cleanup_id => 'c873e585-e99d-4035-86c2-84c84c2d6991',
        p_step_name  => 'TRANSACTION',
        p_message    => 'WHAT-IF was true all charges rolled back'
    );
 END IF;
END;
/

