/// <summary>
/// One Dataverse coupling, for the couplings endpoint (page "DA Coupling
/// API"): a CRM Integration Record with the Business Central record it points
/// to. Temporary: filled while a request is answered, never stored.
///
/// The CRM ID and Integration ID are Text, not Guid: the Business Central
/// Virtual Table app drops Guid fields other than the key, and Dataverse has
/// to filter on them.
/// </summary>
table 77503 "DA Coupling"
{
    Caption = 'Dynamic Assist Coupling';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        /// <summary>The integration record's SystemId: the endpoint's key.</summary>
        field(1; Id; Guid)
        {
            Caption = 'Id';
        }
        /// <summary>The Dataverse row's ID, lowercase without braces.</summary>
        field(2; "CRM ID"; Text[36])
        {
            Caption = 'CRM ID';
        }
        /// <summary>The Business Central record's SystemId, lowercase without braces.</summary>
        field(3; "Integration ID"; Text[36])
        {
            Caption = 'Integration ID';
        }
        field(4; "Table ID"; Integer)
        {
            Caption = 'Table ID';
        }
        field(5; "Table Caption"; Text[250])
        {
            Caption = 'Table Caption';
        }
        /// <summary>The record's primary key values, joined by " · ".</summary>
        field(6; "Record Key"; Text[250])
        {
            Caption = 'Record Key';
        }
        /// <summary>A URL filter on the primary key: 'No.' IS '10000'.</summary>
        field(7; "Record Filter"; Text[2048])
        {
            Caption = 'Record Filter';
        }
        /// <summary>The page to open it on: the mapping's, else the table's drill-down or lookup page.</summary>
        field(8; "Page ID"; Integer)
        {
            Caption = 'Page ID';
        }
        /// <summary>False when the record is gone, or you can't read its table.</summary>
        field(9; "Record Exists"; Boolean)
        {
            Caption = 'Record Exists';
        }
        field(10; Skipped; Boolean)
        {
            Caption = 'Skipped';
        }
        field(11; "Last Synch. Modified On"; DateTime)
        {
            Caption = 'Last Synch. Modified On';
        }
        field(12; "Last Synch. CRM Modified On"; DateTime)
        {
            Caption = 'Last Synch. CRM Modified On';
        }
    }

    keys
    {
        key(PK; Id)
        {
            Clustered = true;
        }
    }
}
