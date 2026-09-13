namespace JisCleanup;

public class InsertTableChange : TableChange
{
    public InsertTableChange(TableDefinition tableDefinition) 
        : base(tableDefinition, ActionType.Insert)
    {
    }

    public override string WherePredicate(Charge charge) => "";

    public override string AfterSnapshot(Charge charge)
    {
        throw new NotImplementedException();
    }

    protected override string Apply(Charge charge)
    {
        throw new NotImplementedException();
    }
}