using System.Text;

namespace JisCleanup.Activities;

public class EnsureSnapshotTableExistActivity(TableChange[] changes) : IActivity
{
    public void Build(StringBuilder builder)
    {
        foreach (var change in changes)
        {
            builder.AppendLine(change.CreateSnapshotTableIfMissing());
        }
    }
}