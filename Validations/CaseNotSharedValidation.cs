namespace JisCleanup.Validations;

public class CaseNotSharedValidation : IValidation
{
    public string Validation()
        => $"""
           SELECT COUNT(*)
           INTO v_count
           FROM JISJDW.CASE_DEFENDANT cd
           WHERE cd.case_id = v_case_id
           AND cd.case_defendant_id <> v_case_defendant_id; 

           {IValidation.Check("CJIS_CASE is shared by another CASE_DEFENDANT")}
           
           """;
}