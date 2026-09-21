using ClosedXML.Excel;

namespace JisCleanup;

public static class ManualListVisitor
{
    public static void Visit(string rootPath)
    {
        if (!Directory.Exists(rootPath))
        {
            throw new DirectoryNotFoundException(
                $"Directory does not exist: {rootPath}");
        }

        var excelFiles = Directory
            .EnumerateFiles(
                rootPath,
                "*.xlsx",
                SearchOption.AllDirectories)
            //filter out any open .xlsx files
            .Where(filePath =>
                !Path.GetFileName(filePath).StartsWith("~$", StringComparison.Ordinal))
            .OrderBy(filePath => filePath, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        Console.WriteLine(
            $"Found {excelFiles.Length} workbook(s).");

        var succeeded = 0;
        var failed = 0;

        foreach (var filePath in excelFiles)
        {
            try
            {
                ApplyValidations(filePath);

                Console.WriteLine($"Updated: {filePath}");

                succeeded++;
            }
            catch (Exception exception)
            {
                Console.Error.WriteLine($"Failed:  {filePath}");

                Console.Error.WriteLine($"         {exception.Message}");
                Console.Error.WriteLine($"         {exception.StackTrace}");

                failed++;
            }
        }

        Console.WriteLine();
        Console.WriteLine($"Succeeded: {succeeded}");
        Console.WriteLine($"Failed:    {failed}");
    }

    private static void ApplyValidations(string filePath)
    {
        using var workbook = new XLWorkbook(filePath);

        var worksheet = workbook.Worksheet(1);
        
        //freeze top row
        worksheet.SheetView.FreezeRows(1);    
        
        //hide columns not needed by review staff
        worksheet.Column("C").Hide();
        worksheet.Column("D").Hide();
        worksheet.Column("H").Hide();

        var lastRowNumber =
            worksheet.LastRowUsed()?.RowNumber() ?? 1;

        if (lastRowNumber < 2)
        {
            Console.WriteLine(
                $"Skipped empty workbook: {filePath}");

            return;
        }

        //STATUS
        ApplyDropdown(
            worksheet,
            columnLetter: "E",
            firstDataRow: 2,
            lastDataRow: lastRowNumber,
            allowedValues:
            [
                "D",
                "R",
                "O",
                "V"
            ]);

        //LOCATION
        ApplyDropdown(
            worksheet,
            columnLetter: "F",
            firstDataRow: 2,
            lastDataRow: lastRowNumber,
            allowedValues:
            [
                "BOND",
                "BONDRT",
                "CAP.",
                "CLRK",
                "LCJ",
                "OREC",
                "OTJA",
                "PTRL",
                "RLSD",
                "RLSDBE",
                "RLSDCC",
                "RLSDDS",
                "RLSDNG",
                "RLSDNI",
                "RLSDNP",
                "RLSDPB",
                "RLSDPT",
                "RLSDTS",
                "RLSDWD",
                "STPR",
                "SUMM"
            ]);
        
        // bold top row
        worksheet
            .Range(1, 1, 1, 8)
            .Style.Font.Bold = true;
        
        //shade every other case
        var isShaded = false;
        for (var row = 2; row < lastRowNumber; row++)
        {
            //every case reset, swap shading
            if (worksheet.Cell(row, "H").GetValue<int>() == 1)
            {
                isShaded = !isShaded;
            }

            if (isShaded)
            {
                worksheet
                    .Range(row, 1, row, 8)
                    .Style.Fill.BackgroundColor = XLColor.LightGray;
            }
        }

        foreach (var column in worksheet.ColumnsUsed())
        {
            column.AdjustToContents();
        }

        workbook.Save();
    }

    private static void ApplyDropdown(
        IXLWorksheet worksheet,
        string columnLetter,
        int firstDataRow,
        int lastDataRow,
        IReadOnlyCollection<string> allowedValues)
    {
        if (allowedValues.Count == 0)
        {
            throw new ArgumentException(
                "At least one allowed value is required.",
                nameof(allowedValues));
        }
        
        var targetRange = worksheet.Range(
            $"{columnLetter}{firstDataRow}:{columnLetter}{lastDataRow}");

        var validation = targetRange.CreateDataValidation();

        var inlineList =
            $"\"{string.Join(",", allowedValues)}\"";

        validation.List(
            inlineList,
            inCellDropdown: true);

        validation.IgnoreBlanks = true;
        validation.ShowErrorMessage = true;
        validation.ErrorStyle = XLErrorStyle.Stop;
        validation.ErrorTitle = "Invalid value";
        validation.ErrorMessage =
            $"Select one of the allowed values: " +
            string.Join(", ", allowedValues);
    }
}