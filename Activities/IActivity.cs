using System.Text;

namespace JisCleanup.Activities;

public interface IActivity
{
    void Build(StringBuilder builder);
}

public interface IDeclareActivity : IActivity
{
    void BuildDeclares(BlockDeclarations declarations);
}