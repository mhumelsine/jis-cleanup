using System.Text;

namespace JisCleanup.Activities;

public class CreateLoggingInfrastructureActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine(
            """
            WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
            SET SERVEROUTPUT ON
            SET VERIFY OFF

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
                            cleanup_id      NUMBER         NOT NULL,
                            cleanup_name    VARCHAR2(100)  NOT NULL,
                            cleanup_date    DATE DEFAULT SYSDATE NOT NULL,
                            description     VARCHAR2(1000) NOT NULL,
                            requested_by    VARCHAR2(128),
                            status          VARCHAR2(20) NOT NULL,

                            CONSTRAINT CLEANUP_PK
                                PRIMARY KEY (cleanup_id),

                            CONSTRAINT CLEANUP_NAME_UQ
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
                            cleanup_id NUMBER NOT NULL,
                            case_id    NUMBER NOT NULL,
                            status     VARCHAR2(50) NOT NULL,
                            message    VARCHAR2(512) NULL,    

                            CONSTRAINT CLN_CASE_Q_PK
                                PRIMARY KEY (cleanup_id, case_id),

                            CONSTRAINT CLN_CASE_Q_FK
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
                            cleanup_id    NUMBER       NOT NULL,
                            case_id       NUMBER       NULL,
                            log_sequence  NUMBER       NOT NULL,
                            logged_at     DATE DEFAULT SYSDATE NOT NULL,
                            step_name     VARCHAR2(50) NULL,
                            message       VARCHAR2(512) NULL,
                            affected_rows NUMBER,

                            CONSTRAINT CLEANUP_LOG_PK
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
            
            
            
            """);
    }
}