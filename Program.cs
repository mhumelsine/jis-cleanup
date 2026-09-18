using JisCleanup;

//args build "CleanupName", "CleanupName2


if (args.Length < 1)
    throw new ArgumentException("Missing positional argument; specify a command: build, run");

var command = args[0];
var cleanupList = new List<string>();

for (var i = 1; i < args.Length; i++)
{
    cleanupList.Add(args[i]);
}

switch (command)
{
    case "build":
        var buildTimestamp = DateTime.Now.ToString("yyyyMMdd_hhmmss");
        
        foreach (var cleanup in args.Skip(1))
        {
            ScriptBuilder.Build(cleanup, buildTimestamp);
        }
        return 0;
    
    default:
        return 1;
}