using System.Data;
using Oracle.ManagedDataAccess.Client;

namespace JisCleanup;

public class OracleCsvDataExtractor
{
    private OracleConnection Connect()
    {
        var user = Environment.GetEnvironmentVariable("ORACLE_USERNAME");
        var password = Environment.GetEnvironmentVariable("ORACLE_PASSWORD");
        var host = Environment.GetEnvironmentVariable("ORACLE_HOST");

        return new OracleConnection(
            $"User Id={user};Password={password};Data Source={host}:1521/JISPROD;");
    }

    public void Extract(string queryFilePath, string outputFilePath)
    {
        if (!File.Exists(queryFilePath))
            throw new ArgumentException($"Expected input file '{queryFilePath}' was not found");

        var queryText = File.ReadAllText(queryFilePath);

        using var connection = Connect();
        using var command = new OracleCommand(queryText, connection);
        using var writer = new StreamWriter(File.OpenWrite(outputFilePath));

        connection.Open();

        using var reader = command.ExecuteReader(CommandBehavior.CloseConnection);

        //write headers
        var line = new object[reader.FieldCount];

        for (var i = 0; i < reader.FieldCount; i++)
        {
            line[i] = reader.GetName(i);
        }

        writer.WriteLine(string.Join(',', line));

        //write rows
        while (reader.Read())
        {
            reader.GetValues(line);
            writer.WriteLine(string.Join(',', line));
        }
    }
}