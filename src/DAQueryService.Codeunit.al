/// <summary>
/// Answers the Dynamic Assist query builder: lists tables and fields and runs
/// read-only queries on any table, as the signed-in user.
///
/// Nothing here writes. Reads go through RecordRef, so the user's permissions
/// apply, and security filters are applied rather than raising errors, so a
/// user only ever sees the rows they're allowed to see.
///
/// Run it through Codeunit.Run (see SetRequest/GetResult) so an error in one
/// request comes back as that request's error instead of breaking the page.
/// </summary>
codeunit 77500 "DA Query Service"
{
    Access = Internal;

    var
        RequestMethod: Text;
        RequestPayload: Text;
        ResultJson: Text;
        UnknownMethodErr: Label 'Unknown method "%1".', Comment = '%1 = the method name';
        NoReadPermissionErr: Label 'You don''t have permission to read %1 (table %2).', Comment = '%1 = table caption, %2 = table number';
        UnknownFieldErr: Label 'Table %1 has no field %2.', Comment = '%1 = table number, %2 = field number';
        MissingTableErr: Label 'Choose a table.';
        CursorGoneErr: Label 'The record the "after" cursor points to no longer matches (it was deleted, renamed or changed so the filters leave it out). Start from the first page again.';
        NoAccessErr: Label 'No permission: %1 can''t use Dynamic Assist Query. Ask your system administrator to assign you the DA QUERY permission set.', Comment = '%1 = the user';
        UnknownTableErr: Label 'There''s no table called "%1".', Comment = '%1 = the name asked for';
        UnknownFieldNameErr: Label 'Table %1 has no field "%2".', Comment = '%1 = table name, %2 = the field name asked for';
        MissingFieldErr: Label 'Say which field ("%1").', Comment = '%1 = the property name';
        TooManyJoinsErr: Label 'A query can join at most %1 tables.', Comment = '%1 = the limit';
        DefaultTop: Integer;
        LastTableNo: Integer;
        LastRowCount: Integer;
        MaxTop: Integer;

    trigger OnRun()
    begin
        ResultJson := Handle(RequestMethod, RequestPayload);
    end;

    procedure SetRequest(Method: Text; Payload: Text)
    begin
        RequestMethod := Method;
        RequestPayload := Payload;
        ResultJson := '';
    end;

    /// <summary>The table the last request used (0 if none), for the log.</summary>
    procedure GetLastTableNo(): Integer
    begin
        exit(LastTableNo);
    end;

    /// <summary>How many rows the last query returned, for the log.</summary>
    procedure GetLastRowCount(): Integer
    begin
        exit(LastRowCount);
    end;

    procedure GetResult(): Text
    begin
        exit(ResultJson);
    end;

    procedure Handle(Method: Text; Payload: Text): Text
    var
        Request: JsonObject;
    begin
        CheckAccess();
        DefaultTop := 100;
        MaxTop := 10000;
        if Payload <> '' then
            Request.ReadFrom(Payload);
        case Method of
            'info':
                exit(Info());
            'tables':
                exit(Tables(GetText(Request, 'search')));
            'describe':
                begin
                    LastTableNo := TableNoOf(Request, 'table');
                    exit(Describe(LastTableNo));
                end;
            'fields':
                begin
                    LastTableNo := TableNoOf(Request, 'table');
                    exit(Fields(LastTableNo));
                end;
            'query':
                exit(RunQuery(Request));
            'apis':
                begin
                    LastTableNo := TableNoOf(Request, 'table');
                    exit(Apis(LastTableNo));
                end;
        end;
        Error(UnknownMethodErr, Method);
    end;

    local procedure Info(): Text
    var
        Company: Record Company;
        Me: ModuleInfo;
        Result: JsonObject;
    begin
        NavApp.GetCurrentModuleInfo(Me);
        Result.Add('app', Me.Name);
        Result.Add('version', Format(Me.AppVersion));
        Result.Add('company', CompanyName());
        // For API URLs: companies({id})
        if Company.Get(CompanyName()) then
            Result.Add('companyId', LowerCase(Format(Company.Id, 0, 4)));
        Result.Add('user', UserId());
        Result.Add('maxRows', MaxTop);
        exit(Write(Result));
    end;

    /// <summary>
    /// Stops anyone without the DA QUERY permission set (or one that includes
    /// it, or SUPER): it grants read on the DA Query Access table.
    /// </summary>
    procedure CheckAccess()
    begin
        if not HasAccess() then
            Error(NoAccessErr, UserId());
    end;

    procedure HasAccess(): Boolean
    var
        Access: Record "DA Query Access";
    begin
        exit(Access.ReadPermission());
    end;

    /// <summary>
    /// What the Dynamic Assist Query page shows: this app's version, where
    /// you are, and whether the REST endpoint (DA Query API) is published.
    /// </summary>
    procedure PageInfo(): Text
    var
        TenantWebService: Record "Tenant Web Service";
        Company: Record Company;
        Me: ModuleInfo;
        Result: JsonObject;
        WebService: JsonObject;
    begin
        NavApp.GetCurrentModuleInfo(Me);
        Result.Add('version', Format(Me.AppVersion));
        Result.Add('company', CompanyName());
        Result.Add('user', UserId());
        Result.Add('hasAccess', HasAccess());
        if Company.Get(CompanyName()) then
            Result.Add('companyId', LowerCase(Format(Company.Id, 0, 4)));
        if TenantWebService.ReadPermission() then begin
            TenantWebService.SetRange("Object Type", TenantWebService."Object Type"::Codeunit);
            TenantWebService.SetRange("Object ID", Codeunit::"DA Query API");
            WebService.Add('published', false);
            if TenantWebService.FindFirst() then begin
                WebService.Replace('published', TenantWebService.Published);
                WebService.Add('name', TenantWebService."Service Name");
            end;
            Result.Add('webService', WebService);
        end;
        exit(Write(Result));
    end;

    /// <summary>Every normal table, including extension and system tables.</summary>
    /// <summary>Tables, optionally only those whose name or caption contains Search.</summary>
    local procedure Tables(Search: Text): Text
    var
        TableMetadata: Record "Table Metadata";
        Result: JsonArray;
        Table: JsonObject;
    begin
        Search := LowerCase(Search);
        TableMetadata.SetRange(TableType, TableMetadata.TableType::Normal);
        TableMetadata.SetFilter(ObsoleteState, '<>%1', TableMetadata.ObsoleteState::Removed);
        if TableMetadata.FindSet() then
            repeat
                if (Search = '') or LowerCase(TableMetadata.Name).Contains(Search) or LowerCase(TableMetadata.Caption).Contains(Search) then begin
                    Clear(Table);
                    Table.Add('id', TableMetadata.ID);
                    Table.Add('name', TableMetadata.Name);
                    Table.Add('caption', TableMetadata.Caption);
                    Table.Add('perCompany', TableMetadata.DataPerCompany);
                    Table.Add('obsolete', TableMetadata.ObsoleteState = TableMetadata.ObsoleteState::Pending);
                    Result.Add(Table);
                end;
            until TableMetadata.Next() = 0;
        exit(Write(Result));
    end;

    local procedure Fields(TableNo: Integer): Text
    var
        Field: Record Field;
        RecRef: RecordRef;
        FldRef: FieldRef;
        PrimaryKey: List of [Integer];
        Result: JsonObject;
        FieldList: JsonArray;
        Item: JsonObject;
    begin
        if TableNo = 0 then
            Error(MissingTableErr);
        RecRef.Open(TableNo);
        PrimaryKey := KeyFields(RecRef);

        Field.SetRange(TableNo, TableNo);
        Field.SetFilter(ObsoleteState, '<>%1', Field.ObsoleteState::Removed);
        if Field.FindSet() then
            repeat
                Clear(Item);
                Item.Add('no', Field."No.");
                Item.Add('name', Field.FieldName);
                Item.Add('caption', Field."Field Caption");
                Item.Add('type', Format(Field.Type));
                Item.Add('class', Format(Field.Class));
                Item.Add('length', Field.Len);
                Item.Add('enabled', Field.Enabled);
                Item.Add('obsolete', Field.ObsoleteState = Field.ObsoleteState::Pending);
                Item.Add('pk', PrimaryKey.Contains(Field."No."));
                if Field.RelationTableNo <> 0 then begin
                    Item.Add('relationTable', Field.RelationTableNo);
                    if Field.RelationFieldNo <> 0 then
                        Item.Add('relationField', Field.RelationFieldNo);
                end;
                if Field.Type = Field.Type::Option then begin
                    FldRef := RecRef.Field(Field."No.");
                    Item.Add('options', Options(FldRef.OptionCaption()));
                end;
                FieldList.Add(Item);
            until Field.Next() = 0;

        Result.Add('table', TableNo);
        Result.Add('name', RecRef.Name());
        Result.Add('caption', RecRef.Caption());
        Result.Add('readable', RecRef.ReadPermission());
        Result.Add('fields', FieldList);
        exit(Write(Result));
    end;

    /// <summary>
    /// Everything about a table, to explore before querying: its fields (type,
    /// class, key, options), its keys, the lookups it can join through (with
    /// the related table and key named), whether you can read it, and the API
    /// pages already installed for it.
    /// </summary>
    local procedure Describe(TableNo: Integer): Text
    var
        LookupField: Record Field;
        RelatedTable: Record "Table Metadata";
        RelatedField: Record Field;
        RecRef: RecordRef;
        Related: RecordRef;
        KeyRef: KeyRef;
        Result: JsonObject;
        ApisJson: JsonArray;
        Keys: JsonArray;
        KeyFields: JsonArray;
        Joins: JsonArray;
        Join: JsonObject;
        i: Integer;
        j: Integer;
    begin
        Result.ReadFrom(Fields(TableNo));
        RecRef.Open(TableNo);
        for i := 1 to RecRef.KeyCount() do begin
            KeyRef := RecRef.KeyIndex(i);
            if KeyRef.Active() then begin
                Clear(KeyFields);
                for j := 1 to KeyRef.FieldCount() do
                    KeyFields.Add(KeyRef.FieldIndex(j).Name());
                Keys.Add(KeyFields);
            end;
        end;
        Result.Add('keys', Keys);

        // Lookups: what "joins" can use, with the table and key filled in
        LookupField.SetRange(TableNo, TableNo);
        LookupField.SetFilter(RelationTableNo, '<>0');
        LookupField.SetRange(Class, LookupField.Class::Normal);
        LookupField.SetFilter(ObsoleteState, '<>%1', LookupField.ObsoleteState::Removed);
        if LookupField.FindSet() then
            repeat
                if RelatedTable.Get(LookupField.RelationTableNo) then begin
                    Clear(Join);
                    Join.Add('field', LookupField.FieldName);
                    Join.Add('table', RelatedTable.Name);
                    if LookupField.RelationFieldNo <> 0 then begin
                        if RelatedField.Get(LookupField.RelationTableNo, LookupField.RelationFieldNo) then
                            Join.Add('key', RelatedField.FieldName);
                    end else begin
                        Related.Open(LookupField.RelationTableNo);
                        if Related.KeyIndex(1).FieldCount() = 1 then
                            Join.Add('key', Related.KeyIndex(1).FieldIndex(1).Name())
                        else
                            Join.Add('note', 'The related key has several fields: the join matches on the first one only.');
                        Related.Close();
                    end;
                    Joins.Add(Join);
                end;
            until LookupField.Next() = 0;
        Result.Add('joins', Joins);

        ApisJson.ReadFrom(Apis(TableNo));
        Result.Add('apis', ApisJson);
        exit(Write(Result));
    end;

    /// <summary>
    /// The API pages installed for a table (Microsoft's and any extension's),
    /// with the JSON name each one gives the table's fields. The query builder
    /// uses it to offer an out-of-the-box endpoint instead of a custom one.
    /// </summary>
    local procedure Apis(TableNo: Integer): Text
    var
        PageMetadata: Record "Page Metadata";
        PageControlField: Record "Page Control Field";
        Result: JsonArray;
        Api: JsonObject;
        ApiFields: JsonArray;
        Item: JsonObject;
    begin
        if TableNo = 0 then
            Error(MissingTableErr);
        PageMetadata.SetRange(PageType, PageMetadata.PageType::API);
        PageMetadata.SetRange(SourceTable, TableNo);
        PageMetadata.SetRange(SourceTableTemporary, false);
        if PageMetadata.FindSet() then
            repeat
                Clear(Api);
                Clear(ApiFields);
                Api.Add('page', PageMetadata.ID);
                Api.Add('name', PageMetadata.Name);
                Api.Add('publisher', PageMetadata.APIPublisher);
                Api.Add('group', PageMetadata.APIGroup);
                Api.Add('version', PageMetadata.APIVersion);
                Api.Add('entityName', PageMetadata.EntityName);
                Api.Add('entitySetName', PageMetadata.EntitySetName);
                Api.Add('view', PageMetadata.SourceTableView);
                PageControlField.SetRange(PageNo, PageMetadata.ID);
                PageControlField.SetRange(TableNo, TableNo);
                PageControlField.SetFilter(FieldNo, '<>0');
                if PageControlField.FindSet() then
                    repeat
                        Clear(Item);
                        Item.Add('no', PageControlField.FieldNo);
                        Item.Add('name', PageControlField.ControlName);
                        ApiFields.Add(Item);
                    until PageControlField.Next() = 0;
                Api.Add('fields', ApiFields);
                Result.Add(Api);
            until PageMetadata.Next() = 0;
        exit(Write(Result));
    end;

    /// <summary>
    /// Runs a query: { table, fields: [no], filters: [{ field, filter }],
    /// sort: [no], descending, top, after, count, joins: [...] }. Filters use Business
    /// Central's filter syntax (10000..20000, A*|B*, &lt;&gt;'', ...). Each join adds
    /// a related table's columns through a lookup field (see DA Query Join).
    /// </summary>
    local procedure RunQuery(Request: JsonObject): Text
    var
        RecRef: RecordRef;
        FldRef: FieldRef;
        FieldNos: List of [Integer];
        FieldNo: Integer;
        Top: Integer;
        RowCount: Integer;
        More: Boolean;
        Done: Boolean;
        Started: DateTime;
        Result: JsonObject;
        Columns: JsonArray;
        Column: JsonObject;
        Rows: JsonArray;
        Row: JsonArray;
        Joins: array[5] of Codeunit "DA Query Join";
        JoinCount: Integer;
        i: Integer;
        Keep: Boolean;
        Restricted: Boolean;
        AfterPosition: Text;
        LastPosition: Text;
        Found: Boolean;
        Token: JsonToken;
        Item: JsonToken;
    begin
        Started := CurrentDateTime();
        LastTableNo := TableNoOf(Request, 'table');
        RecRef.Open(LastTableNo);
        if not RecRef.ReadPermission() then
            Error(NoReadPermissionErr, RecRef.Caption(), RecRef.Number());
        // Rows outside the user's security filters are left out, not an error
        RecRef.SecurityFiltering(SecurityFilter::Filtered);
        RecRef.ReadIsolation := IsolationLevel::ReadCommitted;

        FieldNos := FieldList(Request, 'fields', RecRef);
        if FieldNos.Count() = 0 then
            FieldNos := KeyFields(RecRef);
        foreach FieldNo in FieldNos do begin
            FldRef := FieldOf(RecRef, FieldNo);
            Clear(Column);
            Column.Add('no', FldRef.Number());
            Column.Add('name', FldRef.Name());
            Column.Add('caption', FldRef.Caption());
            Column.Add('type', Format(FldRef.Type()));
            Column.Add('class', Format(FldRef.Class()));
            Columns.Add(Column);
        end;

        if Request.Get('joins', Token) then
            if Token.IsArray() then
                foreach Item in Token.AsArray() do
                    if Item.IsObject() then begin
                        JoinCount += 1;
                        if JoinCount > ArrayLen(Joins) then
                            Error(TooManyJoinsErr, ArrayLen(Joins));
                        Joins[JoinCount].Init(Item.AsObject(), RecRef, Columns);
                        if Joins[JoinCount].IsRestricting() then
                            Restricted := true;
                    end;

        // The sort replaces the view, so it goes before the filters
        ApplySort(RecRef, FieldList(Request, 'sort', RecRef), GetBool(Request, 'descending'));
        ApplyFilters(RecRef, Request);
        foreach FieldNo in FieldNos do
            if FieldOf(RecRef, FieldNo).Class() = FieldClass::Normal then
                RecRef.AddLoadFields(FieldNo);
        foreach FieldNo in FieldList(Request, 'sort', RecRef) do
            if FieldOf(RecRef, FieldNo).Class() = FieldClass::Normal then
                RecRef.AddLoadFields(FieldNo);

        Top := GetInt(Request, 'top', DefaultTop);
        if (Top <= 0) or (Top > MaxTop) then
            Top := MaxTop;

        // Paging: "after" is the "next" cursor from the previous page, a
        // record position, so pages don't shift when data changes between calls
        AfterPosition := GetText(Request, 'after');
        if AfterPosition <> '' then
            Found := SeekAfter(RecRef, AfterPosition)
        else
            Found := RecRef.FindSet();

        if Found then
            repeat
                Clear(Row);
                foreach FieldNo in FieldNos do begin
                    FldRef := RecRef.Field(FieldNo);
                    if FldRef.Class() = FieldClass::FlowField then
                        FldRef.CalcField();
                    Row.Add(ValueOf(FldRef));
                end;
                Keep := true;
                for i := 1 to JoinCount do
                    if Keep then
                        Keep := Joins[i].AddTo(RecRef, Row);
                if Keep then begin
                    Rows.Add(Row);
                    RowCount += 1;
                end;
                LastPosition := RecRef.GetPosition(false);
                if RowCount >= Top then begin
                    More := RecRef.Next() <> 0;
                    Done := true;
                end else
                    Done := RecRef.Next() = 0;
            until Done;

        LastRowCount := RowCount;
        Result.Add('table', RecRef.Number());
        // More rows match: send the same request again with "after": next
        if More then
            Result.Add('next', LastPosition);
        Result.Add('name', RecRef.Name());
        Result.Add('caption', RecRef.Caption());
        Result.Add('columns', Columns);
        Result.Add('rows', Rows);
        Result.Add('more', More);
        // A join that drops rows makes the table's count wrong, so leave it out
        if GetBool(Request, 'count') and not Restricted then
            Result.Add('count', RecRef.Count());
        Result.Add('view', RecRef.GetView(false));
        Result.Add('ms', CurrentDateTime() - Started);
        if GetText(Request, 'shape') = 'objects' then
            Result.Replace('rows', AsObjects(Columns, Rows));
        exit(Write(Result));
    end;

    /// <summary>
    /// Moves to the record after the cursor, in the query's sort order, in
    /// either direction. The cursor is the last record's primary key
    /// (GetPosition). The record is read in full and its values copied into
    /// RecRef, so it has its place in whatever order BC sorts by (BC can add
    /// fields to the sort); Find('=') puts RecRef on it and Next() steps on in
    /// the sort order.
    /// </summary>
    local procedure SeekAfter(var RecRef: RecordRef; AfterPosition: Text): Boolean
    var
        Cursor: RecordRef;
        FldRef: FieldRef;
        i: Integer;
    begin
        Cursor.Open(RecRef.Number());
        Cursor.SecurityFiltering(SecurityFilter::Filtered);
        Cursor.SetPosition(AfterPosition);
        if not Cursor.Find('=') then
            Error(CursorGoneErr);
        for i := 1 to Cursor.FieldCount() do begin
            FldRef := Cursor.FieldIndex(i);
            if (FldRef.Class() = FieldClass::Normal) and (FldRef.Number() < 2000000000) then
                if not (FldRef.Type() in [FieldType::Blob, FieldType::Media, FieldType::MediaSet]) then
                    RecRef.Field(FldRef.Number()).Value := FldRef.Value();
        end;
        if not RecRef.Find('=') then
            Error(CursorGoneErr);
        exit(RecRef.Next() <> 0);
    end;

    local procedure ApplySort(var RecRef: RecordRef; SortFields: List of [Integer]; Descending: Boolean)
    var
        FieldNo: Integer;
        Names: Text;
    begin
        if SortFields.Count() = 0 then begin
            if Descending then
                RecRef.SetView('ORDER(Descending)');
            exit;
        end;
        foreach FieldNo in SortFields do begin
            if Names <> '' then
                Names += ',';
            Names += '"' + FieldOf(RecRef, FieldNo).Name() + '"';
        end;
        if Descending then
            RecRef.SetView('SORTING(' + Names + ') ORDER(Descending)')
        else
            RecRef.SetView('SORTING(' + Names + ') ORDER(Ascending)');
    end;

    local procedure ApplyFilters(var RecRef: RecordRef; Request: JsonObject)
    var
        Token: JsonToken;
        Item: JsonToken;
        Filter: JsonObject;
        FilterText: Text;
    begin
        if not Request.Get('filters', Token) then
            exit;
        if not Token.IsArray() then
            exit;
        foreach Item in Token.AsArray() do
            if Item.IsObject() then begin
                Filter := Item.AsObject();
                FilterText := GetText(Filter, 'filter');
                if FilterText <> '' then
                    RecRef.Field(GetFieldNo(Filter, 'field', RecRef)).SetFilter(FilterText);
            end;
    end;

    procedure ValueOf(FldRef: FieldRef) Value: JsonValue
    var
        IntValue: Integer;
        BigValue: BigInteger;
        DecValue: Decimal;
        BoolValue: Boolean;
        Formatted: Text;
    begin
        case FldRef.Type() of
            FieldType::Integer:
                begin
                    IntValue := FldRef.Value();
                    Value.SetValue(IntValue);
                end;
            FieldType::BigInteger:
                begin
                    BigValue := FldRef.Value();
                    Value.SetValue(BigValue);
                end;
            FieldType::Decimal:
                begin
                    DecValue := FldRef.Value();
                    Value.SetValue(DecValue);
                end;
            FieldType::Boolean:
                begin
                    BoolValue := FldRef.Value();
                    Value.SetValue(BoolValue);
                end;
            FieldType::Blob, FieldType::Media, FieldType::MediaSet:
                Value.SetValueToNull();
            FieldType::Date, FieldType::Time, FieldType::DateTime:
                begin
                    // Blank dates and times come back as null, others as ISO 8601
                    if Format(FldRef.Value()) = '' then
                        Value.SetValueToNull()
                    else
                        Value.SetValue(Format(FldRef.Value(), 0, 9));
                end;
            else begin
                // Options and enums as their caption; codes, text, GUIDs as shown
                Formatted := Format(FldRef.Value());
                Value.SetValue(Formatted);
            end;
        end;
    end;

    local procedure KeyFields(var RecRef: RecordRef) Result: List of [Integer]
    var
        PrimaryKey: KeyRef;
        i: Integer;
    begin
        PrimaryKey := RecRef.KeyIndex(1);
        for i := 1 to PrimaryKey.FieldCount() do
            Result.Add(PrimaryKey.FieldIndex(i).Number());
    end;

    procedure FieldOf(var RecRef: RecordRef; FieldNo: Integer): FieldRef
    begin
        if not RecRef.FieldExist(FieldNo) then
            Error(UnknownFieldErr, RecRef.Number(), FieldNo);
        exit(RecRef.Field(FieldNo));
    end;

    local procedure Options(Captions: Text) Result: JsonArray
    var
        Caption: Text;
    begin
        foreach Caption in Captions.Split(',') do
            if Caption.Trim() <> '' then
                Result.Add(Caption.Trim());
    end;

    /// <summary>A table given by number (18) or name ("Customer").</summary>
    procedure TableNoOf(Obj: JsonObject; Name: Text): Integer
    var
        TableMetadata: Record "Table Metadata";
        Token: JsonToken;
        TableName: Text;
        No: Integer;
    begin
        if not Obj.Get(Name, Token) then
            Error(MissingTableErr);
        if not Token.IsValue() then
            Error(MissingTableErr);
        if Token.AsValue().IsNull() then
            Error(MissingTableErr);
        if TryAsInteger(Token.AsValue(), No) then
            exit(No);
        TableName := Token.AsValue().AsText();
        TableMetadata.SetRange(Name, CopyStr(TableName, 1, MaxStrLen(TableMetadata.Name)));
        if not TableMetadata.FindFirst() then
            Error(UnknownTableErr, TableName);
        exit(TableMetadata.ID);
    end;

    /// <summary>A field given by number (2) or name ("Name", "SystemId").</summary>
    procedure FieldNoOf(var RecRef: RecordRef; Token: JsonToken): Integer
    var
        Field: Record Field;
        FieldName: Text;
        No: Integer;
    begin
        if not Token.IsValue() then
            Error(UnknownFieldNameErr, RecRef.Name(), Format(Token));
        if TryAsInteger(Token.AsValue(), No) then begin
            FieldOf(RecRef, No);
            exit(No);
        end;
        FieldName := Token.AsValue().AsText();
        if LowerCase(FieldName) in ['systemid', '$systemid'] then
            exit(RecRef.SystemIdNo());
        Field.SetRange(TableNo, RecRef.Number());
        Field.SetRange(FieldName, CopyStr(FieldName, 1, MaxStrLen(Field.FieldName)));
        if not Field.FindFirst() then
            Error(UnknownFieldNameErr, RecRef.Name(), FieldName);
        exit(Field."No.");
    end;

    procedure GetFieldNo(Obj: JsonObject; Name: Text; var RecRef: RecordRef): Integer
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            Error(MissingFieldErr, Name);
        exit(FieldNoOf(RecRef, Token));
    end;

    procedure FieldList(Obj: JsonObject; Name: Text; var RecRef: RecordRef) Result: List of [Integer]
    var
        Token: JsonToken;
        Item: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit;
        if not Token.IsArray() then
            exit;
        foreach Item in Token.AsArray() do
            Result.Add(FieldNoOf(RecRef, Item));
    end;

    [TryFunction]
    local procedure TryAsInteger(Value: JsonValue; var Result: Integer)
    begin
        Result := Value.AsInteger();
    end;

    /// <summary>Rows as objects: { "No.": ..., "Salesperson/Purchaser.Name": ... }</summary>
    local procedure AsObjects(Columns: JsonArray; Rows: JsonArray) Result: JsonArray
    var
        Keys: List of [Text];
        ColumnToken: JsonToken;
        RowToken: JsonToken;
        Cell: JsonToken;
        Column: JsonObject;
        Row: JsonObject;
        ColumnKey: Text;
        i: Integer;
    begin
        foreach ColumnToken in Columns do begin
            Column := ColumnToken.AsObject();
            ColumnKey := GetText(Column, 'name');
            if ColumnKey = '$systemId' then
                ColumnKey := 'SystemId';
            if GetText(Column, 'join') <> '' then
                ColumnKey := GetText(Column, 'tableName') + '.' + ColumnKey;
            Keys.Add(ColumnKey);
        end;
        foreach RowToken in Rows do begin
            Clear(Row);
            for i := 1 to Keys.Count() do begin
                RowToken.AsArray().Get(i - 1, Cell);
                if not Row.Contains(Keys.Get(i)) then
                    Row.Add(Keys.Get(i), Cell);
            end;
            Result.Add(Row);
        end;
    end;

    procedure GetInt(Obj: JsonObject; Name: Text; Default: Integer): Integer
    var
        Token: JsonToken;
    begin
        if Obj.Get(Name, Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    exit(Token.AsValue().AsInteger());
        exit(Default);
    end;

    procedure GetBool(Obj: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        if Obj.Get(Name, Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    exit(Token.AsValue().AsBoolean());
        exit(false);
    end;

    procedure GetText(Obj: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Obj.Get(Name, Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    exit(Token.AsValue().AsText());
        exit('');
    end;

    procedure GetIntList(Obj: JsonObject; Name: Text) Result: List of [Integer]
    var
        Token: JsonToken;
        Item: JsonToken;
    begin
        if not Obj.Get(Name, Token) then
            exit;
        if not Token.IsArray() then
            exit;
        foreach Item in Token.AsArray() do
            if Item.IsValue() then
                Result.Add(Item.AsValue().AsInteger());
    end;

    local procedure Write(Json: JsonObject) Result: Text
    begin
        Json.WriteTo(Result);
    end;

    local procedure Write(Json: JsonArray) Result: Text
    begin
        Json.WriteTo(Result);
    end;
}
