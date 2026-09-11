using System.Text;

namespace JisCleanup.Activities;

public class CreateLoggingInfrastructureActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
            SET SERVEROUTPUT ON;

            DECLARE
                v_object_count PLS_INTEGER;
            BEGIN
                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLEANUP
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_TABLES
                WHERE owner = 'JISJDW'
                  AND table_name = 'Z__CLEANUP';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE TABLE JISJDW.Z__CLEANUP
                        (
                            cleanup_id      NUMBER         NOT NULL,
                            cleanup_name    VARCHAR2(100)  NOT NULL,
                            cleanup_date    DATE DEFAULT SYSDATE NOT NULL,
                            description     VARCHAR2(1000) NOT NULL,
                            requested_by    VARCHAR2(128),
                            status          VARCHAR2(20) DEFAULT 'CREATED' NOT NULL,
                            validated_date  DATE,
                            executed_date   DATE,

                            CONSTRAINT Z__CLEANUP_PK
                                PRIMARY KEY (cleanup_id),

                            CONSTRAINT Z__CLEANUP_NAME_UQ
                                UNIQUE (cleanup_name),

                            CONSTRAINT Z__CLEANUP_STATUS_CK
                                CHECK
                                (
                                    status IN
                                    (
                                        'CREATED',
                                        'QUEUED',
                                        'VALIDATED',
                                        'COMPLETED',
                                        'FAILED',
                                        'VALIDATION_FAILED'
                                    )
                                )
                        )
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLEANUP');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLEANUP already exists');
                END IF;

                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLEANUP_SEQ
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_SEQUENCES
                WHERE sequence_owner = 'JISJDW'
                  AND sequence_name = 'Z__CLEANUP_SEQ';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE SEQUENCE JISJDW.Z__CLEANUP_SEQ
                            START WITH 1
                            INCREMENT BY 1
                            NOCACHE
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLEANUP_SEQ');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLEANUP_SEQ already exists');
                END IF;

                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLEANUP_CASE_QUEUE
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_TABLES
                WHERE owner = 'JISJDW'
                  AND table_name = 'Z__CLEANUP_CASE_QUEUE';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE TABLE JISJDW.Z__CLEANUP_CASE_QUEUE
                        (
                            cleanup_id NUMBER NOT NULL,
                            case_id    NUMBER NOT NULL,

                            CONSTRAINT Z__CLN_CASE_Q_PK
                                PRIMARY KEY (cleanup_id, case_id),

                            CONSTRAINT Z__CLN_CASE_Q_FK
                                FOREIGN KEY (cleanup_id)
                                REFERENCES JISJDW.Z__CLEANUP (cleanup_id)
                        )
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLEANUP_CASE_QUEUE');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLEANUP_CASE_QUEUE already exists');
                END IF;

                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLEANUP_VALIDATION
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_TABLES
                WHERE owner = 'JISJDW'
                  AND table_name = 'Z__CLEANUP_VALIDATION';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE TABLE JISJDW.Z__CLEANUP_VALIDATION
                        (
                            cleanup_id NUMBER NOT NULL,
                            case_id    NUMBER NOT NULL,
                            validated  NUMBER(1) DEFAULT 0 NOT NULL,

                            CONSTRAINT Z__CLN_VALID_PK
                                PRIMARY KEY (cleanup_id, case_id),

                            CONSTRAINT Z__CLN_VALID_CK
                                CHECK (validated IN (0, 1)),

                            CONSTRAINT Z__CLN_VALID_FK
                                FOREIGN KEY (cleanup_id, case_id)
                                REFERENCES JISJDW.Z__CLEANUP_CASE_QUEUE
                                    (cleanup_id, case_id)
                        )
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLEANUP_VALIDATION');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLEANUP_VALIDATION already exists');
                END IF;

                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLEANUP_VALIDATION_DETAIL
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_TABLES
                WHERE owner = 'JISJDW'
                  AND table_name = 'Z__CLEANUP_VALIDATION_DETAIL';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE TABLE JISJDW.Z__CLEANUP_VALIDATION_DETAIL
                        (
                            cleanup_id      NUMBER         NOT NULL,
                            case_id         NUMBER         NOT NULL,
                            validation_code VARCHAR2(50)   NOT NULL,
                            failed_count    NUMBER         NOT NULL,
                            description     VARCHAR2(1000) NOT NULL,

                            CONSTRAINT Z__CLN_VAL_DTL_FK
                                FOREIGN KEY (cleanup_id, case_id)
                                REFERENCES JISJDW.Z__CLEANUP_CASE_QUEUE
                                    (cleanup_id, case_id)
                        )
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLEANUP_VALIDATION_DETAIL');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLEANUP_VALIDATION_DETAIL already exists');
                END IF;

                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLN_VAL_DTL_IX
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_INDEXES
                WHERE owner = 'JISJDW'
                  AND index_name = 'Z__CLN_VAL_DTL_IX';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE INDEX JISJDW.Z__CLN_VAL_DTL_IX
                            ON JISJDW.Z__CLEANUP_VALIDATION_DETAIL
                                (cleanup_id, case_id)
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLN_VAL_DTL_IX');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLN_VAL_DTL_IX already exists');
                END IF;

                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLEANUP_LOG
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_TABLES
                WHERE owner = 'JISJDW'
                  AND table_name = 'Z__CLEANUP_LOG';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE TABLE JISJDW.Z__CLEANUP_LOG
                        (
                            cleanup_id    NUMBER       NOT NULL,
                            case_id       NUMBER       NOT NULL,
                            log_sequence  NUMBER       NOT NULL,
                            logged_at     DATE DEFAULT SYSDATE NOT NULL,
                            step_code     VARCHAR2(50) NOT NULL,
                            affected_rows NUMBER,

                            CONSTRAINT Z__CLEANUP_LOG_PK
                                PRIMARY KEY
                                    (cleanup_id, case_id, log_sequence),

                            CONSTRAINT Z__CLEANUP_LOG_CASE_FK
                                FOREIGN KEY (cleanup_id, case_id)
                                REFERENCES JISJDW.Z__CLEANUP_CASE_QUEUE
                                    (cleanup_id, case_id)
                        )
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLEANUP_LOG');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLEANUP_LOG already exists');
                END IF;

                ----------------------------------------------------------------------------
                -- JISJDW.Z__CLEANUP_LOG_SEQ
                ----------------------------------------------------------------------------
                SELECT COUNT(*)
                INTO v_object_count
                FROM ALL_SEQUENCES
                WHERE sequence_owner = 'JISJDW'
                  AND sequence_name = 'Z__CLEANUP_LOG_SEQ';

                IF v_object_count = 0 THEN
                    EXECUTE IMMEDIATE q'~
                        CREATE SEQUENCE JISJDW.Z__CLEANUP_LOG_SEQ
                            START WITH 1
                            INCREMENT BY 1
                            NOCACHE
                    ~';

                    DBMS_OUTPUT.PUT_LINE('Created JISJDW.Z__CLEANUP_LOG_SEQ');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('JISJDW.Z__CLEANUP_LOG_SEQ already exists');
                END IF;
            END;
            /

            """);
    }
}