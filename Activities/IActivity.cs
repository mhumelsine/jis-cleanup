using System.Text;

namespace JisCleanup.Activities;

public interface IActivity
{
    void Build(StringBuilder builder);
}