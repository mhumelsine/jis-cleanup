namespace JisCleanup;

public record Charge
{
    public int ChargeId  { get; set; }
    public string CjisCaseNumber { get; set; } = "";
    public int Spn { get; set; }
    public string Location { get; set; } = "";
    public string BondAmount { get; set; } = "";
    public string Status { get; set; } = "";
}