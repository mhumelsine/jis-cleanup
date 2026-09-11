// using System.Text;
// using JisCleanup.Validations;
//
// namespace JisCleanup;
//
// public abstract class Cleanup
// {
//     public string CleanupConfigurationFileName { get; protected set; }
//     public string OutputfileName { get; protected set; }
//     public string Name { get; protected set; }
//     public string Description { get; protected set; }
//     public string RequestedBy { get; protected set; }
//     public int[] CaseIds { get; protected set; } = [];
//     public TableChange[] Changes { get; protected set; }
//     public IValidation[] Validations { get; set; }
//
//     protected Cleanup()
//     {
//         CleanupConfigurationFileName = $"{AppContext.BaseDirectory}/Cleanups/{GetType().Name}.yaml";
//         OutputfileName = $"{AppContext.BaseDirectory}/Cleanups/{GetType().Name}.sql";
//
//         LoadFromYaml();
//     }
//
//     private void LoadFromYaml()
//     {
//         //TODO:
//         Name = "TEST CLEANUP";
//         Description = "LONG ASDASKLDS";
//         CaseIds = [123321,54354,25432,78876];
//     }
//
//     private string LogChangeNames(TableChange change) => "";
//
//     private string Build()
//     {   
//         var builder = new StringBuilder();
//
//         foreach (var change in Changes)
//         {
//             builder.AppendLine(Log($"Cleanup agent registered: {change}"));
//         }
//
//         builder.AppendLine(ValidateCaseChangesLoop());
//         builder.AppendLine(ApplyCaseChangesLoop());
//         
//         builder.AppendLine(Commit());
//
//         return builder.ToString();
//     }
//
//     public void Create() =>
//         File.WriteAllText(OutputfileName, Build());
//     
//     
//
// //     protected string InitializeCleanup()
// //         => $"""
// //            WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
// //            SET SERVEROUTPUT ON
// //            SET VERIFY OFF
// //            
// //            DEFINE WHAT_IF='&1'
// //            VARIABLE CLEANUP_ID NUMBER
// //            
// //            DECLARE
// //                v_existing NUMBER; 
// //                v_what_if NUMBER;
// //            BEGIN
// //                v_what_if:=TO_NUMBER('&&WHAT_IF');
// //                
// //                IF v_what_if NOT IN (0,1) THEN 
// //                     RAISE_APPLICATION_ERROR(-20001,'WHAT_IF must be 0 or 1'); END IF;
// //                
// //                SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
// //                
// //                SELECT COUNT(*) 
// //                INTO v_existing 
// //                FROM JISJDW.Z__CLEANUP 
// //                WHERE cleanup_name='{Name}';
// //                
// //                IF v_existing>0 THEN 
// //                     RAISE_APPLICATION_ERROR(-20002,'Cleanup [{Name}] already exists'); 
// //                END IF;
// //                
// //                SELECT JISJDW.Z__CLEANUP_SEQ.NEXTVAL 
// //                INTO :CLEANUP_ID 
// //                FROM dual;
// //                
// //                INSERT INTO JISJDW.Z__CLEANUP(cleanup_id,cleanup_name,description,requested_by,status)
// //                VALUES(:CLEANUP_ID,'{Name}','{Description}','{RequestedBy}','CREATED');
// //                
// //                {LoadCasesIntoQueue()}
// //            END;
// //            /
// //            
// //            """;
//
//     // protected string LoadCasesIntoQueue()
//     // {
//     //     var builder = new StringBuilder();
//     //
//     //     foreach (var caseId in CaseIds)
//     //     {
//     //         builder.AppendLine(
//     //             $"  INSERT INTO JISJDW.Z__CLEANUP_CASE_QUEUE(cleanup_id,case_id. status) VALUES(:CLEANUP_ID,{caseId}, 'QUEUED');");
//     //     }
//     //
//     //     return builder.ToString();
//     // }
//
// //     protected string ValidateCaseChangesLoop()
// //         => $"""
// //             DECLARE
// //                 v_case_id JISJDW.Z__CLEANUP_CASE_QUEUE.case_id%TYPE;
// //                 v_is_valid PLS_INTEGER := 0;
// //                 v_validation_error := NULL;
// //
// //                 CURSOR c_cases IS
// //                     SELECT
// //                         case_id
// //                     FROM
// //                         JISJDW.Z__CLEANUP_CASE_QUEUE
// //                     WHERE
// //                         cleanup_id = :CLEANUP_ID
// //                         AND status = 'QUEUED'
// //                     ORDER BY
// //                         case_id;
// //
// //             BEGIN
// //
// //                 FOR r_case IN c_cases
// //                 LOOP
// //                     v_case_id := r_case.case_id;
// //                     v_is_valid := 0;
// //                     v_validation_error := ''; 
// //
// //                      {LogCase("Starting validation for case")}
// //                      {ValidateCaseChangesLoop()}
// //                      {LogCase("Completed validation for case")}
// //
// //                 END LOOP;
// //             END;
// //             /
// //
// //             """;
//
//     
// //     protected string ApplyCaseChangesLoop()
// //         => $"""
// //            DECLARE
// //
// //                v_case_id JISJDW.Z__CLEANUP_CASE_QUEUE.case_id%TYPE;
// //
// //                CURSOR c_cases IS
// //                    SELECT
// //                        case_id
// //                    FROM
// //                        JISJDW.Z__CLEANUP_CASE_QUEUE
// //                    WHERE
// //                        cleanup_id = :CLEANUP_ID
// //                        AND status = 'VALIDATED'
// //                    ORDER BY
// //                        case_id;
// //
// //            BEGIN
// //
// //                FOR r_case IN c_cases
// //                LOOP
// //                    v_case_id := r_case.case_id;
// //
// //                     {LogCase("Starting cleanup for case")}
// //                     {ApplyChanges()}
// //                     {LogCase("Completed cleanup for case")}
// //                    
// //                    UPDATE
// //                        JISJDW.Z__CLEANUP_CASE_QUEUE
// //                    SET
// //                        status = 'PROCESSED'
// //                    WHERE
// //                        cleanup_id = :CLEANUP_ID
// //                        AND case_id = v_case_id;
// //
// //                END LOOP;
// //            
// //            END;
// //            /
// //            
// //            """;
// //
// //     protected string ApplyChanges()
// //     {
// //         var builder = new StringBuilder();
// //
// //         foreach (var change in Changes)
// //         {
// //             builder.AppendLine(change.BeforeSnapshot());
// //             builder.AppendLine(change.Apply());
// //             builder.AppendLine(change.AfterSnapshot());
// //             builder.AppendLine(change.LogOperation());
// //         }
// //
// //         return builder.ToString();
// //     }
//     
//     
//
//     
//     
//     // protected string Commit()
//     //     => """
//     //        BEGIN
//     //         IF TO_NUMBER('&&WHAT_IF')=1 THEN
//     //            ROLLBACK;
//     //            DBMS_OUTPUT.PUT_LINE('WHAT-IF completed. All changes rolled back.');
//     //         ELSE
//     //             UPDATE JISJDW.Z__CLEANUP 
//     //             SET 
//     //                 status='COMPLETED',
//     //                 executed_date=SYSDATE 
//     //             WHERE cleanup_id=:CLEANUP_ID;
//     //             COMMIT;
//     //             DBMS_OUTPUT.PUT_LINE('Cleanup committed.');
//     //         END IF;
//     //        END;
//     //        /
//     //        UNDEFINE WHAT_IF
//     //        EXIT SUCCESS
//     //        """;
//
//
//     
// }