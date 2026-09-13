using System.Text.RegularExpressions;

namespace JisCleanup;

public record Charge
{
    public string ChargeId  { get; set; }
    public string CjisChargeNumber { get; set; } = "";
    
    public int Spn { get; set; }
    public string Location { get; set; } = "";
    public string BondAmount { get; set; } = "";
    public string Status { get; set; } = "";

    public string GetCjisCaseNumber()
    {
        var match = Regex.Match(CjisChargeNumber, @"(\d{4}\w{2}\d+[a-zA-Z])\d+");

        return match.Groups[0].Value;
    }
}