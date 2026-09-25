/// <summary>
/// One join in a query: for each row of the main table, finds the related
/// record through a lookup field (Customer."Salesperson Code" to
/// "Salesperson/Purchaser".Code) and adds the columns asked for.
///
/// Read-only, like the rest: the related table needs the user's read
/// permission, and security filters apply to it too.
/// </summary>
codeunit 77501 "DA Query Join"
{
    Access = Internal;

    var
        Service: Codeunit "DA Query Service";
        Related: RecordRef;
        JoinId: Text;
        FromFieldNo: Integer;
        KeyFieldNo: Integer;
        FieldNos: List of [Integer];
        Restricts: Boolean;
        NoReadPermissionErr: Label 'You don''t have permission to read %1 (table %2).', Comment = '%1 = table caption, %2 = table number';
        NotALookupErr: Label '%1 isn''t a lookup field, so say which table to join ("table").', Comment = '%1 = field name';
        KeyErr: Label 'Choose the field of %1 that %2 points to.', Comment = '%1 = related table caption, %2 = lookup field name';

    /// <summary>
    /// Opens the related table from a join spec: { id, field, table, key,
    /// fields: [no], filters: [{ field, filter }], inner }. Adds its columns.
    /// </summary>
    procedure Init(Spec: JsonObject; var Main: RecordRef; var Columns: JsonArray)
    var
        FldRef: FieldRef;
        FieldNo: Integer;
        Column: JsonObject;
        Token: JsonToken;
        Item: JsonToken;
        Filter: JsonObject;
        FilterText: Text;
        LookupField: Record Field;
    begin
        JoinId := Service.GetText(Spec, 'id');
        FromFieldNo := Service.GetFieldNo(Spec, 'field', Main);
        if JoinId = '' then
            JoinId := Main.Field(FromFieldNo).Name();
        // The related table and field default to the lookup field's relation
        LookupField.Get(Main.Number(), FromFieldNo);
        if Spec.Contains('table') then
            Related.Open(Service.TableNoOf(Spec, 'table'))
        else
            if LookupField.RelationTableNo <> 0 then
                Related.Open(LookupField.RelationTableNo)
            else
                Error(NotALookupErr, Main.Field(FromFieldNo).Name());
        if not Related.ReadPermission() then
            Error(NoReadPermissionErr, Related.Caption(), Related.Number());
        Related.SecurityFiltering(SecurityFilter::Filtered);
        Related.ReadIsolation := IsolationLevel::ReadCommitted;
        if Spec.Contains('key') then
            KeyFieldNo := Service.GetFieldNo(Spec, 'key', Related)
        else
            if (LookupField.RelationTableNo = Related.Number()) and (LookupField.RelationFieldNo <> 0) then
                KeyFieldNo := LookupField.RelationFieldNo
            else
                if Related.KeyIndex(1).FieldCount() = 1 then
                    KeyFieldNo := Related.KeyIndex(1).FieldIndex(1).Number();
        if KeyFieldNo = 0 then
            Error(KeyErr, Related.Caption(), Main.Field(FromFieldNo).Name());
        Service.FieldOf(Related, KeyFieldNo);

        // A filter on the related table, or "only rows with a match", drops
        // main rows without a matching related record (an inner join)
        Restricts := Service.GetBool(Spec, 'inner');
        if Spec.Get('filters', Token) then
            if Token.IsArray() then
                foreach Item in Token.AsArray() do
                    if Item.IsObject() then begin
                        Filter := Item.AsObject();
                        FilterText := Service.GetText(Filter, 'filter');
                        if FilterText <> '' then begin
                            Related.Field(Service.GetFieldNo(Filter, 'field', Related)).SetFilter(FilterText);
                            Restricts := true;
                        end;
                    end;

        FieldNos := Service.FieldList(Spec, 'fields', Related);
        foreach FieldNo in FieldNos do begin
            FldRef := Service.FieldOf(Related, FieldNo);
            if FldRef.Class() = FieldClass::Normal then
                Related.AddLoadFields(FieldNo);
            Clear(Column);
            Column.Add('no', FldRef.Number());
            Column.Add('name', FldRef.Name());
            Column.Add('caption', FldRef.Caption());
            Column.Add('type', Format(FldRef.Type()));
            Column.Add('class', Format(FldRef.Class()));
            Column.Add('join', JoinId);
            Column.Add('table', Related.Number());
            Column.Add('tableName', Related.Name());
            Column.Add('tableCaption', Related.Caption());
            Columns.Add(Column);
        end;
    end;

    /// <summary>
    /// Finds the related record for the main row and adds its values (nulls
    /// when there's none). False when the row should be left out.
    /// </summary>
    procedure AddTo(var Main: RecordRef; var Row: JsonArray): Boolean
    var
        FldRef: FieldRef;
        FieldNo: Integer;
        Found: Boolean;
        Blank: JsonValue;
    begin
        FldRef := Main.Field(FromFieldNo);
        if FldRef.Class() = FieldClass::FlowField then
            FldRef.CalcField();
        if Format(FldRef.Value()) <> '' then begin
            Related.Field(KeyFieldNo).SetRange(FldRef.Value());
            Found := Related.FindFirst();
        end;
        if not Found and Restricts then
            exit(false);
        foreach FieldNo in FieldNos do
            if Found then begin
                FldRef := Related.Field(FieldNo);
                if FldRef.Class() = FieldClass::FlowField then
                    FldRef.CalcField();
                Row.Add(Service.ValueOf(FldRef));
            end else begin
                Blank.SetValueToNull();
                Row.Add(Blank);
            end;
        exit(true);
    end;

    /// <summary>True when this join can drop main rows.</summary>
    procedure IsRestricting(): Boolean
    begin
        exit(Restricts);
    end;
}
