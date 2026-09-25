/// <summary>
/// The key to Dynamic Assist Query. It holds no data: permission to read it
/// is what lets someone query. The DA QUERY permission set grants it (and so
/// DA QUERY ADMIN and SUPER), and every request, from the query builder or
/// the REST endpoints, checks it first. Table data permissions are always
/// enforced, so this gate holds whatever the object permission settings are.
/// </summary>
table 77502 "DA Query Access"
{
    Caption = 'Dynamic Assist Query Access';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Code"; Code[10])
        {
            Caption = 'Code';
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }
}
