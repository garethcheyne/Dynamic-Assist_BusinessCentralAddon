/// <summary>
/// The query engine over GET: the query goes in the URL, the rows come back
/// as an OData collection.
///
///   GET https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/api/err403/dynamicAssist/v1.0/companies({id})/queryRows
///       ?$filter=request eq '{"table":"Customer","fields":["No.","Name"],"top":10}'
///       &amp;$select=rowNo,data
///
/// Each row's "data" is the record as JSON text, keyed by field name; "more"
/// and "next" say whether another page follows (send "after": next). The
/// request is at most 2048 characters; POST to the DAQuery web service for
/// longer ones. Like that service it's off until an admin publishes codeunit
/// 77502 ("DA Query API") on the Web Services page, and it runs as the caller:
/// read-only, with their permissions.
/// </summary>
page 77501 "DA Query Rows API"
{
    PageType = API;
    APIPublisher = 'err403';
    APIGroup = 'dynamicAssist';
    APIVersion = 'v1.0';
    EntityName = 'queryRow';
    EntitySetName = 'queryRows';
    Caption = 'Dynamic Assist Query Rows';
    SourceTable = "DA Query Row";
    SourceTableTemporary = true;
    ODataKeyFields = "Row No.";
    DelayedInsert = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Rows)
            {
                field(rowNo; Rec."Row No.")
                {
                    Caption = 'Row No.';
                }
                field(request; Rec.Request)
                {
                    Caption = 'Request';
                }
                field(data; RowData)
                {
                    Caption = 'Data';
                }
                field(more; PageMore)
                {
                    Caption = 'More';
                }
                field(next; PageNext)
                {
                    Caption = 'Next';
                }
            }
        }
    }

    var
        ResultRows: Dictionary of [Integer, Text];
        RowData: Text;
        PageMore: Boolean;
        PageNext: Text;
        Loaded: Boolean;
        NoRequestErr: Label 'Put the query in the URL: $filter=request eq ''{"table":"Customer","fields":["No.","Name"]}''.';

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

    trigger OnAfterGetRecord()
    begin
        if not ResultRows.Get(Rec."Row No.", RowData) then
            RowData := '';
    end;

    /// <summary>Runs the query in the request filter and fills the temporary rows.</summary>
    local procedure Load()
    var
        QueryApi: Codeunit "DA Query API";
        RequestText: Text;
        ResultText: Text;
        Result: JsonToken;
        RowsToken: JsonToken;
        Row: JsonToken;
        RowText: Text;
        RowNo: Integer;
    begin
        Loaded := true;
        if Rec.GetFilter(Request) = '' then
            Error(NoRequestErr);
        RequestText := Rec.GetRangeMin(Request);
        ResultText := QueryApi.Execute(RequestText, true, "DA Query Channel"::"REST GET");
        Result.ReadFrom(ResultText);

        // A query answers { columns, rows, ... }: one entity per row. Other
        // methods (tables, fields, info) come back whole, as one row.
        if Result.IsObject() then begin
            if Result.AsObject().Get('more', RowsToken) then
                if RowsToken.IsValue() then
                    PageMore := RowsToken.AsValue().AsBoolean();
            if Result.AsObject().Get('next', RowsToken) then
                if RowsToken.IsValue() then
                    PageNext := RowsToken.AsValue().AsText();
        end;
        if Result.IsObject() then
            if Result.AsObject().Get('rows', RowsToken) then
                if RowsToken.IsArray() then begin
                    foreach Row in RowsToken.AsArray() do begin
                        RowNo += 1;
                        Row.WriteTo(RowText);
                        AddRow(RowNo, RequestText, RowText);
                    end;
                    exit;
                end;
        AddRow(1, RequestText, ResultText);
    end;

    local procedure AddRow(RowNo: Integer; RequestText: Text; RowText: Text)
    begin
        ResultRows.Add(RowNo, RowText);
        Rec.Init();
        Rec."Row No." := RowNo;
        Rec.Request := CopyStr(RequestText, 1, MaxStrLen(Rec.Request));
        Rec.Insert();
    end;
}
