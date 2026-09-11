namespace JisCleanup;

public record SnapshotType(string Value)
{
    public static readonly SnapshotType
        Before = new("BEFORE"),
        After = new("AFTER");
}

public record ActionType(string Value)
{
    public static readonly ActionType
        Updated = new("UPDATE"),
        Delete = new("DELETE"),
        Insert = new("INSERT");
}