namespace JisCleanup.Validations;

public class NoBondOutsideGhostDocket : Validator
{
    protected override string Collect()
        => """
           SELECT bond_id BULK COLLECT INTO v_bond_ids
           FROM JISJDW.RELEASE_BOND
           WHERE charge_id IN (SELECT COLUMN_VALUE FROM TABLE(v_charge_ids))
           FOR UPDATE NOWAIT;
           v_bond_count := v_bond_ids.COUNT;
                            
           SELECT COUNT(*) INTO v_count
           FROM JISJDW.CJIS_DOCKET d
           WHERE d.bond_id IN (SELECT COLUMN_VALUE FROM TABLE(v_bond_ids))
           AND d.cjis_docket_id NOT IN (SELECT COLUMN_VALUE FROM TABLE(v_docket_ids));

           """;

    protected override string Check() =>
        ExactlyZero("Bond is referenced by a docket outside the ghost docket");

    public override void Declares(BlockDeclarations declarations)
    {
        declarations.AddVariable("v_bond_count", "PLS_INTEGER");
        declarations.AddVariable("v_bond_ids", "SYS.ODCINUMBERLIST()");
    }
}