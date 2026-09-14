using System.Text.RegularExpressions;

namespace JisCleanup;

public partial record CaseId
{
    public string Value { get; }
    
    public CaseId(string caseId)
    {
        if (!CaseIdPattern().IsMatch(caseId))
        {
            throw new ArgumentException($"Case ID '{caseId}' does not match the expected pattern");
        }

        Value = caseId;
    }

    [GeneratedRegex("^[0-9]{4}[A-Z]{2}[0-9]+[A-Z]$")]
    private static partial Regex CaseIdPattern();
}