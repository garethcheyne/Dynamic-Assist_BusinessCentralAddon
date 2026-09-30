/// <summary>
/// One row of a query's result, for the GET endpoint (page "DA Query Rows
/// API"). Temporary: rows exist only while that request is answered, and
/// nothing is ever stored.
/// </summary>
table 77500 "DA Query Row"
{
    Caption = 'Dynamic Assist Query Row';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Row No."; Integer)
        {
            Caption = 'Row No.';
        }
        /// <summary>The query, as JSON text; the GET request filters on it.</summary>
        field(2; Request; Text[2048])
        {
            Caption = 'Request';
        }
    }

    keys
    {
        key(PK; "Row No.")
        {
            Clustered = true;
        }
    }
}
