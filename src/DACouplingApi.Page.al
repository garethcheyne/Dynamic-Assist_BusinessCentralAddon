/// <summary>
/// Which Business Central records are coupled to a Dataverse row, and back:
/// the integration table (CRM Integration Record, 5331), with each coupled
/// record's table, key and page.
///
///   GET https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/api/err403/dynamicassist/v1.0/companies({id})/couplings
///       ?$filter=crmId eq '{Dataverse row ID}'
///   ...?$filter=integrationId eq '{BC record SystemId}'
///   .../couplings({id})
///
/// One filter is required; without one it answers nothing rather than every
/// coupling in the company. Read-only and run as the caller, with their
/// permissions: the DA QUERY permission set, and read on the integration
/// tables and the coupled records' tables.
///
/// The rows are temporary, filled from the filter: crmId and integrationId
/// are Text so the Business Central Virtual Table app makes them columns
/// (it drops Guid fields other than the key) and Dataverse can filter on
/// them. Identifiers are lowercase and the key is one GUID, as it needs.
/// </summary>
page 77503 "DA Coupling API"
{
    PageType = API;
    APIPublisher = 'err403';
    APIGroup = 'dynamicassist';
    APIVersion = 'v1.0';
    EntityName = 'coupling';
    EntitySetName = 'couplings';
    EntityCaption = 'Dynamics 365 Coupling';
    EntitySetCaption = 'Dynamics 365 Couplings';
    Caption = 'Dynamic Assist Couplings';
    SourceTable = "DA Coupling";
    SourceTableTemporary = true;
    ODataKeyFields = Id;
    DelayedInsert = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Couplings)
            {
                field(id; Rec.Id)
                {
                    Caption = 'Id';
                }
                field(crmId; Rec."CRM ID")
                {
                    Caption = 'CRM ID';
                }
                field(integrationId; Rec."Integration ID")
                {
                    Caption = 'Integration ID';
                }
                field(tableId; Rec."Table ID")
                {
                    Caption = 'Table ID';
                }
                field(tableCaption; Rec."Table Caption")
                {
                    Caption = 'Table Caption';
                }
                field(recordKey; Rec."Record Key")
                {
                    Caption = 'Record Key';
                }
                field(recordFilter; Rec."Record Filter")
                {
                    Caption = 'Record Filter';
                }
                field(pageId; Rec."Page ID")
                {
                    Caption = 'Page ID';
                }
                field(recordExists; Rec."Record Exists")
                {
                    Caption = 'Record Exists';
                }
                field(skipped; Rec.Skipped)
                {
                    Caption = 'Skipped';
                }
                field(lastSynchModifiedOn; Rec."Last Synch. Modified On")
                {
                    Caption = 'Last Synch. Modified On';
                }
                field(lastSynchCrmModifiedOn; Rec."Last Synch. CRM Modified On")
                {
                    Caption = 'Last Synch. CRM Modified On';
                }
            }
        }
    }

    var
        Loaded: Boolean;

    trigger OnOpenPage()
    var
        Service: Codeunit "DA Query Service";
    begin
        Service.CheckAccess();
    end;

    trigger OnFindRecord(Which: Text): Boolean
    begin
        if not Loaded then
            Load();
        exit(Rec.Find(Which));
    end;

    trigger OnNextRecord(Steps: Integer): Integer
    begin
        exit(Rec.Next(Steps));
    end;

    /// <summary>Reads the couplings the request filters on into the temporary rows.</summary>
    local procedure Load()
    var
        Coupling: Record "CRM Integration Record";
        FilterText: Text;
        Value: Guid;
    begin
        Loaded := true;
        if Rec.GetFilter(Id) <> '' then begin
            if Coupling.GetBySystemId(Rec.GetRangeMin(Id)) then
                Add(Coupling, '', '');
            exit;
        end;
        if Rec.GetFilter("CRM ID") <> '' then begin
            FilterText := Rec.GetRangeMin("CRM ID");
            if not Evaluate(Value, FilterText) then
                exit;
            Coupling.SetRange("CRM ID", Value);
            if Coupling.FindSet() then
                repeat
                    // Keep the filter's own spelling, so the page's filter matches the row
                    Add(Coupling, FilterText, '');
                until (Coupling.Next() = 0) or (Rec.Count() >= MaxRows());
            exit;
        end;
        if Rec.GetFilter("Integration ID") <> '' then begin
            FilterText := Rec.GetRangeMin("Integration ID");
            if not Evaluate(Value, FilterText) then
                exit;
            Coupling.SetRange("Integration ID", Value);
            if Coupling.FindSet() then
                repeat
                    Add(Coupling, '', FilterText);
                until (Coupling.Next() = 0) or (Rec.Count() >= MaxRows());
        end;
    end;

    local procedure Add(Coupling: Record "CRM Integration Record"; CrmIdText: Text; IntegrationIdText: Text)
    var
        TableMetadata: Record "Table Metadata";
        Target: RecordRef;
    begin
        Rec.Init();
        Rec.Id := Coupling.SystemId;
        Rec."CRM ID" := CopyStr(GuidText(Coupling."CRM ID", CrmIdText), 1, MaxStrLen(Rec."CRM ID"));
        Rec."Integration ID" := CopyStr(GuidText(Coupling."Integration ID", IntegrationIdText), 1, MaxStrLen(Rec."Integration ID"));
        Rec."Table ID" := Coupling."Table ID";
        Rec.Skipped := Coupling.Skipped;
        Rec."Last Synch. Modified On" := Coupling."Last Synch. Modified On";
        Rec."Last Synch. CRM Modified On" := Coupling."Last Synch. CRM Modified On";

        if TableMetadata.Get(Coupling."Table ID") then begin
            Rec."Table Caption" := CopyStr(TableMetadata.Caption, 1, MaxStrLen(Rec."Table Caption"));
            Rec."Page ID" := MappedPage(Coupling."Table ID");
            if Rec."Page ID" = 0 then
                Rec."Page ID" := TableMetadata.DrillDownPageId;
            if Rec."Page ID" = 0 then
                Rec."Page ID" := TableMetadata.LookupPageID;
            Target.Open(Coupling."Table ID");
            if Target.ReadPermission() then
                if Target.GetBySystemId(Coupling."Integration ID") then begin
                    Rec."Record Exists" := true;
                    DescribeKey(Target);
                end;
        end;
        Rec.Insert();
    end;

    /// <summary>A GUID as the filter spelled it, else lowercase without braces.</summary>
    local procedure GuidText(Value: Guid; AsFiltered: Text): Text
    begin
        if AsFiltered <> '' then
            exit(AsFiltered);
        exit(LowerCase(DelChr(Format(Value), '=', '{}')));
    end;

    /// <summary>The primary key as values (for showing) and as a web client URL filter.</summary>
    local procedure DescribeKey(var Target: RecordRef)
    var
        PrimaryKey: KeyRef;
        FldRef: FieldRef;
        KeyText: Text;
        FilterText: Text;
        i: Integer;
    begin
        PrimaryKey := Target.KeyIndex(1);
        for i := 1 to PrimaryKey.FieldCount() do begin
            FldRef := PrimaryKey.FieldIndex(i);
            if i > 1 then begin
                KeyText += ' · ';
                FilterText += ' AND ';
            end;
            KeyText += Format(FldRef.Value());
            FilterText += Quote(FldRef.Name()) + ' IS ' + Quote(Format(FldRef.Value()));
        end;
        Rec."Record Key" := CopyStr(KeyText, 1, MaxStrLen(Rec."Record Key"));
        Rec."Record Filter" := CopyStr(FilterText, 1, MaxStrLen(Rec."Record Filter"));
    end;

    local procedure Quote(Value: Text): Text
    begin
        exit('''' + Value.Replace('''', '''''') + '''');
    end;

    /// <summary>The integration table mapping's record page for a table (its "BC Rec Page Id"), or 0.</summary>
    local procedure MappedPage(TableNo: Integer): Integer
    var
        Mapping: Record "Integration Table Mapping";
    begin
        if not Mapping.ReadPermission() then
            exit(0);
        Mapping.SetRange("Table ID", TableNo);
        Mapping.SetFilter("BC Rec Page Id", '<>0');
        if Mapping.FindFirst() then
            exit(Mapping."BC Rec Page Id");
        exit(0);
    end;

    local procedure MaxRows(): Integer
    begin
        // A Dataverse row is coupled to a handful of records at most
        exit(100);
    end;
}
