namespace JisCleanup;

public class InsertTableChange : TableChange
{
    public InsertTableChange(TableDefinition tableDefinition) 
        : base(tableDefinition, ActionType.Insert)
    {
    }

    public override string WherePredicate { get; }

    public override string BeforeSnapshot()
    {
        return base.BeforeSnapshot();
    }

    public override string AfterSnapshot()
    {
        throw new NotImplementedException();
    }

    public override string Apply()
    {
        throw new NotImplementedException();
    }
}