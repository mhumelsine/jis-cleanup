using System.Text;

namespace JisCleanup.Activities;

public class BeginTransactionActivity : IActivity
{
    public void Build(StringBuilder builder)
    {
        builder.AppendLine("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;");
    }
}