using System.Text;
using JisCleanup.Validations;

namespace JisCleanup.Activities;

public class ValidationsActivity(Charge charge, IValidation[] validations) : IActivity
{
    public void Build(StringBuilder builder)
    { 
        foreach (var validation in validations)
        {
            validation.Validation(builder, charge);
        }
        
        builder.AppendLine(
            $"""
             
                    UPDATE JISREM.CLEANUP_CASE_QUEUE
                    SET status = 'VALIDATED',
                    message = 'All validations passed'
                    WHERE cleanup_id = :CLEANUP_ID
                    AND charge_id = '{charge.ChargeId}';

             """);
        
    }
}