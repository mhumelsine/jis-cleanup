using System.Text;

namespace JisCleanup;

public class BlockDeclarations
{
    public Dictionary<string, string> VariableDeclarations = new();
    public Dictionary<string, string> TypeDeclarations = new();

    public void AddVariable(string name, string type)
    {
        VariableDeclarations.TryAdd(name, type);
    }
    
    public void AddType(string name, string type)
    {
        TypeDeclarations.TryAdd(name, type);
    }

    public void BuildTypes(StringBuilder builder)
    {
        foreach (var type in TypeDeclarations)
        {
            builder.AppendLine($"TYPE {type.Key} {type.Value};");
        }
    }
    
    public void BuildVariables(StringBuilder builder)
    {
        foreach (var vars in VariableDeclarations)
        {
            builder.AppendLine($"{vars.Key} {vars.Value};");
        }
    }
}