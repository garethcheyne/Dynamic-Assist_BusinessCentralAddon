/// <summary>
/// Who queried what through Dynamic Assist, and how it went: one entry per
/// query from the query builder, and per call to the REST endpoints. The only
/// thing the companion ever writes. Users can add their own entries; reading
/// the log takes the DA QUERY ADMIN permission set.
/// </summary>
table 77501 "DA Query Log"
{
    Caption = 'Dynamic Assist Query Log';
    DataClassification = SystemMetadata;
    LookupPageId = "DA Query Log";
    DrillDownPageId = "DA Query Log";

    fields
    {
        field(1; "Entry No."; BigInteger)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(3; "User Security ID"; Guid)
        {
            Caption = 'User Security ID';
            DataClassification = EndUserPseudonymousIdentifiers;
        }
        field(4; Channel; Enum "DA Query Channel")
        {
            Caption = 'Channel';
        }
        field(5; Method; Text[30])
        {
            Caption = 'Method';
        }
        field(6; "Table No."; Integer)
        {
            Caption = 'Table No.';
        }
        field(7; "Table Name"; Text[30])
        {
            Caption = 'Table';
        }
        field(8; Rows; Integer)
        {
            Caption = 'Rows';
        }
        field(9; "Duration (ms)"; Integer)
        {
            Caption = 'Duration (ms)';
        }
        field(10; Success; Boolean)
        {
            Caption = 'Success';
        }
        field(11; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            DataClassification = CustomerContent;
        }
        /// <summary>The request as sent; the first 2048 characters.</summary>
        field(12; Request; Text[2048])
        {
            Caption = 'Request';
            DataClassification = CustomerContent;
        }
        field(13; Company; Text[30])
        {
            Caption = 'Company';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByUser; "User ID", SystemCreatedAt)
        {
        }
    }
}
