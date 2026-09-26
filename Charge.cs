using System.Text.RegularExpressions;

namespace JisCleanup;

public record Charge
{
    public int ChargeId { get; set; }

    public string CjisCaseNumber { get; set; } = "";

    public int CaseDefendantId { get; set; }
    
    public int CjisSpn { get; set; }
    public string Location { get; set; } = "";
    public string BondAmount { get; set; } = "";
    public string Status { get; set; } = "";


    public string GetCaseYear() => CjisCaseNumber[..3];
    
    public string GetCaseCourt()
    {
        var match = Regex.Match(CjisCaseNumber, @"\d{4}(\w{2})\d+\w\d+");
    
        return match.Groups[1].Value;
    }
    
    public string GetCaseSequence()
    {
        var match = Regex.Match(CjisCaseNumber, @"\d{4}\w{2}(\d+)\w\d+");
    
        return match.Groups[1].Value;
    }
    
    public string GetCaseNumber()
    {
        var match = Regex.Match(CjisCaseNumber, @"(\d{4}\w{2}\d+\w)\d+");
    
        return match.Groups[1].Value;
    }
}